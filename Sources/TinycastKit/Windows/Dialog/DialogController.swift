import AppKit
import SwiftUI

/// Tinycast's own dialogs; `NSAlert`'s nested run loop would let hotkeys stack them.
@MainActor
final class DialogController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let onPresentationChanged: (Bool) -> Void
    private var panel: DialogPanel?
    private var active: Pending?
    /// Tool consent waiting its turn; anything else is refused while a dialog is up.
    private var waiting: [Pending] = []
    private var isAdvancing = false

    private struct Pending {
        let id: UUID
        let request: DialogRequest
        let continuation: CheckedContinuation<Int, Never>
    }

    init(settings: AppSettings, onPresentationChanged: @escaping (Bool) -> Void) {
        self.settings = settings
        self.onPresentationChanged = onPresentationChanged
    }

    func confirm(
        title: String, message: String?, symbol: String?, tone: DialogTone, confirmTitle: String,
        confirmRole: DialogAction.Role, dismissTitle: String = "Cancel", queued: Bool = false
    ) async -> Bool {
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: tone,
            actions: [
                DialogAction(title: confirmTitle, role: confirmRole),
                DialogAction(title: dismissTitle, role: .cancel)
            ],
            defaultIndex: 0, cancelIndex: 1)
        return await present(request, queued: queued) == 0
    }

    /// More than two ways forward; `options` is in dispatch order and the last one is the cancel.
    func choose(
        title: String, message: String?, symbol: String?, tone: DialogTone,
        options: [DialogAction], defaultIndex: Int, queued: Bool = false
    ) async -> Int {
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: tone, actions: options,
            defaultIndex: defaultIndex, cancelIndex: options.count - 1)
        return await present(request, queued: queued)
    }

    func notice(title: String, message: String, symbol: String, tone: DialogTone) async {
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: tone,
            actions: [DialogAction(title: "OK", role: .cancel)], defaultIndex: 0, cancelIndex: 0)
        _ = await present(request)
    }

    /// `queued` waits behind the dialog on screen rather than being refused, for a tool call's
    /// consent; cancelling the caller's task dismisses its dialog, shown or still waiting.
    private func present(_ request: DialogRequest, queued: Bool = false) async -> Int {
        // Keyed on `active`, so a panel still fading can't swallow the next.
        guard !Task.isCancelled, queued || !isBusy else { return request.cancelIndex }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let pending = Pending(id: id, request: request, continuation: continuation)
                if isBusy {
                    waiting.append(pending)
                } else {
                    show(pending)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.withdraw(id) }
        }
    }

    private var isBusy: Bool { active != nil || !waiting.isEmpty || isAdvancing }

    private func show(_ pending: Pending) {
        let request = pending.request
        active = pending
        onPresentationChanged(true)
        let width = metrics.size.dialogCompactWidth
        let content = hostingView(
            DialogView(
                request: request, width: width,
                onChoose: { [weak self] index in self?.finish(index) }),
            width: width, minHeight: 0)
        let panel = DialogPanel(content: content, cornerRadius: metrics.radius.panel)
        panel.delegate = self
        panel.onKey = { [weak self] key in
            guard let self else { return }
            switch key {
            case .cancel:
                finish(request.cancelIndex)
            case .confirm:
                finish(request.defaultIndex)
            }
        }
        self.panel = panel
        place(panel)
        show(panel)
    }

    /// A cancelled caller's dialog goes away as if dismissed, whether on screen or still queued.
    private func withdraw(_ id: UUID) {
        if let active, active.id == id {
            finish(active.request.cancelIndex)
        } else if let index = waiting.firstIndex(where: { $0.id == id }) {
            let pending = waiting.remove(at: index)
            pending.continuation.resume(returning: pending.request.cancelIndex)
            if !isBusy { onPresentationChanged(false) }
        }
    }

    /// Moves the full-size glass panel, avoiding the transient rim caused by scaling its content.
    private func show(_ panel: NSPanel) {
        let destination = panel.frame
        panel.alphaValue = Theme.DialogMotion.initialOpacity
        panel.setFrameOrigin(
            NSPoint(x: destination.minX, y: destination.minY - Theme.DialogMotion.offset))
        // Non-activating like the palette: key focus without pulling the user out.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Duration.dialogEnter
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            // Moving a cached surface avoids redrawing the glass at each whole-point frame step.
            panel.animator().setFrame(destination, display: false)
            panel.animator().alphaValue = 1
        }
    }

    /// Resumes before the fade finishes, so a confirmation isn't held up by animation.
    private func finish(_ index: Int) {
        guard let finished = active else { return }
        active = nil
        let closing = panel
        panel = nil
        closing?.delegate = nil
        closing?.onKey = nil
        finished.continuation.resume(returning: index)
        closing?.fadeOut(duration: Theme.Duration.dialogExit)
        guard !waiting.isEmpty else {
            onPresentationChanged(false)
            return
        }
        // The next waits out the fade, since placement reads the key window, and gives the
        // reader a beat to see that a different question is now being asked.
        isAdvancing = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Duration.dialogExit + 0.25))
            self?.advance()
        }
    }

    private func advance() {
        isAdvancing = false
        guard active == nil else { return }
        guard !waiting.isEmpty else {
            onPresentationChanged(false)
            return
        }
        show(waiting.removeFirst())
    }

    private var metrics: InterfaceMetrics { settings.interfaceSize.metrics }

    private func hostingView(_ view: some View, width: CGFloat, minHeight: CGFloat) -> NSView {
        let hosting = NSHostingView(rootView: AnyView(view.environment(\.metrics, metrics)))
        // Measure at the fixed width first: the message wraps, so height follows width.
        hosting.setFrameSize(NSSize(width: width, height: minHeight))
        let fitted = hosting.fittingSize
        hosting.setFrameSize(NSSize(width: width, height: max(fitted.height, minHeight)))
        return hosting
    }

    private func place(_ panel: NSPanel) {
        let parent = NSApp.keyWindow ?? NSApp.mainWindow
        let bounds = parent?.frame ?? NSScreen.underCursor?.visibleFrame
        guard let bounds else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
    }

    // MARK: - NSWindowDelegate

    /// After AppKit's own first-responder pick, which a view's focus request can't outlast.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        panel.focusFirstTextField()
    }

    /// Click-away resolves as a dismissal rather than leaving an orphaned dialog behind.
    func windowDidResignKey(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        panel.onKey?(.cancel)
    }
}
