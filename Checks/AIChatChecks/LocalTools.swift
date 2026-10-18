import Foundation

@testable import TinycastKit

@MainActor
private final class ToolCheckHost: ExtensionHostAPI {
    func perform(api: String, method: String, arguments: [RenderValue]) async throws -> String {
        "null"
    }
    func sessionEnded() {}
}

extension AIChatTests {
    static func localTools() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("readme.txt")
            try Data("hello 🦊".utf8).write(to: file)
            let utf8 = try AILocalTools.readText(file)
            expect(utf8 == "hello 🦊", "Local tools read UTF-8 text")
            expect(
                AILocalTools.allowed(file, folders: [root.path]),
                "Files inside an allowed folder are accessible")
            expect(!AILocalTools.allowed(file, folders: []), "File access starts denied")
            expect(
                !AILocalTools.allowed(
                    URL(fileURLWithPath: root.path + "-other/file"), folders: [root.path]),
                "Folder scope has a path boundary")
            let link = root.appendingPathComponent("escape")
            try FileManager.default.createSymbolicLink(
                at: link, withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))
            expect(
                !AILocalTools.allowed(link, folders: [root.path]),
                "Symlinks cannot escape folder scope")
            try Data(repeating: 65, count: 70_000).write(to: file)
            let truncated = try AILocalTools.readText(file)
            expect(
                truncated.hasSuffix("[File truncated at 64 KiB]"),
                "Large file reads are marked as truncated")
            expect(truncated.utf8.count < 66_000, "File reads have a byte limit")
            try Data([0, 1, 2]).write(to: file)
            do {
                _ = try AILocalTools.readText(file)
                expect(false, "Binary file rejected")
            } catch { expect(true, "Binary file rejected") }
            let result = CalcEngine.evaluate("2 * (3 + 4)", now: Date(), calendar: .current)
            expect(
                result?.payload == .value(display: "14", copyText: "14"),
                "Native calculator evaluates expressions")
            let server = AILocalToolServer(tools: AILocalTools.definitions) { call in
                AIToolResult(callID: call.id, content: call.name, isError: false)
            }
            defer { server.stop() }
            let endpoint = try await server.server()
            guard case .url(let url, let header, let token) = endpoint.transport else {
                fatalError()
            }
            func post(
                _ body: [String: Any], authorized: Bool = true, origin: String? = nil,
                method: String = "POST"
            ) async throws -> (JSONValue?, Int) {
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = method
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if authorized { request.setValue(token, forHTTPHeaderField: header) }
                if let origin { request.setValue(origin, forHTTPHeaderField: "Origin") }
                if method == "POST" {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                return (JSONValue(data: data), (response as! HTTPURLResponse).statusCode)
            }
            let initialize = try await post(["jsonrpc": "2.0", "id": 1, "method": "initialize"])
            expect(
                initialize.1 == 200
                    && initialize.0?.objectValue?["result"]?.objectValue?["capabilities"]?
                        .objectValue?[
                            "tools"] != nil,
                "Local MCP bridge initializes")
            let listing = try await post(["jsonrpc": "2.0", "id": 2, "method": "tools/list"])
            let names = listing.0?.objectValue?["result"]?.objectValue?["tools"]?.arrayValue?
                .compactMap {
                    $0.objectValue?["name"]?.stringValue
                }
            expect(
                names == ["calculate", "search_files", "read_file", "selected_text"],
                "CLI routes receive all native tools")
            let invoked = try await post([
                "jsonrpc": "2.0", "id": 3, "method": "tools/call",
                "params": ["name": "read_file", "arguments": ["path": "/fixture"]],
            ])
            expect(
                invoked.0?.objectValue?["result"]?.objectValue?["content"]?.arrayValue?.first?
                    .objectValue?[
                        "text"]?.stringValue == "raycompanion__read_file",
                "CLI tool names route to the same native executor")
            let unauthorized = try await post(["id": 1, "method": "tools/list"], authorized: false)
            expect(unauthorized.1 == 403, "Local tools reject missing authentication")
            let browser = try await post(
                ["id": 1, "method": "tools/list"], origin: "https://example.com")
            expect(browser.1 == 403, "Local tools reject browser origins")
            let notification = try await post([
                "jsonrpc": "2.0", "method": "notifications/initialized",
            ])
            expect(notification.1 == 202, "Local MCP notifications are accepted")
            let toolDirectory = root.appendingPathComponent("tools")
            try FileManager.default.createDirectory(
                at: toolDirectory, withIntermediateDirectories: true)
            try Data("exports.default = () => 1".utf8).write(
                to: toolDirectory.appendingPathComponent("noop.js"))
            let manifest: [String: Any] = [
                "name": "fixture", "title": "Fixture",
                "tools": [["name": "noop", "description": "No arguments"]],
            ]
            try JSONSerialization.data(withJSONObject: manifest).write(
                to: root.appendingPathComponent("package.json"))
            let imported = AIExtension.load(root)
            expect(imported?.tools.count == 1, "Extensions with argument-free tools import")
            expect(
                imported?.tools.first?.input.objectValue?["type"]?.stringValue == "object",
                "Argument-free tools receive an object schema")
            let invalid: [String: Any] = ["name": "fixture", "tools": [["name": "../escape"]]]
            try JSONSerialization.data(withJSONObject: invalid).write(
                to: root.appendingPathComponent("package.json"))
            expect(
                AIExtension.load(root) == nil, "Extension tool paths cannot traverse outside tools")
            let get = try await post([:], method: "GET")
            expect(get.1 == 405, "Local MCP bridge declines SSE GET with 405")
            let host = ToolCheckHost()
            let resource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/TinycastKit/Resources/RaycastRuntime.generated.js")
            let context = ExtensionLaunchContext(
                extensionName: "proof", extensionTitle: "Proof", commandName: "sum",
                commandMode: .noView,
                assetsPath: root.path, supportPath: root.path, preferences: [:], caches: [:],
                arguments: [:], fallbackText: nil, isDarkAppearance: false)
            for allowed in [false, true] {
                let runtime = ExtensionRuntime(hostAPI: host, runtimeURL: resource)
                try await runtime.boot(config: .current(supportDirectory: root))
                let code =
                    "exports.confirmation = input => ({message: 'Add numbers?'}); exports.default = input => ({sum: input.a + input.b});"
                do {
                    let value = try await runtime.invokeTool(
                        code: code, file: root.appendingPathComponent("sum.js"), context: context,
                        arguments: "{\"a\":2,\"b\":3}"
                    ) { _ in allowed }
                    expect(
                        allowed
                            && JSONValue(data: Data(value.utf8))?.objectValue?["sum"]?.intValue
                                == 5,
                        "Native JavaScriptCore returns approved tool results")
                } catch {
                    expect(!allowed, "Native JavaScriptCore respects denied tool confirmation")
                }
                runtime.shutdown()
            }
        } catch { expect(false, "Local tool checks: \(error)") }
    }
}
