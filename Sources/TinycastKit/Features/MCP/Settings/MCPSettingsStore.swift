import Foundation
import Observation

@MainActor
@Observable
final class MCPSettingsStore {
    private let defaults: UserDefaults

    private(set) var servers: [MCPServer] {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoded = Self.decode(defaults.data(forKey: AppSettingsKey.mcpServers.rawValue))
        servers = Self.releasingReservedSlugs(decoded)
        if servers != decoded { persist() }
    }

    func server(id: UUID) -> MCPServer? {
        servers.first { $0.id == id }
    }

    var enabledServers: [MCPServer] {
        servers.filter(\.isEnabled)
    }

    func save(_ server: MCPServer) {
        let server = normalized(server)
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
    }

    func remove(id: UUID) {
        servers.removeAll { $0.id == id }
    }

    func setTrust(_ trust: MCPTrust, for id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].trust = trust
    }

    /// A slug is derived, never typed, so `@handle` can never name two servers or nothing at all.
    private func normalized(_ server: MCPServer) -> MCPServer {
        var server = server
        server.name = server.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(servers.filter { $0.id != server.id }.map(\.slug)).union(MCPSlug.reserved)
        let derived = MCPSlug.normalize(server.name.isEmpty ? server.slug : server.name)
        if server.slug != derived || taken.contains(server.slug) {
            server.slug = MCPSlug.make(from: derived, existing: taken)
        }
        return server
    }

    /// A server saved before the app's own handle was reserved moves aside, as a new one would.
    static func releasingReservedSlugs(_ servers: [MCPServer]) -> [MCPServer] {
        var result = servers
        for index in result.indices where MCPSlug.reserved.contains(result[index].slug) {
            let taken = Set(result.map(\.slug))
            result[index].slug = MCPSlug.make(from: result[index].slug, existing: taken)
        }
        return result
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: AppSettingsKey.mcpServers.rawValue)
    }

    private static func decode(_ data: Data?) -> [MCPServer] {
        guard let data, let servers = try? JSONDecoder().decode([MCPServer].self, from: data)
        else { return [] }
        return servers
    }
}
