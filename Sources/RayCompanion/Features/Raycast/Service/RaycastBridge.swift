import AppKit
import ApplicationServices
import Observation
import ChatCore

@MainActor @Observable final class RaycastBridge {
    var status = "Tab handoff paused"
    var isRunning = false
    private var engine: RaycastEventTap?
    private var timer: Timer?
    private var generation = UUID()
    private var overlayOpen = false
    private var windowObserver: RaycastWindowObserver?
    let settings: Settings
    var onPrompt: ((String, CGRect?) -> Bool)?
    var onRootOpened: ((CGRect?) -> Void)?
    var shouldResume = false

    init(settings: Settings) { self.settings = settings }
    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(); _ = self?.resumeIfRootAvailable() }
        }
    }
    func refresh() {
        if !settings.isTesting {
            let enabled = UserDefaults.standard.bool(forKey: "interceptTab")
            if enabled != settings.interceptTab { settings.interceptTab = enabled }
        }
        guard UserDefaults.standard.object(forKey: "aiEnabled") as? Bool != false else { stopEngine(); status = "AI is disabled in Settings"; return }
        guard !overlayOpen else { stopEngine(); status = "Chat open · Tab interception paused"; return }
        guard settings.interceptTab else { stopEngine(); status = "Tab handoff paused"; return }
        guard AXIsProcessTrusted() else { stopEngine(); status = "Accessibility permission needed"; return }
        guard let raycast = NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").first else {
            windowObserver?.stop(); windowObserver = nil
            stopEngine(); status = "Open Raycast to enable the handoff"; return
        }
        if windowObserver?.pid != raycast.processIdentifier {
            windowObserver?.stop()
            windowObserver = RaycastWindowObserver(pid: raycast.processIdentifier) { [weak self] in
                self?.resumeIfRootAvailable() ?? true
            }
        }
        if engine?.pid == raycast.processIdentifier { return }
        stopEngine()
        let generation = self.generation
        let engine = RaycastEventTap(pid: raycast.processIdentifier) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                switch result {
                case .ready: isRunning = true; status = "Ready · Raycast-only Tab handoff"
                case .failed: stopEngine(); status = "Raycast keyboard tap unavailable"
                case .captured(let prompt, let bounds, let field):
                    if onPrompt?(prompt, bounds) == true { field.clear(ifUnchanged: prompt) }
                case .rejected(let reason): status = reason
                }
            }
        }
        self.engine = engine
        engine.start()
    }
    static func inspectCurrentRoot() {
        print("Accessibility trusted: \(AXIsProcessTrusted())")
        guard AXIsProcessTrusted(), let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").first else { return }
        let engine = RaycastEventTap(pid: app.processIdentifier) { result in
            if case .rejected(let reason) = result { print(reason) }
        }
        if let capture = engine.inspect() { print("Root captured: true; prompt length: \(capture.0.count)") }
    }
    func setOverlayOpen(_ open: Bool) { overlayOpen = open; refresh() }
    private func resumeIfRootAvailable() -> Bool {
        guard shouldResume, settings.interceptTab else { return true }
        guard !overlayOpen else { return false }
        guard let capture = engine?.inspect() else { return false }
        onRootOpened?(capture.1)
        return true
    }
    func stop() { timer?.invalidate(); timer = nil; windowObserver?.stop(); windowObserver = nil; stopEngine() }
    private func stopEngine() { generation = UUID(); engine?.stop(); engine = nil; isRunning = false }
}
