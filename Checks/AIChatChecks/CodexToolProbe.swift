import Foundation
@testable import TinycastKit

extension AIChatTests {
    static func codexToolProbe() async {
        let root = URL(fileURLWithPath: "/Users/anirudh/Library/Application Support/com.anirudh.raycompanion/ai-extensions")
        let extensions = ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).compactMap(AIExtension.load)
        let tools = AILocalTools.definitions + extensions.flatMap { item in
            item.tools.map { tool in AITool(name: item.wireName(tool), description: tool.description, parameters: tool.input, origin: item.title, title: tool.title) }
        }
        print("Tool count: \(tools.count)")
        let bridge = AILocalToolServer(tools: tools) { call in
            AIToolResult(callID: call.id, content: "14", isError: false)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("raycompanion-codex-tool-probe")
        let client = CodexAppServerClient(workspace: directory)
        defer { client.stop(); bridge.stop() }
        do {
            let server = try await bridge.server()
            try await client.start(toolServers: [server])
            let status = try await client.request(method: "mcpServerStatus/list", params: ["limit": 10], timeout: .seconds(30))
            for item in status["data"]?.arrayValue ?? [] {
                guard let entry = item.objectValue, entry["name"]?.stringValue == "tinycast-raycompanion" else { continue }
                print("Listed count: \(entry["tools"]?.objectValue?.count ?? 0); error: \(entry["toolsError"]?.stringValue ?? "none")")
            }
            let runner = CodexTurnRunner(client: client)
            client.onNotification = { method, params in runner.handle(method: method, params: params) }
            runner.connect = { servers in try await client.start(toolServers: servers); return [] }
            let session = AIToolServerSession(rounds: 3, servers: { [server] }, consent: { _ in true })
            let request = AIRequest(messages: [AIMessage(role: .user, text: "Use the calculator tool to evaluate 2 * (3 + 4). Do not calculate it yourself.")])
            for try await event in runner.stream(request, model: "gpt-5.6-luna", effort: "medium", toolServers: session) {
                print("EVENT: \(event)")
            }
        } catch { print("PROBE ERROR: \(error.localizedDescription)") }
    }
}
