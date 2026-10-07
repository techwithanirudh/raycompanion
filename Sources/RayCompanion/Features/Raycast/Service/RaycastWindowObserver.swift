import AppKit
import ApplicationServices

@MainActor final class RaycastWindowObserver {
    let pid: pid_t
    private let onChange: () -> Bool
    private var observer: AXObserver?
    private var activation: NSObjectProtocol?
    private var pending: Task<Void, Never>?

    init(pid: pid_t, onChange: @escaping () -> Bool) {
        self.pid = pid
        self.onChange = onChange
        var observer: AXObserver?
        if AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<RaycastWindowObserver>.fromOpaque(context).takeUnretainedValue().schedule()
            }
        }, &observer) == .success, let observer {
            let app = AXUIElementCreateApplication(pid)
            let context = Unmanaged.passUnretained(self).toOpaque()
            for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXFocusedUIElementChangedNotification] {
                AXObserverAddNotification(observer, app, name as CFString, context)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            self.observer = observer
        }
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                guard let self, app.processIdentifier == self.pid else { return }
                self.schedule()
            }
        }
    }

    private func schedule() {
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            for delay in [80, 100, 160, 240, 400] {
                do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
                guard let self, !self.onChange() else { return }
            }
        }
    }

    func stop() {
        pending?.cancel()
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        activation = nil
    }
}
