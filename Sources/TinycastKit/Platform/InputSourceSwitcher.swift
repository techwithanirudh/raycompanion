import AppKit
import Carbon.HIToolbox

/// Holds the keyboard input source at the palette's preferred one for the life of one summon.
@MainActor
final class InputSourceSwitcher {
    /// The source to restore is kept as the object TIS vended, so hiding never re-reads the list.
    private struct Session {
        let previousSource: TISInputSource
        let preferredInputSourceID: String
        var applied = false
    }

    private var session: Session?

    /// Records what to go back to; skipped when the preferred source is already the active one.
    func beginSession(preferredInputSourceID: String?) {
        guard session == nil, let preferredInputSourceID,
            let current = Self.currentSource(),
            Self.identifier(of: current) != preferredInputSourceID
        else { return }
        session = Session(previousSource: current, preferredInputSourceID: preferredInputSourceID)
    }

    /// Goes through the field's own context, so the switch follows the palette's focus.
    func applySession(to inputContext: NSTextInputContext) {
        guard let session, !session.applied else { return }
        inputContext.selectedKeyboardInputSource = session.preferredInputSourceID
        self.session?.applied = true
    }

    /// Undoes only our own switch: a source picked since, by the user or another app, stands.
    func endSession() {
        guard let session else { return }
        self.session = nil
        guard session.applied, let current = Self.currentSource(),
            Self.identifier(of: current) == session.preferredInputSourceID
        else { return }
        TISSelectInputSource(session.previousSource)
    }

    private static func currentSource() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    private static func identifier(of source: TISInputSource) -> String? {
        property(kTISPropertyInputSourceID, of: source)
    }

    /// TIS vends untyped pointers, so an unexpected type reads as absent, not a trap.
    private static func property<Value>(_ key: CFString, of source: TISInputSource) -> Value? {
        guard let value = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue() as? Value
    }
}
