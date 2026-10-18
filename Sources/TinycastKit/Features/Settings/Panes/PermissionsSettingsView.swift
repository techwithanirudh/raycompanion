import SwiftUI
import PermissionFlow

struct PermissionsSettingsView: View {
    @Environment(AppCore.self) private var core
    @AppStorage("interceptTab") private var interceptTab = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(get: { core.settings.launchAtLogin }, set: { core.settings.launchAtLogin = $0 }))
            }
            Section("Appearance") {
                Picker("Theme", selection: Binding(get: { core.settings.appearance }, set: { core.settings.appearance = $0 })) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }
            Section("Raycast") {
                Toggle("Open chat with Tab", isOn: $interceptTab)
                Text("Press Tab in Raycast to ask a question or reopen chat.")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: SettingsListMetrics.iconSize - Theme.Spacing.xs))
                        .frame(width: SettingsListMetrics.iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        SettingsRowTitle(.permissionsAccessibility, SettingsAnchor.permissionsAccessibility.title)
                        Text("Open chat from Raycast and insert dictated text.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.lg)
                    permissionButton(.accessibility)
                }
            } header: {
                SettingsSectionHeader(.permissionsAccessibility)
            }
            Section {
                HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: SettingsListMetrics.iconSize - Theme.Spacing.xs))
                        .frame(width: SettingsListMetrics.iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        SettingsRowTitle(.permissionsMicrophone, "Microphone")
                        Text("Records audio only while dictating.").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.lg)
                    permissionButton(.microphone)
                }
            } header: {
                SettingsSectionHeader(.permissionsMicrophone)
            }
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.permissions)
    }

    private func permissionButton(_ pane: PermissionFlowPane) -> some View {
        PermissionFlowButton(pane: pane, suggestedAppURLs: [Bundle.main.bundleURL]) { state in
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: state.systemImage)
                    .foregroundStyle(state.isGranted ? Color.green : Color.primary)
                Text(state.isGranted ? "Open…" : "Grant Access…")
            }
            .accessibilityValue(state.isGranted ? "Granted" : state.defaultTitle)
        }
    }
}
