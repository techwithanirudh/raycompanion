import AppKit
import SwiftUI

@MainActor final class OnboardingWindowController {
    private var window: NSWindow?
    private(set) var isInProgress = false
    private let onFinish: () -> Void
    private let onConfigureAI: (NSWindow, @escaping () -> Void) -> Void
    private let onVisibilityChanged: (NSWindow, Bool) -> Void
    init(onFinish: @escaping () -> Void, onConfigureAI: @escaping (NSWindow, @escaping () -> Void) -> Void, onVisibilityChanged: @escaping (NSWindow, Bool) -> Void) {
        self.onFinish = onFinish
        self.onConfigureAI = onConfigureAI
        self.onVisibilityChanged = onVisibilityChanged
    }
    func show(step: Int? = nil) {
        isInProgress = true
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
        if let step { UserDefaults.standard.set(step, forKey: "onboardingStep") }
        if window == nil {
            let window = SetupWindow(contentRect: CGRect(origin: .zero, size: SetupTheme.windowSize), styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "RayCompanion Setup"
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.onClose = { [weak self] in self?.dismiss() }
            window.contentViewController = NSHostingController(rootView: OnboardingView(finish: { [weak self] in
                self?.isInProgress = false
                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                self?.dismiss()
                self?.onFinish()
            }, configureAI: { [weak self, weak window] done in
                if let window { self?.onConfigureAI(window, done) }
            }, dismiss: { [weak self] in self?.dismiss() }))
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            if let bounds = screen?.visibleFrame {
                let size = SetupTheme.windowSize
                window.setFrame(CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height), display: false)
            }
            self.window = window
        }
        if let window {
            onVisibilityChanged(window, true)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    private func dismiss() {
        guard let window else { return }
        window.orderOut(nil)
        onVisibilityChanged(window, false)
    }
}

private final class SetupWindow: NSWindow {
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func performClose(_ sender: Any?) { onClose?() }
}
