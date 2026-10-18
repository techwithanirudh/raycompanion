import Foundation
import Network

@MainActor
final class AILocalToolServer {
    private let tools: [AITool]
    private let invoke: @MainActor @Sendable (AIToolCall) async -> AIToolResult
    private let makeListener: () throws -> NWListener
    private let token = UUID().uuidString + UUID().uuidString
    private var listener: NWListener?
    private var waiting: CheckedContinuation<UInt16, Error>?
    private var startTask: Task<UInt16, Error>?
    private var connections: [UUID: Connection] = [:]
    private let queue = DispatchQueue(label: "com.anirudh.raycompanion.tools")

    /// A request's tool runs in `work`, so a hang-up, the idle drop or `stop()` cancels its dialog.
    private struct Connection {
        let connection: NWConnection
        let idle: Task<Void, Never>
        var work: Task<Void, Never>?
    }

    init(
        tools: [AITool], makeListener: @escaping () throws -> NWListener = loopbackListener,
        invoke: @escaping @MainActor @Sendable (AIToolCall) async -> AIToolResult
    ) {
        self.tools = tools
        self.makeListener = makeListener
        self.invoke = invoke
    }

    nonisolated static func loopbackListener() throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        return try NWListener(using: parameters)
    }

    func server() async throws -> AIToolServer {
        let task = startTask ?? Task { try await start() }
        startTask = task
        let port: UInt16
        do { port = try await task.value } catch {
            // A failed start is retried by the next caller rather than cached for the app's life.
            if startTask == task {
                startTask = nil
                listener?.cancel()
                listener = nil
            }
            throw error
        }
        return AIToolServer(
            handle: AILocalTools.handle, title: "RayCompanion",
            transport: .url(
                "http://127.0.0.1:\(port)/mcp", headerName: "Authorization",
                headerValue: "Bearer \(token)")
        )
    }

    private func start() async throws -> UInt16 {
        let listener = try makeListener()
        self.listener = listener
        return try await withCheckedThrowingContinuation { continuation in
            waiting = continuation
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        if let port = listener.port?.rawValue {
                            self.waiting?.resume(returning: port)
                            self.waiting = nil
                        }
                    case .failed(let error):
                        self.waiting?.resume(throwing: error)
                        self.waiting = nil
                    case .cancelled:
                        self.waiting?.resume(throwing: CancellationError())
                        self.waiting = nil
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: queue)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 32 else {
            connection.cancel()
            return
        }
        let id = UUID()
        let idle = Task { [weak self] in
            guard (try? await Task.sleep(for: .seconds(180))) != nil else { return }
            self?.close(id)
        }
        connections[id] = Connection(connection: connection, idle: idle)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: Task { @MainActor in self?.close(id) }
            default: break
            }
        }
        connection.start(queue: queue)
        receive(connection, id: id, buffer: Data())
    }

    /// The request is complete, so anything further is the client going away mid-call.
    private func watchForHangUp(_ connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] _, _, complete, error in
            Task { @MainActor in
                guard let self, self.connections[id] != nil else { return }
                if complete || error != nil {
                    self.close(id)
                } else {
                    self.watchForHangUp(connection, id: id)
                }
            }
        }
    }

    private func receive(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self, self.connections[id] != nil else { return }
                var buffer = buffer
                if let data { buffer.append(data) }
                guard buffer.count <= 131_072, error == nil else {
                    self.close(id)
                    return
                }
                guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                    if complete || buffer.count > 8_192 {
                        self.close(id)
                    } else {
                        self.receive(connection, id: id, buffer: buffer)
                    }
                    return
                }
                let header = String(decoding: buffer[..<separator.lowerBound], as: UTF8.self)
                let lines = header.components(separatedBy: "\r\n")
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    guard let colon = line.firstIndex(of: ":") else { continue }
                    headers[line[..<colon].lowercased()] = line[line.index(after: colon)...]
                        .trimmingCharacters(in: .whitespaces)
                }
                guard headers["authorization"] == "Bearer \(self.token)",
                    headers["origin"] == nil, headers["transfer-encoding"] == nil
                else {
                    self.respond(connection, id: id, status: "403 Forbidden", data: Data())
                    return
                }
                guard lines.first == "POST /mcp HTTP/1.1" else {
                    self.respond(connection, id: id, status: "405 Method Not Allowed", data: Data())
                    return
                }
                guard let length = headers["content-length"].flatMap(Int.init),
                    (0...65_536).contains(length)
                else {
                    self.respond(connection, id: id, status: "400 Bad Request", data: Data())
                    return
                }
                let body = buffer[separator.upperBound...]
                guard body.count >= length else {
                    if complete {
                        self.close(id)
                    } else {
                        self.receive(connection, id: id, buffer: buffer)
                    }
                    return
                }
                guard let request = JSONValue(data: Data(body.prefix(length)))?.objectValue else {
                    self.respond(connection, id: id, status: "400 Bad Request", data: Data())
                    return
                }
                guard let requestID = request["id"] else {
                    self.respond(connection, id: id, status: "202 Accepted", data: Data())
                    return
                }
                self.watchForHangUp(connection, id: id)
                self.connections[id]?.work = Task {
                    let result = await self.reply(request)
                    guard !Task.isCancelled, self.connections[id] != nil else { return }
                    let response = JSONValue.object([
                        "jsonrpc": .string("2.0"), "id": requestID, result.0: result.1,
                    ])
                    let encoded = try? JSONSerialization.data(withJSONObject: response.jsonObject)
                    self.respond(connection, id: id, status: "200 OK", data: encoded ?? Data())
                }
            }
        }
    }

    private func reply(_ request: [String: JSONValue]) async -> (String, JSONValue) {
        switch request["method"]?.stringValue {
        case "initialize":
            return (
                "result",
                .object([
                    "protocolVersion": .string("2025-03-26"),
                    "capabilities": .object(["tools": .object([:])]),
                    "serverInfo": .object([
                        "name": .string("RayCompanion"), "version": .string("1"),
                    ]),
                ])
            )
        case "ping": return ("result", .object([:]))
        case "tools/list":
            return (
                "result",
                .object([
                    "tools": .array(
                        tools.map { tool in
                            .object([
                                "name": .string(Self.shortName(tool.name)),
                                "description": .string(tool.description),
                                "inputSchema": tool.parameters,
                            ])
                        })
                ])
            )
        case "tools/call":
            guard let params = request["params"]?.objectValue,
                let name = params["name"]?.stringValue,
                let tool = tools.first(where: { Self.shortName($0.name) == name })
            else {
                return (
                    "error", .object(["code": .number(-32602), "message": .string("Unknown tool")])
                )
            }
            let arguments = params["arguments"] ?? .object([:])
            let text = ExtensionRuntime.jsonString(from: arguments.jsonObject)
            let result = await invoke(
                AIToolCall(id: UUID().uuidString, name: tool.name, arguments: text))
            return (
                "result",
                .object([
                    "content": .array([
                        .object(["type": .string("text"), "text": .string(result.content)])
                    ]),
                    "isError": .bool(result.isError),
                ])
            )
        default:
            return (
                "error", .object(["code": .number(-32601), "message": .string("Method not found")])
            )
        }
    }

    /// The name after the handle; a tool's own name may itself contain the separator.
    nonisolated static func shortName(_ name: String) -> String {
        MCPToolName.parse(name)?.tool ?? name
    }

    private func respond(_ connection: NWConnection, id: UUID, status: String, data: Data) {
        var response = Data(
            "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
                .utf8)
        response.append(data)
        connection.send(
            content: response,
            completion: .contentProcessed { [weak self] _ in
                Task { @MainActor in self?.close(id) }
            })
    }

    private func close(_ id: UUID) {
        guard let closing = connections.removeValue(forKey: id) else { return }
        closing.idle.cancel()
        closing.work?.cancel()
        closing.connection.cancel()
    }

    func stop() {
        listener?.cancel()
        for id in Array(connections.keys) { close(id) }
        startTask?.cancel()
        startTask = nil
        listener = nil
    }
}
