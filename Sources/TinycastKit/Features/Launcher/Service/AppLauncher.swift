import AppKit

enum AppLauncher {
    @MainActor
    static func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        bringFileViewerForwardIfRefused()
    }

    /// While `.regular` and inactive, cooperative activation refuses the viewer's own activation.
    @MainActor
    private static func bringFileViewerForwardIfRefused() {
        guard NSApp.activationPolicy() == .regular, !NSApp.isActive,
            let viewer = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: fileViewerBundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: viewer, configuration: NSWorkspace.OpenConfiguration())
    }

    /// The global `NSFileViewer` default is how a replacement file viewer takes over reveals.
    private static var fileViewerBundleID: String {
        UserDefaults.standard.string(forKey: "NSFileViewer") ?? "com.apple.finder"
    }

    /// Opens System Settings at the pane backed by the given extension bundle ID.
    @MainActor
    static func openSettingsPane(bundleID: String) {
        guard let url = URL(string: "x-apple.systempreferences:" + bundleID) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Focus the app if it isn't frontmost, hide it if it is, launch it if it isn't running.
    @MainActor
    static func toggle(bundleID: String) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first
        if let running, running.isActive {
            running.hide()
            return
        }
        if let url = running?.bundleURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        {
            // Dock-click semantics; a bare `activate()` does none of it reliably.
            NSWorkspace.shared.openApplication(
                at: url, configuration: NSWorkspace.OpenConfiguration())
        } else if let running {
            // Running app whose bundle URL can't be resolved (moved or deleted since launch).
            running.unhide()
            running.activate()
        }
    }
}
