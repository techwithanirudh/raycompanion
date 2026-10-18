import Foundation
import Network

@testable import TinycastKit

/// Signals across the tool server's tasks; every touch is on the main actor.
@MainActor
private final class Flag {
    var value = false
}

extension AIChatTests {
    static func toolCallsRouteByExactOfferedName() {
        let local: Set<String> = ["raycompanion__calculate", "raycompanion__ext-1234abcd-sum"]
        let mcp: Set<String> = ["github__list_prs"]
        let open = ChatToolScope()
        func route(
            _ name: String, enabled: Bool = true, scope: ChatToolScope = ChatToolScope()
        ) -> AIToolRoute {
            AIToolRoute.resolve(name, local: local, mcp: mcp, localEnabled: enabled, scope: scope)
        }
        expect(route("raycompanion__calculate") == .local, "Offered native tools route locally")
        expect(
            route("raycompanion__ext-1234abcd-sum") == .local,
            "Offered extension tools route locally")
        expect(route("github__list_prs") == .mcp, "Offered MCP tools route to MCP")
        expect(
            route("raycompanion__read_file") == .unavailable,
            "A local-looking name that was not offered does not run")
        expect(
            route("raycompanion__ext-ffffffff-delete") == .unavailable,
            "An extension-looking name that was not offered does not run")
        expect(route("github__delete_repo") == .unavailable, "Unoffered MCP tools do not run")
        expect(
            route("raycompanion__calculate", enabled: false) == .unavailable,
            "Local tools switched off since the turn began do not run")
        var withoutLocal = open
        withoutLocal.toggle(AILocalTools.handle)
        expect(
            route("raycompanion__calculate", scope: withoutLocal) == .unavailable,
            "Local tools excluded from the chat do not run")
        var withoutGitHub = open
        withoutGitHub.toggle("github")
        expect(
            route("github__list_prs", scope: withoutGitHub) == .unavailable,
            "MCP servers excluded from the chat do not run")
        expect(
            route("raycompanion__calculate", scope: ChatToolScope(isEnabled: false))
                == .unavailable,
            "A chat with tools off runs nothing")

        let offered = [
            AITool(
                name: "raycompanion__calculate", description: "", parameters: .object([:]),
                origin: "RayCompanion", title: "Calculator"),
            AITool(
                name: MCPToolName.compose(slug: AILocalTools.handle, tool: "ext-1234abcd-a__b"),
                description: "", parameters: .object([:]), origin: "Fixture", title: "A B"),
        ]
        func permits(
            _ handle: String, _ tool: String, enabled: Bool = true,
            scope: ChatToolScope = ChatToolScope()
        ) -> Bool {
            AIToolRoute.permitsLocal(
                AIToolServerCall(handle: handle, tool: tool), offered: offered,
                localEnabled: enabled, scope: scope)
        }
        expect(permits("raycompanion", "calculate"), "CLI consent allows an offered local tool")
        expect(
            permits("raycompanion", "ext-1234abcd-a__b"),
            "CLI consent finds a tool whose own name contains the separator")
        expect(!permits("raycompanion", "read_file"), "CLI consent refuses an unoffered tool")
        expect(!permits("github", "calculate"), "CLI consent for local tools needs the handle")
        expect(
            !permits("raycompanion", "calculate", enabled: false),
            "CLI consent refuses while local tools are off")
        expect(
            !permits("raycompanion", "calculate", scope: withoutLocal),
            "CLI consent refuses local tools excluded from the chat")
        expect(
            AILocalToolServer.shortName("raycompanion__ext-1234abcd-a__b") == "ext-1234abcd-a__b",
            "Bridge names split on the first separator only")
    }

    static func theLocalHandleIsReserved() {
        expect(
            MCPSlug.make(from: "RayCompanion", existing: []) != AILocalTools.handle,
            "A new server cannot take the local tools' handle")
        expect(
            MCPSlug.make(from: "GitHub", existing: []) == "github",
            "Other names keep their derived handle")
        let suite = "raycompanion.checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MCPSettingsStore(defaults: defaults)
        store.save(MCPServer(name: "RayCompanion"))
        let saved = store.servers.first?.slug
        expect(
            saved != nil && saved != AILocalTools.handle,
            "Saving a server named after the app moves its handle aside")
        store.save(store.servers[0])
        expect(store.servers.first?.slug == saved, "A moved-aside handle stays stable on resave")

        let legacy = [
            MCPServer(name: "Old", slug: AILocalTools.handle),
            MCPServer(name: "Other", slug: "raycompanion-2"),
        ]
        defaults.set(
            try? JSONEncoder().encode(legacy), forKey: AppSettingsKey.mcpServers.rawValue)
        let reloaded = MCPSettingsStore(defaults: defaults).servers.map(\.slug)
        expect(
            !reloaded.contains(AILocalTools.handle) && Set(reloaded).count == reloaded.count,
            "A stored server holding the local handle is moved aside on load")
        let persisted = defaults.data(forKey: AppSettingsKey.mcpServers.rawValue)
            .flatMap { try? JSONDecoder().decode([MCPServer].self, from: $0) }?.map(\.slug)
        expect(persisted == reloaded, "The moved-aside handle is saved")
    }

    static func theLocalToolServerRecoversAndCancels() async {
        var attempts = 0
        let flaky = AILocalToolServer(
            tools: AILocalTools.definitions,
            makeListener: {
                attempts += 1
                if attempts == 1 { throw NWError.posix(.EADDRINUSE) }
                return try AILocalToolServer.loopbackListener()
            }
        ) { call in AIToolResult(callID: call.id, content: "", isError: false) }
        defer { flaky.stop() }
        let first = try? await flaky.server()
        expect(first == nil, "A failed bridge start reports the failure")
        let second = try? await flaky.server()
        expect(
            second != nil && attempts == 2, "The bridge starts again after a failed start")

        let started = Flag()
        let cancelled = Flag()
        let server = AILocalToolServer(tools: AILocalTools.definitions) { call in
            started.value = true
            try? await Task.sleep(for: .seconds(30))
            cancelled.value = Task.isCancelled
            return AIToolResult(callID: call.id, content: "late", isError: false)
        }
        defer { server.stop() }
        guard let endpoint = try? await server.server(),
            case .url(let url, let header, let token) = endpoint.transport
        else {
            expect(false, "Cancellation fixture bridge starts")
            return
        }
        func call() -> Task<Void, Never> {
            Task {
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = "POST"
                request.setValue(token, forHTTPHeaderField: header)
                request.httpBody = try? JSONSerialization.data(withJSONObject: [
                    "jsonrpc": "2.0", "id": 1, "method": "tools/call",
                    "params": ["name": "calculate", "arguments": ["expression": "1"]],
                ])
                _ = try? await URLSession.shared.data(for: request)
            }
        }
        func waitFor(_ flag: Flag) async -> Bool {
            for _ in 0..<100 where !flag.value { try? await Task.sleep(for: .milliseconds(20)) }
            return flag.value
        }
        let hangingUp = call()
        let ran = await waitFor(started)
        expect(ran, "The bridge runs a tool call")
        hangingUp.cancel()
        let hungUp = await waitFor(cancelled)
        expect(hungUp, "A client hanging up cancels its tool call")

        started.value = false
        cancelled.value = false
        let stopping = call()
        let ranAgain = await waitFor(started)
        expect(ranAgain, "The bridge runs a second tool call")
        server.stop()
        let stopped = await waitFor(cancelled)
        expect(stopped, "Stopping the bridge cancels a running tool call")
        stopping.cancel()
    }

    static func toolTimeoutsSkipTheConfirmation() async {
        var clock = ToolInvocationClock()
        let now = DispatchTime.now().uptimeNanoseconds
        clock.armedAt = DispatchTime(uptimeNanoseconds: now - 2_000_000_000)
        clock.timeout = DispatchWorkItem {}
        clock.pause()
        expect(
            (87.5...88.5).contains(clock.remaining) && clock.timeout == nil,
            "Pausing for a confirmation keeps the rest of the tool budget")
        clock.pause()
        expect((87.5...88.5).contains(clock.remaining), "A second pause spends nothing")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let resource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/TinycastKit/Resources/RaycastRuntime.generated.js")
        let context = ExtensionLaunchContext(
            extensionName: "proof", extensionTitle: "Proof", commandName: "wait",
            commandMode: .noView, assetsPath: root.path, supportPath: root.path,
            preferences: [:], caches: [:], arguments: [:], fallbackText: nil,
            isDarkAppearance: false)
        let runtime = ExtensionRuntime(hostAPI: RoutingCheckHost(), runtimeURL: resource)
        defer { runtime.shutdown() }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try await runtime.boot(config: .current(supportDirectory: root))
        } catch {
            expect(false, "Confirmation fixture runtime boots: \(error)")
            return
        }
        let asked = Flag()
        let dismissed = Flag()
        let invocation = Task {
            try await runtime.invokeTool(
                code: "exports.confirmation = () => ({message: 'Wait?'}); exports.default = () => 1;",
                file: root.appendingPathComponent("wait.js"), context: context, arguments: "{}"
            ) { _ in
                asked.value = true
                try? await Task.sleep(for: .seconds(30))
                dismissed.value = Task.isCancelled
                return false
            }
        }
        for _ in 0..<100 where !asked.value { try? await Task.sleep(for: .milliseconds(20)) }
        expect(asked.value, "The extension asks for confirmation")
        invocation.cancel()
        let failed = (try? await invocation.value) == nil
        for _ in 0..<100 where !dismissed.value { try? await Task.sleep(for: .milliseconds(20)) }
        expect(
            failed && dismissed.value,
            "Cancelling an extension tool call dismisses its pending confirmation")
    }
}

@MainActor
private final class RoutingCheckHost: ExtensionHostAPI {
    func perform(api: String, method: String, arguments: [RenderValue]) async throws -> String {
        "null"
    }
    func sessionEnded() {}
}
