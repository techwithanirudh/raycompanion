import SwiftUI

struct UpdateSettingsSection: View {
    @Environment(AppCore.self) private var core

    var body: some View {
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: Binding(
                get: { core.updater.checksAutomatically },
                set: { core.updater.checksAutomatically = $0 }))
            Toggle("Install updates automatically", isOn: Binding(
                get: { core.updater.downloadsAutomatically },
                set: { core.updater.downloadsAutomatically = $0 }))
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Software updates")
                    Text(core.updater.lastCheck.map {
                        "Last checked \($0.formatted(date: .abbreviated, time: .shortened))"
                    } ?? "Not checked yet")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check Now") { core.updater.checkForUpdates() }
                    .disabled(!core.updater.canCheck)
            }
        }
        .disabled(!core.updater.isConfigured)
    }
}
