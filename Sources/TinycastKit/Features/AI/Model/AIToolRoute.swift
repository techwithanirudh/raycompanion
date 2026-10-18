import Foundation

/// Which executor a model's tool call reaches: only a tool this turn offered, by its exact name,
/// and only while its server is still switched on for the chat.
enum AIToolRoute: Equatable {
    case local
    case mcp
    case unavailable

    static func resolve(
        _ name: String, local: Set<String>, mcp: Set<String>, localEnabled: Bool,
        scope: ChatToolScope
    ) -> AIToolRoute {
        if local.contains(name) {
            return localEnabled && scope.allows(AILocalTools.handle) ? .local : .unavailable
        }
        guard mcp.contains(name), let route = MCPToolName.parse(name), scope.allows(route.slug)
        else { return .unavailable }
        return .mcp
    }

    /// A CLI asks before calling through the shared bridge; the same checks, by handle and tool.
    static func permitsLocal(
        _ call: AIToolServerCall, offered: [AITool], localEnabled: Bool, scope: ChatToolScope
    ) -> Bool {
        guard call.handle == AILocalTools.handle,
            let tool = offered.first(where: { AILocalToolServer.shortName($0.name) == call.tool })
        else { return false }
        return resolve(
            tool.name, local: [tool.name], mcp: [], localEnabled: localEnabled, scope: scope)
            == .local
    }
}
