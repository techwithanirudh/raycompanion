import SwiftUI

struct ExaSearchSettings: View {
    @Environment(AppCore.self) private var core
    @Environment(MCPSettingsStore.self) private var store
    @Environment(MCPCoordinator.self) private var coordinator
    @State private var key = ""
    @State private var expanded = false
    @State private var error: String?

    private var server: MCPServer? { store.server(id: ExaSearch.id) }

    var body: some View {
        DisclosureGroup("Exa search", isExpanded: $expanded) {
            Text("Search with Exa in Codex, Claude, and API chats that support tools.")
                .foregroundStyle(.secondary)
            if let server {
                Toggle("Use Exa", isOn: Binding(get: { server.isEnabled }, set: { enabled in
                    var updated = server
                    updated.isEnabled = enabled
                    store.save(updated)
                    if enabled { core.settings.mcpEnabled = true }
                    coordinator.applyEnabled()
                }))
                Text(core.settings.mcpEnabled ? coordinator.status(of: server.id).label : "MCP tools are off.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                SecureField(server == nil ? "Exa API key" : "Replace Exa API key", text: $key)
                    .textFieldStyle(.roundedBorder)
                Button("Save key", action: save).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Link("Get an Exa key", destination: URL(string: "https://dashboard.exa.ai/api-keys")!)
                Spacer()
                if server != nil { Button("Remove key", role: .destructive, action: remove) }
            }
            Text("The key stays in Keychain. Search queries go to Exa.").foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.orange) }
        }
        .onAppear {
            if Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true,
               CommandLine.arguments.contains("--exa-demo") { expanded = true }
        }
    }

    private func save() {
        do {
            try coordinator.save(ExaSearch.server(), secrets: .init(headerValue: key.trimmingCharacters(in: .whitespacesAndNewlines)))
            core.settings.mcpEnabled = true
            coordinator.applyEnabled()
            key = ""
            error = nil
        } catch { self.error = "The key could not be saved to Keychain." }
    }

    private func remove() {
        do {
            try coordinator.remove(ExaSearch.id)
            key = ""
            error = nil
        } catch { self.error = "The key could not be removed from Keychain." }
    }
}
