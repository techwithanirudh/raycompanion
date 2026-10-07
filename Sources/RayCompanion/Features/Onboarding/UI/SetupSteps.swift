import AppKit
import SwiftUI
import PermissionFlow

struct WelcomeStep: View {
    var body: some View {
        StepLayout(title: "Meet RayCompanion", hint: "AI chat and dictation, alongside Raycast.") {
            Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high)
                .frame(width: 76, height: 76)
        }
    }
}

struct PermissionStep: View {
    let trusted: Bool
    var body: some View {
        StepLayout(title: "Connect to Raycast", hint: "Allow \(String(localized: PermissionFlowResources.accessibilityNameResource)) to open chat from Raycast with Tab.") {
            Image(systemName: "hand.raised.fill").font(.system(size: 48, weight: .medium))
                .foregroundStyle(.orange).frame(width: 100, height: 100)
                .background(SetupTheme.Card.fill, in: RoundedRectangle(cornerRadius: 24))
        } content: {
            if trusted { DoneLine(title: "Permission allowed") }
        }
    }
}

struct ReadyStep: View {
    var body: some View {
        StepLayout(title: "Choose your AI", hint: "Use Apple Intelligence, an AI app, or an API key.") {
            Image(systemName: "sparkles").font(.system(size: 48, weight: .medium))
                .foregroundStyle(.blue).frame(width: 100, height: 100)
                .background(SetupTheme.Card.fill, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
