import AppKit
import Carbon.HIToolbox

/// One dialog's panel; keys go through `sendEvent`, so Esc/↵ need no focused subview.
final class DialogPanel: NSPanel {
    /// What the panel saw, not what it means.
    enum Key {
        case cancel
        case confirm
    }

    var onKey: ((Key) -> Void)?

    init(content: NSView, cornerRadius: CGFloat) {
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .dialog
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Suppresses AppKit's own window animation; `fadeIn`/`fadeOut` replace it.
        animationBehavior = .none
        isReleasedWhenClosed = false
        content.wantsLayer = true
        content.layer?.cornerRadius = cornerRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        contentView = content
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let onKey else {
            super.sendEvent(event)
            return
        }
        switch Int(event.keyCode) {
        // A held key repeats; one press answers one dialog, never the consent queued behind it.
        case kVK_Escape:
            if !event.isARepeat { onKey(.cancel) }
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if !event.isARepeat { onKey(.confirm) }
        default:
            super.sendEvent(event)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func focusFirstTextField() {
        // SwiftUI builds its text fields on first layout, which may not have run by turning key.
        contentView?.layoutSubtreeIfNeeded()
        guard let field = contentView.flatMap(Self.firstTextField(in:)) else { return }
        makeFirstResponder(field)
    }

    private static func firstTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap(firstTextField(in:)).first
    }
}
