import Foundation

/// Owns every binding: persistence, registration with both engines, conflicts and dispatch.
@MainActor
@Observable
final class HotKeyManager {
    var onTogglePalette: (() -> Void)?
    var onDictationPressed: (() -> Void)?
    var onDictationReleased: (() -> Void)?
    var onDictationCancelled: (() -> Void)?
    var dictationEnabled = false {
        didSet {
            guard dictationEnabled != oldValue else { return }
            if !dictationEnabled { onDictationCancelled?() }
            syncModifierTaps()
        }
    }
    var dictationHoldToTalk = false {
        didSet {
            guard dictationHoldToTalk != oldValue else { return }
            onDictationCancelled?()
            syncModifierTaps()
        }
    }
    /// The launcher's own command funnel, so a shortcut and a palette row run the same thing.
    var onRunCommand: ((CommandID) -> Void)?
    var onRunExtensionCommand: ((String) -> Void)?
    /// Names what only the stores know; the fixed catalogs resolve here. Set in `AppCore.start()`.
    var displayName: ((HotKeyAction) -> String?)?
    /// Whether the action's launcher category is switched on. Set in `AppCore.start()`.
    var allowsAction: ((HotKeyAction) -> Bool)?

    /// The recorder currently capturing, which also pauses both engines.
    var recordingAction: HotKeyAction? {
        didSet {
            guard recordingAction != oldValue else { return }
            let recording = recordingAction != nil
            if recording, dictationEnabled, dictationHoldToTalk { onDictationCancelled?() }
            center.isPaused = recording
            modifierTapMonitor.isPaused = recording
            if let recordingAction {
                capture.start(action: recordingAction, hotKeys: self)
            } else {
                capture.stop()
            }
        }
    }

    let modifierTapMonitor = ModifierTapMonitor()
    /// Live state of the open recorder, read by its callout.
    let capture = ShortcutCaptureSession()

    private let center = HotKeyCenter()
    private var modifierTaps: [HotKeyBinding: HotKeyAction] = [:]
    /// Every binding, loaded once in `start()` and written through on change.
    private var bindings: [HotKeyAction: HotKeyBinding] = [:]
    /// Part of `AppIndex`'s cache key: a bound entry leaves the launcher's Suggestions.
    private(set) var revision = 0
    @ObservationIgnored private var candidateActionsCache: [HotKeyAction]?
    // Reused: the startup load decodes once per candidate action.
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let boundKey = "boundAppBundleIDs"
    private let boundPaneKey = "boundPaneBundleIDs"
    private let boundExtensionCommandKey = "boundExtensionCommandEntryIDs"

    func startAICombinations() {
        for action in [HotKeyAction.command(.quickAI), .command(.aiChat), .dictation] {
            bindings[action] = storedBinding(for: action)
            register(action)
        }
        revision &+= 1
    }

    /// Never pruned at launch: not-installed-yet and gone are indistinguishable there.
    var boundExtensionCommandEntryIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundExtensionCommandKey) ?? []
    }

    /// Bundle IDs holding a per-app hotkey, so `start()` knows which records to load.
    var boundBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundKey) ?? []
    }

    /// Settings-pane bundle IDs with a hotkey — same role as `boundBundleIDs`, own namespace.
    var boundPaneBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundPaneKey) ?? []
    }

    func binding(for action: HotKeyAction) -> HotKeyBinding? { bindings[action] }

    private func storedBinding(for action: HotKeyAction) -> HotKeyBinding? {
        // The stored value is a JSON string; anything else reads as unbound.
        guard
            let json = UserDefaults.standard.string(forKey: action.defaultsKey),
            let data = json.data(using: .utf8)
        else { return nil }
        return try? decoder.decode(HotKeyBinding.self, from: data)
    }

    /// Persists or clears the binding and swaps live registration.
    func setBinding(_ binding: HotKeyBinding?, for action: HotKeyAction) {
        if action == .dictation, binding != self.binding(for: action) { onDictationCancelled?() }
        let previous = bindings[action]
        if let binding,
            let data = try? encoder.encode(binding),
            let json = String(data: data, encoding: .utf8)
        {
            bindings[action] = binding
            UserDefaults.standard.set(json, forKey: action.defaultsKey)
        } else {
            bindings[action] = nil
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
        revision &+= 1
        // Unregister unconditionally: the previous binding may have been a combo.
        center.unregister(id: action.defaultsKey)
        register(action)

        switch action {
        case .app(let bundleID):
            index(bundleID, bound: binding != nil, key: boundKey)
        case .settingsPane(let bundleID):
            index(bundleID, bound: binding != nil, key: boundPaneKey)
        case .extensionCommand(let entryID):
            index(entryID, bound: binding != nil, key: boundExtensionCommandKey)
        case .togglePalette, .dictation, .command:
            break
        }
        candidateActionsCache = nil
        // A rebuild walks every candidate; only a modifier-only binding changes this map.
        if previous?.usesModifierTapMonitor == true || binding?.usesModifierTapMonitor == true {
            syncModifierTaps()
        }
    }

    /// A hold reserves its physical modifier across both tap gestures.
    func conflictOwner(of binding: HotKeyBinding, excluding action: HotKeyAction) -> String? {
        for candidate in candidateActions where candidate != action {
            guard let other = self.binding(for: candidate) else { continue }
            let holdsModifier =
                dictationHoldToTalk
                && (action == .dictation && binding.holdKey != nil
                    || candidate == .dictation && other.holdKey != nil)
            if binding.conflicts(with: other, holdsModifier: holdsModifier) {
                return displayName(of: candidate)
            }
        }
        return nil
    }

    /// Every action that could hold a binding: the search space for conflicts and the map.
    private var candidateActions: [HotKeyAction] {
        if let candidateActionsCache { return candidateActionsCache }
        var actions = HotKeyAction.builtInActions
        actions += boundBundleIDs.map { .app(bundleID: $0) }
        actions += boundPaneBundleIDs.map { .settingsPane(bundleID: $0) }
        actions += boundExtensionCommandEntryIDs.map { .extensionCommand(entryID: $0) }
        candidateActionsCache = actions
        return actions
    }

    private func displayName(of action: HotKeyAction) -> String {
        switch action {
        case .togglePalette:
            return "App Launcher"
        case .dictation:
            return "Dictation"
        case .command(let id):
            return id.name
        case .app(let bundleID), .settingsPane(let bundleID):
            return displayName?(action) ?? bundleID
        case .extensionCommand:
            return displayName?(action) ?? "Extension Command"
        }
    }

    /// Hands a combo to Carbon; a modifier-only binding has no per-action registration.
    private func register(_ action: HotKeyAction) {
        guard let shortcut = binding(for: action)?.shortcut else { return }
        center.register(
            id: action.defaultsKey, shortcut: shortcut,
            onKeyDown: { [weak self] in self?.perform(action) },
            onKeyUp: action == .dictation ? { [weak self] in self?.onDictationReleased?() } : nil)
    }

    /// Rebuilt wholesale, so the map can't drift from what is on disk.
    private func syncModifierTaps() {
        modifierTaps = [:]
        let dictationBinding = binding(for: .dictation)
        let holdKey = dictationHoldToTalk ? dictationBinding?.holdKey : nil
        for action in candidateActions {
            guard let binding = binding(for: action), binding.usesModifierTapMonitor else { continue }
            if action == .dictation, !dictationEnabled { continue }
            if action == .dictation, dictationHoldToTalk {
                guard holdKey != nil, conflictOwner(of: binding, excluding: action) == nil else {
                    continue
                }
            }
            modifierTaps[binding] = action
        }
        modifierTapMonitor.update(
            bound: Set(modifierTaps.keys),
            holdKey: dictationBinding.flatMap { modifierTaps[$0] == .dictation ? holdKey : nil })
    }

    private func perform(_ action: HotKeyAction) {
        // The category switch, the way each feature switch already guards its own funnel.
        guard allowsAction?(action) ?? true else { return }
        switch action {
        case .togglePalette: onTogglePalette?()
        case .dictation: onDictationPressed?()
        case .command(let id): onRunCommand?(id)
        case .app(let bundleID): AppLauncher.toggle(bundleID: bundleID)
        case .settingsPane(let bundleID): AppLauncher.openSettingsPane(bundleID: bundleID)
        case .extensionCommand(let entryID): onRunExtensionCommand?(entryID)
        }
    }

    private func index(_ id: String, bound: Bool, key: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        if bound { set.insert(id) } else { set.remove(id) }
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}
