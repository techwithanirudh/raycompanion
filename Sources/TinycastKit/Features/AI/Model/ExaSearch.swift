import Foundation

enum ExaSearch {
    static let id = UUID(uuidString: "C11C7B42-88AC-42B1-B760-244826B12D17")!
    static let endpoint = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa"

    static func server() -> MCPServer {
        MCPServer(id: id, name: "Exa search", slug: "exa-search",
                  transport: .http(url: endpoint, headerName: "x-api-key"))
    }
}
