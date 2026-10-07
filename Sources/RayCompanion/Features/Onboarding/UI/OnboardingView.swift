import ApplicationServices
import Combine
import PermissionFlow
import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void
    let configureAI: (@escaping () -> Void) -> Void
    let dismiss: () -> Void
    @AppStorage("onboardingStep") private var step = 0
    @State private var trusted = AXIsProcessTrusted()
    @State private var configuredAI = false
    @StateObject private var permissionFlow = PermissionFlowController()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            Group {
                switch step {
                case 0: WelcomeStep()
                case 1: PermissionStep(trusted: trusted)
                default: ReadyStep()
                }
            }.frame(maxWidth: .infinity)
            Spacer(minLength: 12)
            PanelButton(title: step == 2 ? (configuredAI ? "Start chatting" : "Choose AI") : "Continue") {
                if step == 2 {
                    if configuredAI { finish() }
                    else { configureAI { configuredAI = true } }
                } else if step == 1 && !trusted {
                    permissionFlow.authorize(pane: .accessibility, suggestedAppURLs: [Bundle.main.bundleURL])
                } else { step += 1 }
            }
            if step == 1 && !trusted {
                Button("Not now") { permissionFlow.closePanel(); step += 1 }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
            if step == 2 {
                Button(configuredAI ? "Change AI" : "Skip for now") {
                    if configuredAI { configureAI {} } else { finish() }
                }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .frame(width: SetupTheme.windowSize.width, height: SetupTheme.windowSize.height)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(SetupTheme.Card.stroke))
        .onReceive(timer) { _ in trusted = AXIsProcessTrusted() }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { item in
                    Capsule().fill(.primary.opacity(item == step ? 0.45 : 0.14))
                        .frame(width: item == step ? 14 : 5, height: 5)
                }
            }
            HStack {
                if step > 0 {
                    Button { step -= 1 } label: {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                }.buttonStyle(.plain)
            }.foregroundStyle(.secondary)
        }.frame(height: 22)
    }
}
