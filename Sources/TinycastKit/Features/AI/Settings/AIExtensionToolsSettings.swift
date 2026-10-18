import SwiftUI

struct AIExtensionToolsSettings: View {
    @Environment(AppCore.self) private var core
    @State private var presented = false

    var body: some View {
        Section("Raycast extensions") {
            SettingsRow(
                title: "AI extensions",
                subtitle: "\(core.aiExtensionTools.extensions.count) imported"
            ) {
                Button("Manage…") { presented = true }
            }
        }
        .onAppear {
            if Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true,
                CommandLine.arguments.contains("--extensions-demo")
            {
                presented = true
            }
        }
        .settingsEditorPanel(isPresented: $presented) {
            AIExtensionToolsEditor(onDone: { presented = false })
        }
    }
}

private struct AIExtensionToolsEditor: View {
    @Environment(AppCore.self) private var core
    let onDone: () -> Void
    @State private var editing: AIExtension?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SettingsEditorHeader(title: "AI extensions")
                Spacer()
                Button("Import from Raycast") { core.aiExtensionTools.importInstalled() }
            }
            .padding(Theme.Spacing.dialogInset)
            Toggle(
                "Enable all",
                isOn: Binding(
                    get: {
                        !core.aiExtensionTools.extensions.isEmpty
                            && core.aiExtensionTools.extensions.allSatisfy {
                                core.aiExtensionTools.enabledNames.contains($0.name)
                            }
                    },
                    set: { enabled in
                        let names = Set(core.aiExtensionTools.extensions.map(\.name))
                        if enabled {
                            core.aiExtensionTools.enabledNames.formUnion(names)
                        } else {
                            core.aiExtensionTools.enabledNames.subtract(names)
                        }
                    })
            )
            .toggleStyle(.checkbox)
            .disabled(core.aiExtensionTools.extensions.isEmpty)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.dialogInset)
            .padding(.bottom, Theme.Spacing.md)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if core.aiExtensionTools.extensions.isEmpty {
                        Text("Import installed extensions with AI tools.")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    ForEach(core.aiExtensionTools.extensions) { item in
                        HStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).lineLimit(1)
                                Text("\(item.tools.count) tools").font(.caption).foregroundStyle(
                                    .secondary)
                            }
                            Spacer(minLength: Theme.Spacing.md)
                            if !item.schemas.isEmpty {
                                Button("Configure…") { editing = item }
                            }
                            Toggle(
                                item.title,
                                isOn: Binding(
                                    get: { core.aiExtensionTools.enabledNames.contains(item.name) },
                                    set: { enabled in
                                        if enabled {
                                            core.aiExtensionTools.enabledNames.insert(item.name)
                                        } else {
                                            core.aiExtensionTools.enabledNames.remove(item.name)
                                        }
                                    })
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(item.title)
                        }
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Theme.Colors.cardFill,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }
                    if let error = core.aiExtensionTools.error {
                        Text(error).foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.dialogInset)
                .padding(.bottom, Theme.Spacing.dialogInset)
            }
            .frame(height: 380)
            .overflowFade(includingTop: true)
            Divider()
            HStack {
                Text("Logins are separate from Raycast.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
            .padding(Theme.Spacing.dialogInset)
        }
        .frame(width: 580)
        .settingsEditorPanelSurface()
        .settingsEditorPanel(item: $editing) { item in
            AIExtensionPreferencesEditor(item: item, onDone: { editing = nil })
        }
    }
}

private struct AIExtensionPreferencesEditor: View {
    @Environment(AppCore.self) private var core
    let item: AIExtension
    let onDone: () -> Void
    @State private var values: [String: ExtensionPreferenceValue] = [:]
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            SettingsEditorHeader(title: item.title).frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.dialogInset)
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(item.schemas, id: \.name) { schema in
                        SettingsEditorField(schema.displayTitle) {
                            if schema.kind == .checkbox {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { values[schema.name]?.boolValue ?? false },
                                        set: { values[schema.name] = .bool($0) })
                                ).labelsHidden()
                            } else if schema.kind == .dropdown {
                                Picker("", selection: text(schema)) {
                                    ForEach(schema.options, id: \.value) {
                                        Text($0.title).tag($0.value)
                                    }
                                }.labelsHidden()
                            } else if schema.kind == .password {
                                SecureField(schema.placeholder ?? "", text: text(schema))
                                    .settingsEditorTextField()
                            } else {
                                TextField(schema.placeholder ?? "", text: text(schema))
                                    .settingsEditorTextField()
                            }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.orange) }
                }.padding(Theme.Spacing.dialogInset)
            }
            .frame(maxHeight: 340)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onDone).keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try core.aiExtensionTools.savePreferences(values, for: item)
                        onDone()
                    } catch { self.error = "Could not save settings to Keychain." }
                }.keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.bordered)
            .padding(Theme.Spacing.dialogInset)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .settingsEditorPanelSurface()
        .onAppear {
            do { values = try core.aiExtensionTools.preferences(for: item) } catch {
                self.error = "Could not read saved settings."
            }
        }
    }

    private func text(_ schema: ExtensionPreferenceSchema) -> Binding<String> {
        Binding(
            get: { values[schema.name]?.stringValue ?? "" },
            set: { values[schema.name] = .string($0) })
    }
}
