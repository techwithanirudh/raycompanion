import AppKit

@MainActor
final class AIExtensionToolHost: ExtensionHostAPI {
    private let account: UUID
    private let store = KeychainSecretStore(scope: "extension-tool-storage")
    private let fetcher = ExtensionFetcher()
    private var caches: [String: [String: String]] = [:]
    private var values: [String: JSONValue] = [:]

    init(account: UUID) throws {
        self.account = account
        if let saved = try store.secret(for: account) {
            values = JSONValue(data: Data(saved.utf8))?.objectValue ?? [:]
        }
    }

    func perform(api: String, method: String, arguments: [RenderValue]) async throws -> String {
        let result: Any?
        switch api {
        case "fetch": result = try await fetcher.request(arguments.first)
        case "storage":
            let key = arguments.first?.stringValue ?? ""
            switch method {
            case "get": result = values[key]?.jsonObject
            case "all": result = values.mapValues(\.jsonObject)
            case "set":
                if let value = arguments[safe: 1],
                    let data = try? JSONSerialization.data(
                        withJSONObject: value.jsonValue, options: [.fragmentsAllowed])
                {
                    values[key] = JSONValue(data: data)
                }
                try save()
                result = nil
            case "remove":
                values.removeValue(forKey: key)
                try save()
                result = nil
            case "clear":
                values = [:]
                try save()
                result = nil
            default: throw ExtensionHostError.unknown("storage.\(method)")
            }
        case "cache":
            let namespace = arguments.first?.stringValue ?? "default"
            let key = arguments[safe: 1]?.stringValue
            switch method {
            case "set":
                if let key {
                    caches[namespace, default: [:]][key] = arguments[safe: 2]?.stringValue
                }
                result = nil
            case "remove":
                if let key { caches[namespace]?.removeValue(forKey: key) }
                result = nil
            case "clear":
                caches[namespace] = [:]
                result = nil
            default: result = nil
            }
        case "feedback": result = method == "toast" ? 1 : nil
        case "oauth":
            throw ExtensionHostError.unsupported(
                "OAuth login in AI tools; Raycast logins are not shared")
        default: throw ExtensionHostError.unsupported("\(api).\(method) in AI tools")
        }
        return ExtensionRuntime.jsonString(from: result)
    }

    private func save() throws {
        try store.setSecret(
            ExtensionRuntime.jsonString(from: values.mapValues(\.jsonObject)), for: account)
    }

    func sessionEnded() {}
}
