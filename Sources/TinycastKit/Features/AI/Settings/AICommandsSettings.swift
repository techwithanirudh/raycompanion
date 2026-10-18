import SwiftUI

struct AICommandsSettings: View {
    var body: some View {
        Section {
            ForEach(CommandCatalog.entries(ownedBy: .ai)) { entry in
                SettingsRow(title: entry.name) {
                    AppIconView(app: entry)
                        .frame(width: SettingsListMetrics.iconSize, height: SettingsListMetrics.iconSize)
                } trailing: {
                    if let action = entry.hotKeyAction {
                        ShortcutRecorder(action: action)
                    }
                }
            }
        } header: {
            SettingsSectionHeader(.aiCommands)
        }
    }
}
