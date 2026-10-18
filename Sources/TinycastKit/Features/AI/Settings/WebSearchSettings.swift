import SwiftUI

private enum WebSearchType: String, CaseIterable, Identifiable {
    case off, provider, exa

    var id: Self { self }
    var title: String {
        switch self {
        case .off: "Off"
        case .provider: "Provider"
        case .exa: "Exa"
        }
    }
}

struct WebSearchSettings: View {
    @Environment(AppCore.self) private var core
    @Environment(AISettingsStore.self) private var settings
    @Environment(MCPSettingsStore.self) private var store
    @Environment(MCPCoordinator.self) private var coordinator
    @State private var choosingExa = false
    @State private var editorPresented = false

    private var server: MCPServer? { store.server(id: ExaSearch.id) }
    private var selection: WebSearchType {
        if choosingExa || server?.isEnabled == true { return .exa }
        return settings.webSearchEnabled ? .provider : .off
    }

    var body: some View {
        Section {
            Picker(selection: Binding(get: { selection }, set: { select($0) })) {
                ForEach(WebSearchType.allCases) { Text($0.title).tag($0) }
            } label: {
                SettingsRowTitle(.aiWebSearch, "Search type")
            }
            if selection == .exa {
                SettingsRow(title: "Exa", subtitle: server.map {
                    core.settings.mcpEnabled ? coordinator.status(of: $0.id).label : "Tools are off"
                }) {
                    Button(server == nil ? "Set up…" : "Edit key…") { editorPresented = true }
                }
            }
        } header: {
            SettingsSectionHeader(.aiWebSearch)
        } footer: {
            if selection == .provider {
                Text("Available with Codex and OpenRouter.")
            }
        }
        .settingsEditorPanel(isPresented: $editorPresented) {
            ExaKeyEditor(hasKey: server != nil, onSave: save, onDelete: remove,
                         onCancel: { editorPresented = false })
        }
    }

    private func select(_ type: WebSearchType) {
        choosingExa = type == .exa
        settings.webSearchEnabled = type == .provider
        if var server {
            server.isEnabled = type == .exa
            store.save(server)
            if server.isEnabled { core.settings.mcpEnabled = true }
            coordinator.applyEnabled()
        }
    }

    private func save(_ key: String) -> String? {
        do {
            try coordinator.save(ExaSearch.server(), secrets: .init(
                headerValue: key.trimmingCharacters(in: .whitespacesAndNewlines)))
            settings.webSearchEnabled = false
            core.settings.mcpEnabled = true
            coordinator.applyEnabled()
            editorPresented = false
            return nil
        } catch { return "Could not save the key to Keychain." }
    }

    private func remove() -> String? {
        do {
            try coordinator.remove(ExaSearch.id)
            choosingExa = false
            editorPresented = false
            return nil
        } catch { return "Could not delete the key from Keychain." }
    }
}

private struct ExaKeyEditor: View {
    let hasKey: Bool
    let onSave: (String) -> String?
    let onDelete: () -> String?
    let onCancel: () -> Void
    @State private var key = ""
    @State private var error: String?
    @State private var deleting = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsEditorHeader(title: hasKey ? "Edit Exa key" : "Set up Exa")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.dialogInset)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SettingsEditorField("API key") {
                    SecureField("API key", text: $key,
                                prompt: Text(hasKey ? "Enter replacement key" : "Enter key"))
                        .settingsEditorTextField()
                }
                Link("Get API key", destination: URL(string: "https://dashboard.exa.ai/api-keys")!)
                if let error { Text(error).foregroundStyle(.orange) }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .padding(.horizontal, Theme.Spacing.dialogInset)
            .padding(.bottom, Theme.Spacing.dialogInset)
            Divider()
            HStack(spacing: Theme.Spacing.md) {
                if hasKey {
                    Button("Delete key", role: .destructive) { deleting = true }
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { error = onSave(key) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(Theme.Spacing.dialogInset)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .settingsEditorPanelSurface()
        .confirmationDialog("Delete Exa API key?", isPresented: $deleting) {
            Button("Delete key", role: .destructive) { error = onDelete() }
        }
    }
}
