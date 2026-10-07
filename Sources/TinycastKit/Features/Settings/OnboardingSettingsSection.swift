import SwiftUI

struct OnboardingSettingsSection: View {
    @Environment(AppCore.self) private var core

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Onboarding")
                    Text("Review permissions and choose your AI.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Replay") { core.onReplaySetup?() }
            }
        }
    }
}
