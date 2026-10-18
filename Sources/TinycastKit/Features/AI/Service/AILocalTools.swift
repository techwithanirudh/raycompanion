import AppKit
import ApplicationServices
import Observation

enum AIToolApproval: String, CaseIterable {
    case ask = "Ask every time"
    case reads = "Allow reads"
    case all = "Allow reads & writes"
}

@MainActor
@Observable
final class AILocalTools {
    private unowned let core: AppCore
    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?
    private(set) var target: NSRunningApplication?
    var folders: [String] {
        didSet { defaults.set(folders, forKey: "aiToolFolders") }
    }
    var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "aiLocalToolsEnabled")
            if !enabled { stop() }
        }
    }
    var approval: AIToolApproval {
        didSet { defaults.set(approval.rawValue, forKey: "aiToolApproval") }
    }
    var automaticallyAllowReads: Bool { approval != .ask }
    /// One bridge for every chat. Codex relaunches whenever its server list changes, so the
    /// URL and token stay stable and are replaced only when the offered tools change.
    private var bridge: (names: [String], server: AILocalToolServer)?

    init(core: AppCore, defaults: UserDefaults = .standard) {
        self.core = core
        self.defaults = defaults
        folders = defaults.stringArray(forKey: "aiToolFolders") ?? []
        enabled = defaults.object(forKey: "aiLocalToolsEnabled") as? Bool ?? true
        approval = defaults.string(forKey: "aiToolApproval")
            .flatMap(AIToolApproval.init(rawValue:)) ?? .reads
        target = NSWorkspace.shared.frontmostApplication
        if target?.bundleIdentifier?.hasPrefix("com.raycast") == true { target = nil }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app =
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let app,
                    app.processIdentifier != NSRunningApplication.current.processIdentifier,
                    app.bundleIdentifier?.hasPrefix("com.raycast") != true
                else { return }
                self?.target = app
            }
        }
    }

    nonisolated static let handle = "raycompanion"
    static let definitions: [AITool] = [
        tool(
            "calculate",
            "Evaluate arithmetic, dates and unit conversions. Example: 2 * (3 + 4), 10 km in miles.",
            "Calculator", ["expression": "Expression to evaluate"]),
        tool(
            "search_files",
            "Find files by name in the folders the user allowed. Returns paths, not contents.",
            "File search", ["query": "Filename query"]),
        tool(
            "read_file",
            "Read UTF-8 text from an allowed folder. Returns at most 64 KiB. Follows the read approval setting.",
            "Read file", ["path": "Absolute file path"]),
        tool(
            "selected_text",
            "Read the current selection in the app used before chat. Requires Accessibility permission and follows the read approval setting.",
            "Selected text", [:]),
    ]

    private static func tool(
        _ name: String, _ description: String, _ title: String, _ fields: [String: String]
    ) -> AITool {
        AITool(
            name: MCPToolName.compose(slug: handle, tool: name), description: description,
            parameters: .object([
                "type": .string("object"),
                "properties": .object(
                    fields.mapValues {
                        .object(["type": .string("string"), "description": .string($0)])
                    }),
                "required": .array(fields.keys.sorted().map(JSONValue.string)),
                "additionalProperties": .bool(false),
            ]), origin: "RayCompanion", title: title)
    }

    func tools(scopedTo slug: String?) -> [AITool] {
        guard enabled, slug == nil || slug == Self.handle else { return [] }
        return Self.definitions + core.aiExtensionTools.tools()
    }

    func server(scopedTo slug: String?) async -> AIToolServer? {
        guard enabled, slug == nil || slug == Self.handle else { return nil }
        let tools = tools(scopedTo: slug)
        let names = tools.map(\.name)
        if bridge?.names != names {
            bridge?.server.stop()
            bridge = (names, AILocalToolServer(tools: tools) { [weak self] call in
                guard let self else { return .failure(call.id, "Tools are unavailable.") }
                return await self.invoke(call)
            })
        }
        guard let server = bridge?.server else { return nil }
        do { return try await server.server() } catch {
            if bridge?.server === server { bridge = nil }
            return nil
        }
    }

    /// Only what `tools(scopedTo:)` offers runs, matched by its exact wire name.
    func invoke(_ call: AIToolCall) async -> AIToolResult {
        guard enabled, core.settings.aiEnabled else {
            return .failure(call.id, "That tool is unavailable or its arguments are invalid.")
        }
        if core.aiExtensionTools.tools().contains(where: { $0.name == call.name }) {
            return await core.aiExtensionTools.invoke(call)
        }
        guard let arguments = JSONValue(data: Data(call.arguments.utf8))?.objectValue,
            let definition = Self.definitions.first(where: { $0.name == call.name })
        else {
            return .failure(call.id, "That tool is unavailable or its arguments are invalid.")
        }
        do {
            let value: String
            switch definition.name {
            case "raycompanion__calculate":
                if approval == .ask {
                    guard await core.confirm(
                        title: "Calculate?", message: arguments["expression"]?.stringValue,
                        symbol: "function", confirmTitle: "Calculate", dismissTitle: "Cancel",
                        queued: true)
                    else { return .failure(call.id, "The user declined the calculation.") }
                }
                guard !Task.isCancelled, enabled, core.settings.aiEnabled else {
                    return .failure(call.id, "The calculation was cancelled.")
                }
                guard let expression = arguments["expression"]?.stringValue,
                    let result = CalcEngine.evaluate(expression, now: Date(), calendar: .current)
                else {
                    return .failure(call.id, "The expression could not be evaluated.")
                }
                switch result.payload {
                case .value(_, let text): value = text
                case .error(let message): return .failure(call.id, message)
                }
            case "raycompanion__search_files":
                guard let query = arguments["query"]?.stringValue, !query.isEmpty,
                    query.count <= 256
                else {
                    return .failure(call.id, "Enter a filename query of 1–256 characters.")
                }
                guard !folders.isEmpty else {
                    return .failure(call.id, "Choose file access folders in AI Settings first.")
                }
                if !automaticallyAllowReads {
                    guard
                        await core.confirm(
                            title: "Search files?", message: query, symbol: "magnifyingglass",
                            confirmTitle: "Search", dismissTitle: "Cancel", queued: true)
                    else { return .failure(call.id, "The user declined the file search.") }
                }
                guard !Task.isCancelled, enabled, core.settings.aiEnabled, !folders.isEmpty else {
                    return .failure(call.id, "The file search was cancelled.")
                }
                let policy = FileSearchPolicy(
                    scopes: folders, ignorePatterns: [],
                    homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
                let results = try await Task.detached {
                    try FileSearchService.search(query: query, policy: policy)
                }.value
                value = ExtensionRuntime.jsonString(
                    from: results.prefix(30).filter { self.allowed($0.url) }.map {
                        ["name": $0.name, "path": $0.url.path, "directory": $0.isDirectory]
                            as [String: Any]
                    })
            case "raycompanion__read_file":
                guard let path = arguments["path"]?.stringValue, path.hasPrefix("/") else {
                    return .failure(call.id, "Use an absolute file path.")
                }
                let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
                guard allowed(url) else {
                    return .failure(call.id, "That file is outside the allowed folders.")
                }
                if !automaticallyAllowReads {
                    guard
                        await core.confirm(
                            title: "Read file?", message: url.path, symbol: "doc.text",
                            confirmTitle: "Read",
                            dismissTitle: "Cancel", queued: true)
                    else { return .failure(call.id, "The user declined the file read.") }
                }
                guard !Task.isCancelled, enabled, core.settings.aiEnabled, allowed(url) else {
                    return .failure(call.id, "The file read was cancelled.")
                }
                value = try await Task.detached { try Self.readText(url) }.value
            default:
                guard AXIsProcessTrusted(), let app = target,
                    app.processIdentifier != NSRunningApplication.current.processIdentifier
                else {
                    return .failure(
                        call.id, "Accessibility permission and a target app are required.")
                }
                if !automaticallyAllowReads {
                    guard
                        await core.confirm(
                            title: "Read selected text?", message: app.localizedName,
                            symbol: "text.cursor",
                            confirmTitle: "Read", dismissTitle: "Cancel", queued: true)
                    else { return .failure(call.id, "The user declined reading selected text.") }
                }
                guard !Task.isCancelled, enabled, core.settings.aiEnabled,
                    let text = AccessibilityText.selection(in: app),
                    !text.isEmpty
                else { return .failure(call.id, "No selected text is available in that app.") }
                value = String(text.prefix(32_000))
            }
            return AIToolResult(callID: call.id, content: value, isError: false)
        } catch { return .failure(call.id, error.localizedDescription) }
    }

    func allowed(_ url: URL) -> Bool {
        Self.allowed(url, folders: folders)
    }

    nonisolated static func allowed(_ url: URL, folders: [String]) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return folders.contains { folder in
            let root = URL(fileURLWithPath: folder).resolvingSymlinksInPath().standardizedFileURL
                .path
            return path.hasPrefix(root == "/" ? "/" : root + "/")
        }
    }

    nonisolated static func readText(_ url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 65_537) ?? Data()
        guard !data.contains(0) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        var bounded = data.prefix(65_536)
        var text = String(data: bounded, encoding: .utf8)
        if data.count > 65_536 {
            for _ in 0..<3 where text == nil {
                bounded = bounded.dropLast()
                text = String(data: bounded, encoding: .utf8)
            }
        }
        guard let text else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return text + (data.count > 65_536 ? "\n[File truncated at 64 KiB]" : "")
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Allow"
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.folders = panel.urls.map { $0.resolvingSymlinksInPath().path }
        }
    }

    func stop() {
        bridge?.server.stop()
        bridge = nil
    }
}
