import AppKit

/// Owns summoning the palette and nothing else; where and how big stays with the controller.
@MainActor
final class PaletteCoordinator {
    private let palette: PaletteState
    private let settings: AppSettings
    private let fileSearch: FileSearchSession
    private let windowController: PaletteWindowController
    /// Features whose launcher rows are read from outside Tinycast re-read them on each open.
    var onLauncherShown: (() -> Void)?
    /// Screens that snapshot other apps re-read them on every open, a restored one included.
    var onScreenOpening: ((PaletteMode) -> Void)?

    init(
        palette: PaletteState,
        settings: AppSettings,
        fileSearch: FileSearchSession,
        windowController: PaletteWindowController
    ) {
        self.palette = palette
        self.settings = settings
        self.fileSearch = fileSearch
        self.windowController = windowController
    }

    // MARK: - Palette control

    var isVisible: Bool { windowController.isVisible }

    /// The app an action acts on: the one displaced, else what a hotkey found frontmost.
    var targetApp: NSRunningApplication? {
        windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
    }

    /// Up and pointed at `mode`, which is the state a mode command's second invocation closes.
    func isShowing(_ mode: PaletteMode) -> Bool {
        windowController.isVisible && palette.mode == mode
    }

    /// Navigating keeps the screen under as the back step; the launcher is the root and never has one.
    func navigate(to mode: PaletteMode) {
        if windowController.isVisible, palette.mode != mode, mode != .launcher {
            palette.push(mode: mode)
        } else {
            palette.prepare(mode: mode)
        }
    }

    /// Shows the palette, honoring Pop to Root Search. See docs/features/palette.md#state-flow.
    func showPalette(
        mode: PaletteMode, restoreAnyMode: Bool = false, seeding query: String? = nil
    ) {
        let preserved = windowController.consumePreservedState()
        let restoring = preserved && (restoreAnyMode || palette.mode == mode)
        // Resetting a screen the pop to root already reset would only re-render the whole palette.
        let alreadyFresh = windowController.isPoppedToRoot && palette.mode == mode
        // A carried query always opens the screen fresh: restoring the previous one would drop it.
        if query != nil || !(restoring || alreadyFresh) {
            navigate(to: mode)
        }
        if let query { palette.query = query }
        // Before the show: `targetApp` must still name the app in front, and no row may pop in.
        onScreenOpening?(palette.mode)
        windowController.show()
        if palette.mode == .fileSearch { fileSearch.search(palette.query) }
        if palette.mode == .launcher { onLauncherShown?() }
    }

    func hidePalette(restoreFocus: Bool = true) {
        fileSearch.cancel()
        windowController.hide(restoreFocus: restoreFocus)
    }

    /// Reset to the root search now rather than after the Pop to Root Search delay.
    func popToRootNow() {
        windowController.popToRootNow()
    }

    /// True for the slim compact bar: compact on, launcher root, empty, not overflowed.
    var paletteIsCollapsed: Bool {
        settings.compactMode
            && !palette.forceExpanded
            && palette.mode == .launcher
            && palette.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The compact bar's overflow: expand into the full launcher without typing.
    func expandFromCompact() {
        palette.forceExpanded = true
    }

    /// Resize the panel to the current collapsed state, when it flips while open.
    func syncPaletteSize() {
        windowController.applyCollapsed(paletteIsCollapsed)
    }

    // MARK: - Dragging

    /// Bracket one drag gesture; the handle tracks it from mouse-down to mouse-up itself.
    func beginPaletteDrag() {
        windowController.beginDrag()
    }

    func endPaletteDrag() {
        windowController.endDrag()
    }
}
