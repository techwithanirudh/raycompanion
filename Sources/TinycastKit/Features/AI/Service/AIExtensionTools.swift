import AppKit
import Observation

@MainActor
@Observable
final class AIExtensionTools {
    private unowned let core: AppCore
    private let root: URL
    private let defaults: UserDefaults
    private let secrets = KeychainSecretStore(scope: "extension-tool-preferences")
    private(set) var extensions: [AIExtension] = []
    var enabledNames: Set<String> {
        didSet {
            defaults.set(Array(enabledNames), forKey: "aiToolExtensions")
        }
    }
    var error: String?

    init(core: AppCore, defaults: UserDefaults = .standard, root: URL? = nil) {
        self.core = core
        self.defaults = defaults
        self.root =
            root
            ?? ExtensionCatalog.extensionsDirectory().deletingLastPathComponent()
            .appendingPathComponent(
                "ai-extensions")
        enabledNames = Set(defaults.stringArray(forKey: "aiToolExtensions") ?? [])
        reload()
    }

    func reload() {
        extensions =
            ((try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil))
            ?? [])
            .compactMap(AIExtension.load).sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    func importInstalled() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for source in ExtensionCatalog.raycastExtensionRoots() {
                for directory
                    in (try? FileManager.default.contentsOfDirectory(
                        at: source, includingPropertiesForKeys: nil)) ?? []
                {
                    guard let item = AIExtension.load(directory) else { continue }
                    let destination = root.appendingPathComponent(item.account.uuidString)
                    let staging = root.appendingPathComponent(".\(UUID().uuidString)")
                    try FileManager.default.createDirectory(
                        at: staging, withIntermediateDirectories: true)
                    do {
                        let entries = try FileManager.default.contentsOfDirectory(
                            at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey])
                        for entry in entries
                        where entry.lastPathComponent == "package.json"
                            || entry.lastPathComponent == "assets"
                            || entry.lastPathComponent == "tools"
                            || entry.lastPathComponent.lowercased().hasPrefix("license")
                            || entry.pathExtension == "js"
                        {
                            try Self.copyCode(
                                entry, to: staging.appendingPathComponent(entry.lastPathComponent))
                        }
                        guard AIExtension.load(staging) != nil else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        if FileManager.default.fileExists(atPath: destination.path) {
                            _ = try FileManager.default.replaceItemAt(
                                destination, withItemAt: staging)
                        } else {
                            try FileManager.default.moveItem(at: staging, to: destination)
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: staging)
                        throw error
                    }
                }
            }
            error = nil
            core.localTools.stop()
            reload()
        } catch { self.error = "Could not import extensions: \(error.localizedDescription)" }
    }

    private static func copyCode(_ source: URL, to destination: URL) throws {
        let attributes = try source.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard attributes.isSymbolicLink != true else { return }
        if attributes.isDirectory == true {
            try FileManager.default.createDirectory(
                at: destination, withIntermediateDirectories: true)
            for child in try FileManager.default.contentsOfDirectory(
                at: source, includingPropertiesForKeys: nil)
            {
                try copyCode(child, to: destination.appendingPathComponent(child.lastPathComponent))
            }
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    func tools() -> [AITool] {
        extensions.filter { enabledNames.contains($0.name) }.flatMap { item in
            item.tools.map { tool in
                AITool(
                    name: item.wireName(tool), description: tool.description,
                    parameters: tool.input,
                    origin: item.title, title: tool.title)
            }
        }
    }

    func preferences(for item: AIExtension) throws -> [String: ExtensionPreferenceValue] {
        let saved =
            try secrets.secret(for: item.account).flatMap {
                JSONValue(data: Data($0.utf8))?.objectValue
            }
            ?? [:]
        var values: [String: ExtensionPreferenceValue] = [:]
        for schema in item.schemas {
            let stored = saved[schema.name].flatMap {
                ExtensionPreferenceValue(manifestDefault: $0.jsonObject)
            }
            values[schema.name] = schema.runtimeValue(stored)
        }
        return values
    }

    func savePreferences(_ values: [String: ExtensionPreferenceValue], for item: AIExtension) throws
    {
        try secrets.setSecret(
            ExtensionRuntime.jsonString(
                from: values.mapValues { value -> Any in
                    if case .application(let path) = value { return path }
                    return value.jsonValue
                }), for: item.account)
    }

    func invoke(_ call: AIToolCall) async -> AIToolResult {
        guard core.settings.aiEnabled,
            let item = extensions.first(where: { item in
                enabledNames.contains(item.name)
                    && item.tools.contains(where: { item.wireName($0) == call.name })
            }),
            let tool = item.tools.first(where: { item.wireName($0) == call.name }),
            let arguments = JSONValue(data: Data(call.arguments.utf8)), arguments.objectValue != nil
        else {
            return .failure(call.id, "That extension tool is unavailable.")
        }
        do {
            let preferences = try preferences(for: item)
            let missing = (item.preferences + tool.preferences).filter {
                $0.required && preferences[$0.name]?.stringValue.isEmpty != false
            }
            guard missing.isEmpty else {
                return .failure(
                    call.id,
                    "Configure \(item.title) in AI Settings first: \(missing.map(\.displayTitle).joined(separator: ", "))."
                )
            }
            if core.localTools.approval != .all {
                guard
                    await core.confirm(
                        title: "Run \(tool.title)?",
                        message: "\(item.title)\n\(String(call.arguments.prefix(2_000)))",
                        symbol: "puzzlepiece.extension", confirmTitle: "Run", dismissTitle: "Cancel",
                        queued: true)
                else { return .failure(call.id, "The user declined this tool call.") }
            }
            guard !Task.isCancelled, core.settings.aiEnabled, enabledNames.contains(item.name),
                tools().contains(where: { $0.name == call.name })
            else {
                return .failure(call.id, "The tool call was cancelled.")
            }
            let file = item.directory.appendingPathComponent("tools/\(tool.name).js")
            let data = try Data(contentsOf: file)
            guard data.count <= 16_000_000, let code = String(data: data, encoding: .utf8) else {
                return .failure(call.id, "The tool bundle could not be loaded.")
            }
            let support = ExtensionCatalog.supportPath(for: "ai-\(item.name)")
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let host = try AIExtensionToolHost(account: item.account)
            let runtime = ExtensionRuntime(hostAPI: host)
            defer { runtime.shutdown() }
            try await runtime.boot(config: .current(supportDirectory: support))
            let context = ExtensionLaunchContext(
                extensionName: item.name, extensionTitle: item.title,
                commandName: tool.name, commandMode: .noView,
                assetsPath: item.directory.appendingPathComponent("assets").path,
                supportPath: support.path, preferences: preferences, caches: [:], arguments: [:],
                fallbackText: nil,
                isDarkAppearance: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
                    == .darkAqua
            )
            let input = ExtensionRuntime.jsonString(from: arguments.jsonObject)
            let result = try await runtime.invokeTool(
                code: code, file: file, context: context, arguments: input
            ) { [core] json in
                // An exported confirmation is the extension declaring a side effect, so it always asks.
                let details = JSONValue(data: Data(json.utf8))?.objectValue
                let allowed = await core.confirm(
                    title: details?["message"]?.stringValue ?? "Confirm \(tool.title)?",
                    message: String(json.prefix(2_000)), symbol: "puzzlepiece.extension",
                    confirmTitle: "Run",
                    dismissTitle: "Cancel", queued: true)
                return allowed && !Task.isCancelled && core.settings.aiEnabled
            }
            return AIToolResult(callID: call.id, content: result, isError: false)
        } catch { return .failure(call.id, error.localizedDescription) }
    }
}
