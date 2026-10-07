import AVFoundation
import Combine
import SwiftUI
import PermissionFlow

struct PermissionsSettingsView: View {
    @Environment(AppCore.self) private var core
    @AppStorage("interceptTab") private var interceptTab = false
    @State private var accessibilityTrusted = Permissions.isAccessibilityTrusted()
    @State private var microphoneAccess = Permissions.microphoneAccess()
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(get: { core.settings.launchAtLogin }, set: { core.settings.launchAtLogin = $0 }))
                Text("Run in the background without opening a window.").foregroundStyle(.secondary)
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
                Text("Type a question in Raycast, then press Tab. Press Tab with no question to reopen your chat.")
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
                        Text("Lets RayCompanion read your question in Raycast and paste dictated text.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.lg)
                    status(accessibilityStatus)
                    PermissionFlowButton(title: accessibilityTrusted ? "Open…" : "Grant Access…", pane: .accessibility, suggestedAppURLs: [Bundle.main.bundleURL])
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
                    status(microphoneStatus)
                    Button(microphoneAccess == .notDetermined ? "Grant Access…" : "Open…") {
                        if microphoneAccess == .notDetermined {
                            Task { _ = await Permissions.requestMicrophoneAccess(); refresh() }
                        } else { Permissions.openMicrophoneSettings() }
                    }
                }
            } header: {
                SettingsSectionHeader(.permissionsMicrophone)
            }
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.permissions)
        .onAppear(perform: refresh)
        .onReceive(refreshTimer) { _ in refresh() }
    }

    private func status(_ value: (title: String, symbol: String, tint: Color)) -> some View {
        Label(value.title, systemImage: value.symbol)
            .foregroundStyle(value.tint)
            .fixedSize()
    }

    private var accessibilityStatus: (title: String, symbol: String, tint: Color) {
        accessibilityTrusted
            ? ("Granted", "checkmark.circle.fill", .green)
            : ("Not granted", "exclamationmark.triangle.fill", .orange)
    }

    private var microphoneStatus: (title: String, symbol: String, tint: Color) {
        switch microphoneAccess {
        case .authorized: return ("Granted", "checkmark.circle.fill", .green)
        case .notDetermined: return ("Not asked yet", "questionmark.circle.fill", .secondary)
        default: return ("Not granted", "exclamationmark.triangle.fill", .orange)
        }
    }

    private func refresh() {
        let trusted = Permissions.isAccessibilityTrusted()
        if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
        let microphone = Permissions.microphoneAccess()
        if microphone != microphoneAccess { microphoneAccess = microphone }
    }
}
