import Foundation

public struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable { case user, assistant }
    public var id: UUID
    public var role: Role
    public var content: String
    public init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

public struct Conversation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var messages: [ChatMessage] = []
    public var title: String { String(messages.first?.content.prefix(48) ?? "New conversation") }
    public init() {}
}

public struct HistoryFile: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> [Conversation] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Conversation].self, from: Data(contentsOf: url))
    }
    public func save(_ conversations: [Conversation]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(conversations).write(to: url, options: .atomic)
    }
}

public enum RootSearchGate {
    public static func accepts(isRaycast: Bool, hasRootResults: Bool, isSearchField: Bool, hasOverlay: Bool, plainTab: Bool) -> Bool {
        isRaycast && hasRootResults && isSearchField && !hasOverlay && plainTab
    }
}
