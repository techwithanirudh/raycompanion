import Foundation

/// Everything in Tinycast a global shortcut can be bound to.
enum HotKeyAction: Hashable, Sendable {
    /// Fixed actions with no command row of their own.
    case togglePalette
    case dictation
    /// Parameterised over the catalog, so a new built-in command is bindable with no case here.
    case command(CommandID)
    case app(bundleID: String)
    case settingsPane(bundleID: String)
    /// Keyed by `AppEntry.id`, which is what survives a reinstall of the extension.
    case extensionCommand(entryID: String)

    /// The UserDefaults key, and the `HotKeyCenter` registration id: one per action.
    var defaultsKey: String {
        switch self {
        case .togglePalette: "hotkey.togglePalette"
        case .dictation: "hotkey.dictation"
        case .command(let id): "hotkey." + id.rawValue
        case .app(let bundleID): "hotkey.app." + bundleID
        case .settingsPane(let bundleID): "hotkey.pane." + bundleID
        case .extensionCommand(let entryID): "hotkey.extensionCommand." + entryID
        }
    }

    /// The fixed actions every install can bind; the per-item catalogs extend them at launch.
    static let builtInActions: [HotKeyAction] =
        [.togglePalette, .dictation] + CommandID.allCases.compactMap(\.hotKeyAction)
}
