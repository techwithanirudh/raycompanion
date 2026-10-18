import AppKit

/// How a command meets the palette: launching, leaving, and the host callbacks it can make.
@MainActor
final class ExtensionCoordinator {
    private let extensions: ExtensionManager
    private let palette: PaletteState
    private let paletteCoordinator: PaletteCoordinator
    private let settingsCoordinator: SettingsCoordinator
    private let settings: AppSettings
    /// Message-HUD presentation only — never for state this type owns.
    private unowned let core: AppCore

    init(
        extensions: ExtensionManager,
        palette: PaletteState,
        paletteCoordinator: PaletteCoordinator,
        settingsCoordinator: SettingsCoordinator,
        settings: AppSettings,
        core: AppCore
    ) {
        self.extensions = extensions
        self.palette = palette
        self.paletteCoordinator = paletteCoordinator
        self.settingsCoordinator = settingsCoordinator
        self.settings = settings
        self.core = core
    }

    // MARK: - Feature presence

    /// A `raycast://extensions/…` link: the same command the launcher would run, by slug.
    func runDeepLink(_ link: ExtensionDeepLink) {
        guard settings.extensionsEnabled else {
            core.showMessage("Extensions are disabled — enable them in Settings", tone: .danger)
            return
        }
        guard let (owner, command) = extensions.resolve(link) else {
            core.showMessage("No installed extension provides '\(link.commandName)'", tone: .danger)
            return
        }
        run(
            owner, command: command, arguments: link.arguments, fallbackText: link.fallbackText,
            launchType: link.launchType)
    }

    // MARK: - Managing one extension from the launcher

    /// A view command takes over the palette; a no-view command closes it and runs headless.
    func runExtensionCommand(
        _ app: AppEntry, arguments: [String: String] = [:], fallbackText: String? = nil,
        launchType: ExtensionLaunchType = .userInitiated,
        launchContext: [String: RenderValue] = [:]
    ) {
        guard let (owner, command) = extensions.resolve(app) else { return }
        run(
            owner, command: command, arguments: arguments, fallbackText: fallbackText,
            launchType: launchType, launchContext: launchContext)
    }

    private func run(
        _ owner: InstalledExtension, command: ExtensionCommand, arguments: [String: String],
        fallbackText: String? = nil, launchType: ExtensionLaunchType = .userInitiated,
        launchContext: [String: RenderValue] = [:]
    ) {
        switch command.mode {
        case .view:
            // Switch the palette over first, so the launching state is what the user sees.
            paletteCoordinator.navigate(to: .extensionCommand)
            // A shortcut fires while hidden, where a view command has nowhere to render.
            if !paletteCoordinator.isVisible {
                paletteCoordinator.showPalette(mode: .extensionCommand)
            }
            if let fallbackText, !fallbackText.isEmpty { palette.query = fallbackText }
        case .noView, .menuBar:
            // A no-view command's own HUD is the feedback, so the palette gets out of the way.
            if launchType == .userInitiated { paletteCoordinator.hidePalette(restoreFocus: false) }
        }
        Task {
            await extensions.run(
                owner, command: command, arguments: arguments, fallbackText: fallbackText,
                launchType: launchType, launchContext: launchContext)
        }
    }

    /// Escape past an empty search field: pop the extension's own stack, then leave the command.
    func exitExtensionScreen() {
        Task {
            if await extensions.popNavigation() { return }
            await extensions.stop()
            if !palette.pop() { paletteCoordinator.hidePalette() }
        }
    }

    /// `popToRoot()` from an extension — back to a fresh root search, command torn down.
    func popExtensionToRoot() {
        Task {
            await extensions.stop()
            palette.prepare(mode: .launcher)
        }
    }

    func showExtensionSettings(for owner: InstalledExtension) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        settingsCoordinator.showSettings(
            tab: .extensions, revealing: .row(.extensionsInstalled, owner.manifest.name))
    }

    // MARK: - Host callbacks, routed here so the manager never touches a window itself

    /// The same recorded target the clipboard and emoji paste paths use.
    var pasteTarget: NSRunningApplication? { paletteCoordinator.targetApp }

    /// `getApplications()` reports what the launcher itself indexes, so the two never disagree.
    var applicationURLs: [URL] { SearchScopes.appBundles(in: settings.searchScopes) }

    /// True while the palette is on screen — a toast has somewhere to render only then.
    var isPaletteVisible: Bool { paletteCoordinator.isVisible }

    func closeMainWindow() {
        paletteCoordinator.hidePalette(restoreFocus: false)
    }

    func reopenPalette(hasRunningCommand: Bool) {
        paletteCoordinator.showPalette(
            mode: hasRunningCommand ? .extensionCommand : .launcher, restoreAnyMode: true)
    }

    func clearSearchBar() {
        palette.query = ""
    }

    /// Its own window: a no-view command closes the palette before the pill is done.
    func showHUD(_ message: String) {
        core.showMessage(message)
    }

    /// The dialog outranks the palette, so a view command keeps its screen behind it.
    func confirmExtensionAlert(_ alert: ExtensionAlert) async -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return await core.confirm(
            title: alert.title, message: alert.message,
            symbol: alert.isDestructive ? "exclamationmark.triangle" : "questionmark.circle",
            confirmTitle: alert.primaryTitle,
            tone: alert.isDestructive ? .danger : .neutral,
            confirmRole: alert.isDestructive ? .destructive : .standard,
            dismissTitle: alert.dismissTitle)
    }
}
