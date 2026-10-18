import SwiftUI

struct AILocalToolsSettings: View {
    @Environment(AppCore.self) private var core

    var body: some View {
        @Bindable var tools = core.localTools
        Section("Tools") {
            Toggle("Calculator, files and selected text", isOn: $tools.enabled)
            Picker("Tool approval", selection: $tools.approval) {
                ForEach(AIToolApproval.allCases, id: \.self) { approval in
                    Text(approval.rawValue).tag(approval)
                }
            }
            .settingsEnabled(tools.enabled)
            SettingsRow(
                title: "File access",
                subtitle: tools.folders.isEmpty
                    ? "No folders allowed"
                    : tools.folders.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(
                        separator: ", ")
            ) {
                Button("Choose folders…") { tools.chooseFolders() }
                if !tools.folders.isEmpty {
                    Button("Clear") { tools.folders = [] }
                }
            }
            .settingsEnabled(tools.enabled)
        }
    }
}
