import CryptoKit
import Foundation

struct AIExtensionTool: Identifiable, Equatable, Sendable {
    let name: String
    let title: String
    let description: String
    let input: JSONValue
    let preferences: [ExtensionPreferenceSchema]
    var id: String { name }
}

struct AIExtension: Identifiable, Equatable, Sendable {
    let name: String
    let title: String
    let directory: URL
    let tools: [AIExtensionTool]
    let preferences: [ExtensionPreferenceSchema]
    var id: String { name }
    var account: UUID {
        let bytes = Array(SHA256.hash(data: Data(name.utf8)).prefix(16))
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8],
                bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
    var schemas: [ExtensionPreferenceSchema] {
        var names = Set<String>()
        return (preferences + tools.flatMap(\.preferences)).filter {
            names.insert($0.name).inserted
        }
    }
    func wireName(_ tool: AIExtensionTool) -> String {
        MCPToolName.compose(
            slug: AILocalTools.handle,
            tool: "ext-\(account.uuidString.prefix(8).lowercased())-\(tool.name)")
    }

    static func load(_ directory: URL) -> AIExtension? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("package.json")),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let name = json["name"] as? String
        else { return nil }
        let tools = (json["tools"] as? [[String: Any]] ?? []).compactMap {
            raw -> AIExtensionTool? in
            guard let name = raw["name"] as? String,
                name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
                let inputData = try? JSONSerialization.data(
                    withJSONObject: raw["input"] ?? ["type": "object", "properties": [:]]),
                let input = JSONValue(data: inputData),
                input.objectValue?["type"]?.stringValue == "object",
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("tools/\(name).js").path)
            else { return nil }
            return AIExtensionTool(
                name: name, title: raw["title"] as? String ?? name,
                description: raw["description"] as? String ?? name, input: input,
                preferences: (raw["preferences"] as? [Any] ?? []).compactMap(
                    ExtensionPreferenceSchema.init(json:)))
        }
        guard !tools.isEmpty else { return nil }
        return AIExtension(
            name: name, title: json["title"] as? String ?? name, directory: directory, tools: tools,
            preferences: (json["preferences"] as? [Any] ?? []).compactMap(
                ExtensionPreferenceSchema.init(json:)))
    }
}
