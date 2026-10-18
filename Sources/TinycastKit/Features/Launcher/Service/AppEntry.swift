import AppKit

struct AppEntry: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case application
        case systemSettings
        case command
        case quickAction
        case customCommand
        case snippet
        case systemAction
        case windowCommand
        case windowLayout
        case windowRoom
        case quicklink
        case appleShortcut
        case extensionCommand
        case meeting

        var descriptor: KindDescriptor {
            switch self {
            case .application:
                return KindDescriptor(
                    label: "Application", sectionTitle: "Applications",
                    openVerb: "Open Application", canHideFromSearch: true,
                    canRevealInFinder: true, canDragOut: true, isSymbolIcon: false, rankPriority: 4)
            case .systemSettings:
                return KindDescriptor(
                    label: "System Setting", sectionTitle: "System Settings",
                    openVerb: "Open System Setting", canHideFromSearch: true,
                    canRevealInFinder: true, canDragOut: false, isSymbolIcon: false, rankPriority: 1)
            case .command:
                return KindDescriptor(
                    label: "Command", sectionTitle: "Commands",
                    openVerb: "Run Command", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .quickAction:
                return KindDescriptor(
                    label: "Quick Action", sectionTitle: "Quick Actions",
                    openVerb: "Run Quick Action", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .customCommand:
                return KindDescriptor(
                    label: "Custom Command", sectionTitle: "Custom Commands",
                    openVerb: "Run Custom Command", canHideFromSearch: false,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .snippet:
                return KindDescriptor(
                    label: "Snippet", sectionTitle: "Snippets",
                    openVerb: "Paste Snippet", canHideFromSearch: false,
                    canRevealInFinder: true, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .systemAction:
                return KindDescriptor(
                    label: "System Action", sectionTitle: "System Actions",
                    openVerb: "Run System Action", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .windowCommand:
                return KindDescriptor(
                    label: "Window Command", sectionTitle: "Window Management",
                    openVerb: "Move Window", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .windowLayout:
                return KindDescriptor(
                    label: "Window Layout", sectionTitle: "Window Layouts",
                    openVerb: "Arrange Windows", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .windowRoom:
                return KindDescriptor(
                    label: "Room", sectionTitle: "Rooms", openVerb: "Enter Room",
                    canHideFromSearch: true, canRevealInFinder: false, canDragOut: false,
                    isSymbolIcon: true, rankPriority: 3)
            case .quicklink:
                return KindDescriptor(
                    label: "Quicklink", sectionTitle: "Quicklinks",
                    openVerb: "Open Quicklink", canHideFromSearch: false,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 2)
            case .appleShortcut:
                // File-backed so every row draws the Shortcuts app's own icon.
                return KindDescriptor(
                    label: "Apple Shortcut", sectionTitle: "Apple Shortcuts",
                    openVerb: "Run Shortcut", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: false, rankPriority: 3)
            case .extensionCommand:
                // The label is per-entry, the owning extension's title; this is the fallback.
                return KindDescriptor(
                    label: "Extension", sectionTitle: "Extensions",
                    openVerb: "Run Command", canHideFromSearch: true,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 3)
            case .meeting:
                return KindDescriptor(
                    label: "Meeting", sectionTitle: "Meetings",
                    openVerb: "Join Meeting", canHideFromSearch: false,
                    canRevealInFinder: false, canDragOut: false, isSymbolIcon: true, rankPriority: 1)
            }
        }
    }

    /// Fixed per kind: a new `Kind` case fails to build until it names every field.
    struct KindDescriptor: Sendable {
        let label: String
        let sectionTitle: String
        let openVerb: String
        /// Only where Settings lists a per-item checkbox to put it back: a hide is never one-way.
        let canHideFromSearch: Bool
        let canRevealInFinder: Bool
        /// Only an application: a pane or a shortcut dropped on another app opens nothing there.
        let canDragOut: Bool
        let isSymbolIcon: Bool
        /// Breaks a full tie, apps first: Calculator over Calculator History.
        let rankPriority: Int
    }

    let id: String  // file path (or "command:…" id) — always unique
    let name: String  // clean display name, never includes ".app"
    let url: URL
    let bundleID: String?
    let kind: Kind
    /// Set when a feature pane, not this entry's category pane, lists its controls and gates it.
    var settingsOwner: SettingsTab?
    /// Secondary label beside the name, for an entry whose name alone can't say what it acts on.
    var subtitle: String?
    /// Background-refresh dot for a scheduled extension command; nil everywhere else.
    var backgroundRefresh: ExtensionRefreshState?
    /// Ranked like the name: a translation, a rename, `CFBundleAlternateNames`.
    var alternateTitles: [String] = []
    /// Per-item symbol, for the one kind whose glyph is the user's choice. Nil elsewhere.
    var symbolName: String?
    /// Found by, never ranked by: a declared name, an extension's keywords.
    var keywords: [String] = []
    /// Moves when the bundle's icon changes on disk, retiring the cached bitmap. Applications only.
    var iconStamp: Int = 0
    /// Set by the feature that produced the entry when its glyph isn't derivable from `kind`.
    var iconOverride: EntryIcon?
    /// What this entry comes from — an extension's title. Labels the row; ranks as a subtitle.
    var ownerName: String?
    /// When it landed on disk, so a fresh install can be suggested before its first open.
    var installedAt: Date?
    /// The searchable form of every field above, built at publish by `buildSearchProfile`.
    var search = SearchProfile.unnamed

    /// The hotkey action for this entry, or nil when the entry has no addressable action.
    var hotKeyAction: HotKeyAction? {
        switch kind {
        case .command, .quickAction:
            return CommandCatalog.command(for: self)?.hotKeyAction
        case .application:
            return bundleID.map { .app(bundleID: $0) }
        case .systemSettings:
            return bundleID.map { .settingsPane(bundleID: $0) }
        case .customCommand, .systemAction, .windowCommand, .windowLayout, .windowRoom, .quicklink,
            .appleShortcut, .snippet, .extensionCommand, .meeting:
            return nil
        }
    }

    /// What this row draws, and the only thing any icon path needs to ask.
    var iconSource: EntryIcon { iconOverride ?? defaultIcon }

    /// Derived from the kind alone: synthetic entries get a symbol tile, everything else its file.
    private var defaultIcon: EntryIcon {
        guard kind.descriptor.isSymbolIcon else { return .file(stamp: iconStamp) }
        return .symbol(symbolName ?? kindSymbol)
    }

    private var kindSymbol: String {
        switch kind {
        case .command, .quickAction: return CommandCatalog.command(for: self)?.sfSymbol ?? "questionmark"
        case .meeting: return "video.fill"
        default: return "questionmark"
        }
    }

    /// Icon identity for a row's async load: re-skinning changes the glyph while `id` stays put.
    var iconKey: String { "\(id)|\(iconSource)" }
}
