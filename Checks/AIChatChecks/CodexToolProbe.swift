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
            let prompt = ProcessInfo.processInfo.environment["RAYCOMPANION_CODEX_TOOL_PROBE_PROMPT"]
                ?? "Use the calculator tool to evaluate 2 * (3 + 4). Do not calculate it yourself."
            let environment = ProcessInfo.processInfo.environment
            // The turns before "turn on klack" in the reported chat, where the model had already refused.
            let history: [AIMessage] = environment["RAYCOMPANION_CODEX_TOOL_PROBE_HISTORY"] == "1" ? [
                AIMessage(role: .user, text: "can you use extensions"),
                AIMessage(role: .assistant, text: "I can't install or use extensions from this chat. Tell me which extension or app you mean, and I'll guide you through using it."),
                AIMessage(role: .user, text: "Use a browser extension"),
                AIMessage(role: .assistant, text: "Which browser are you using—Safari, Chrome, or Firefox? Also, what should the extension do?"),
            ] : []
            let instructions = environment["RAYCOMPANION_CODEX_TOOL_PROBE_NOTE"] == "1"
                ? AIInstructions.compose(
                    userPrompt: nil, isEnabled: false,
                    toolSources: ["a calculator", "file search and reading in allowed folders", "the selected text"]
                        + extensions.map(\.title))
                : nil
            let request = AIRequest(
                instructions: instructions, messages: history + [AIMessage(role: .user, text: prompt)])
            for try await event in runner.stream(request, model: "gpt-5.6-luna", effort: "medium", toolServers: session) {
                print("EVENT: \(event)")
            }
        } catch { print("PROBE ERROR: \(error.localizedDescription)") }
    }
}
