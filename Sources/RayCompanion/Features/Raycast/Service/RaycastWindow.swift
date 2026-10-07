import AppKit
import ApplicationServices

@MainActor final class RaycastWindow {
    private let application: NSRunningApplication
    private let window: AXUIElement?
    let bounds: CGRect?

    init?() {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: "com.raycast.macos").first else { return nil }
        self.application = application
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.1)
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        window = value.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
        var position: CFTypeRef?
        var dimensions: CFTypeRef?
        var point = CGPoint.zero
        var size = CGSize.zero
        if let window,
           AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &dimensions) == .success,
           let position, let dimensions,
           CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(dimensions) == AXValueGetTypeID(),
           AXValueGetValue(position as! AXValue, .cgPoint, &point),
           AXValueGetValue(dimensions as! AXValue, .cgSize, &size) {
            bounds = CGRect(origin: point, size: size)
        } else { bounds = nil }
    }

    func restore() {
        guard !application.isTerminated, let url = application.bundleURL else { return }
        if application.isActive {
            if let window { AXUIElementPerformAction(window, kAXRaiseAction as CFString) }
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self, let window else { return }
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            }
        }
    }
}
