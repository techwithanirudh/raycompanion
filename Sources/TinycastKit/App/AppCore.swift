import AppKit

/// Single owner of every long-lived manager. Wired up once from the app delegate.
@MainActor
@Observable
final class AppCore {
    static let shared = AppCore()

    let launcherRanking: LauncherRankingStore
    let clipboardStore = ClipboardStore()
    let clipboardManager: ClipboardManager
    let textInjector: TextInjector
    let hotKeys = HotKeyManager()
    let dictationAudioDucker = DictationAudioDucker()
    @ObservationIgnored private(set) lazy var dictationModels =
        DictationModelStore(idleRelease: settings.dictationIdleRelease)
    let inputSourceSwitcher = InputSourceSwitcher()
    let updater = AppUpdater()
    var onReplaySetup: (() -> Void)?
    var onSettingsOpening: (() -> Void)?
    let settings: AppSettings
    @ObservationIgnored private var appearanceObservation: NSKeyValueObservation?
    /// The last verdict `trackChatRoute` acted on; nil until it has read one.
    @ObservationIgnored private var chatsRunTheirOwnTools: Bool?
    let favorites = FavoritesStore()
    let visibility = VisibilityStore()
    let aliases = AliasStore()
    let currencyRates = CurrencyRateStore()
    let runningApps = RunningAppsMonitor()
    let palette = PaletteState()
    let fileSearch = FileSearchSession()
    let activationPolicy = ActivationPolicy()
    let extensions: ExtensionManager
    let chatHistory: ChatHistoryStore
    let aiChats: AIChatSurfacesState
    let aiSettings = AISettingsStore(
        environmentStore: .keychain,
        isAppleIntelligenceAvailable: { AppleIntelligenceProvider.status().isAvailable })
    let mcpSettings = MCPSettingsStore()
    let mcpOAuth = MCPOAuthManager()
    @ObservationIgnored private(set) lazy var mcp = MCPServerManager(oauth: mcpOAuth)
    let chatGPTSubscription = ChatGPTSubscriptionManager()
    let installedAI = InstalledAIManager()
    @ObservationIgnored private var appliedLaunchRevisions: [InstalledAIKind: Int] = [:]

    @ObservationIgnored private(set) lazy var dictationCoordinator = DictationCoordinator(
        settings: settings, hotKeys: hotKeys, models: dictationModels, injector: textInjector,
        audioDucker: dictationAudioDucker,
        confirmEnable: { [unowned self] in
            await self.confirm(
                title: "Enable Dictation?",
                message: "RayCompanion needs microphone access for dictation and Accessibility to paste into "
                    + "other apps. Audio is processed on this Mac.",
                symbol: "waveform", confirmTitle: "Continue", tone: .neutral,
                confirmRole: .standard)
        },
        showMessage: { [unowned self] in self.showMessage($0, tone: $1) })

    @ObservationIgnored private(set) lazy var paletteCoordinator = PaletteCoordinator(
        palette: palette, settings: settings, fileSearch: fileSearch,
        windowController: windowController)
    /// Its own window and lifecycle: neither coordinator shows or closes the other's surface.
    @ObservationIgnored private(set) lazy var settingsCoordinator = SettingsCoordinator(core: self)
    @ObservationIgnored private(set) lazy var extensionCoordinator = ExtensionCoordinator(
        extensions: extensions, palette: palette, paletteCoordinator: paletteCoordinator,
        settingsCoordinator: settingsCoordinator, settings: settings, core: self)
    @ObservationIgnored private(set) lazy var aiExtensionTools = AIExtensionTools(core: self)
    @ObservationIgnored private(set) lazy var localTools = AILocalTools(core: self)
    @ObservationIgnored private(set) lazy var mcpCoordinator = MCPCoordinator(
        settings: settings, store: mcpSettings, manager: mcp, core: self)
    /// Its own window and lifecycle, like Settings; Quick AI is the palette's half of the feature.
    @ObservationIgnored private(set) lazy var aiChatCoordinator = AIChatCoordinator(
        chats: aiChats, settings: settings,
        paletteCoordinator: paletteCoordinator, settingsCoordinator: settingsCoordinator,
        core: self)
    @ObservationIgnored private(set) lazy var quickAICoordinator = QuickAICoordinator(
        chats: aiChats, settings: settings, palette: palette,
        paletteCoordinator: paletteCoordinator, core: self)

    @ObservationIgnored lazy var windowController = PaletteWindowController(core: self)
    @ObservationIgnored private lazy var messageHUD = MessageHUDController(settings: settings)
    private(set) var isShowingDialog = false
    var isDimmingPaletteForDialog: Bool { isShowingDialog && windowController.isVisible }
    /// Every confirmation, report and prompt; it also stops a held hotkey stacking them.
    @ObservationIgnored private lazy var dialogs = DialogController(
        settings: settings,
        onPresentationChanged: { [weak self] isPresenting in
            guard let self else { return }
            isShowingDialog = isPresenting
        })

    private init() {
        let launcherRanking = LauncherRankingStore()
        let settings = AppSettings()
        let chatHistory = ChatHistoryStore(directory: AppPaths.applicationSupport())
        self.launcherRanking = launcherRanking
        self.settings = settings
        self.chatHistory = chatHistory
        aiChats = AIChatSurfacesState(history: chatHistory)
        let clipboardManager = ClipboardManager(store: clipboardStore, settings: settings)
        self.clipboardManager = clipboardManager
        extensions = ExtensionManager(clipboardStore: clipboardStore)
        textInjector = TextInjector(
            clipboardManager: clipboardManager,
            settings: settings)
    }

    func startAIOnly() {
        NSApp.setActivationPolicy(.accessory)
        updater.start()
        _ = localTools
        applyAppearance()
        track({ _ = $0.appearance }, reproject: { $0.applyAppearance() })
        observeEffectiveAppearance()
        hotKeys.onRunCommand = { [weak self] id in
            guard let self else { return }
            if id == .quickAI { quickAICoordinator.show() }
            if id == .aiChat { aiChatCoordinator.showWindow() }
        }
        hotKeys.dictationEnabled = settings.dictationEnabled
        hotKeys.dictationHoldToTalk = settings.dictationMode == .pushToTalk
        hotKeys.onDictationPressed = { [weak self] in self?.dictationCoordinator.pressed() }
        hotKeys.onDictationReleased = { [weak self] in self?.dictationCoordinator.released() }
        hotKeys.onDictationCancelled = { [weak self] in self?.dictationCoordinator.cancel() }
        hotKeys.allowsAction = { [weak self] action in
            guard let self else { return false }
            if action == .dictation { return settings.dictationEnabled }
            return settings.aiEnabled && (action == .command(.quickAI) || action == .command(.aiChat))
        }
        hotKeys.startAICombinations()
        track({ _ = $0.dictationIdleRelease }, reproject: {
            $0.dictationModels.setIdleRelease($0.settings.dictationIdleRelease)
        })
        track({ _ = $0.dictationEnabled; _ = $0.dictationMode }, reproject: {
            $0.hotKeys.dictationHoldToTalk = $0.settings.dictationMode == .pushToTalk
            $0.hotKeys.dictationEnabled = $0.settings.dictationEnabled
        })
        installedAI.launchSettings = { [aiSettings] in aiSettings.launch(for: $0) }
        chatGPTSubscription.launchSettings = { [aiSettings] in aiSettings.launch(for: .codex) }
        mcpCoordinator.applyEnabled()
        track({ _ = $0.aiEnabled }, reproject: { $0.aiChatCoordinator.applyEnabled() })
        aiChatCoordinator.applyEnabled()
        track(aiSettings, { _ = $0.retention }, reproject: { $0.aiChatCoordinator.applyRetention() })
        track(aiSettings, { _ = $0.launchRevisions }, reproject: { $0.applyInstalledLaunches() })
        track({ _ = $0.mcpEnabled }, reproject: { $0.mcpCoordinator.applyEnabled() })
        trackChatRoute()
    }

    func handleOpenURL(_ url: URL) {
        switch ExtensionOAuthSession.handleCallbackURL(url) {
        case .delivered:
            paletteCoordinator.showPalette(mode: .extensionCommand, restoreAnyMode: true)
            return
        case .expired:
            showMessage("Sign-in expired — run the command again", tone: .danger)
            return
        case .ignored:
            break
        }
        guard ExtensionDeepLink.claims(url) else { return }
        guard let link = ExtensionDeepLink.parse(url: url) else {
            paletteCoordinator.showPalette(mode: .launcher, restoreAnyMode: true)
            return
        }
        extensionCoordinator.runDeepLink(link)
    }

    /// Only the tool whose own path or variables changed is checked again; the rest keep running.
    private func applyInstalledLaunches() {
        let revisions = aiSettings.launchRevisions
        let enabled =
            settings.aiEnabled || settings.quickActionsEnabled
            ? aiSettings.enabledInstalledProviders : []
        for kind in InstalledAIKind.allCases where appliedLaunchRevisions[kind] != revisions[kind] {
            guard enabled.contains(kind) else { continue }
            if kind == .codex {
                chatGPTSubscription.stop()
                chatGPTSubscription.refresh()
            } else {
                installedAI.refresh(kind: kind)
            }
        }
        appliedLaunchRevisions = revisions
    }

    @discardableResult
    func applyInstalledAILifecycle() -> Task<Void, Never> {
        let enabledKinds =
            settings.aiEnabled || settings.quickActionsEnabled
            ? aiSettings.enabledInstalledProviders : []
        var tasks: [Task<Void, Never>] = []
        if enabledKinds.contains(.codex) {
            tasks.append(
                chatGPTSubscription.phase == .idle
                    ? chatGPTSubscription.refresh()
                    : chatGPTSubscription.currentRefreshTask())
        } else {
            chatGPTSubscription.stop()
        }
        tasks.append(installedAI.ensure(enabledKinds: enabledKinds))
        return Task { for task in tasks { await task.value } }
    }

    // MARK: - Feature switches

    private func applyAppearance() {
        NSApp.appearance = settings.appearance.nsAppearance
    }

    /// IconCache is told here, not from `applyAppearance()`, which never fires under `.system`.
    private func observeEffectiveAppearance() {
        // Synchronous on main, so no row can cache a tile under the outgoing appearance's key.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial]) { app, _ in
            MainActor.assumeIsolated { IconCache.setDarkSurface(app.effectiveAppearance.isDark) }
        }
    }

    private func track(
        _ reads: @escaping @Sendable @MainActor (AppSettings) -> Void,
        reproject: @escaping @Sendable @MainActor (AppCore) -> Void
    ) {
        track(settings, reads, reproject: reproject)
    }

    /// Fires synchronously on main before the write lands, so the task re-arms and re-reads.
    private func track<Store: AnyObject & Sendable>(
        _ store: Store,
        _ reads: @escaping @Sendable @MainActor (Store) -> Void,
        reproject: @escaping @Sendable @MainActor (AppCore) -> Void
    ) {
        withObservationTracking {
            reads(store)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.track(store, reads, reproject: reproject)
                reproject(self)
            }
        }
    }

    /// A chat route that runs its own MCP client decides which servers Tinycast runs itself.
    private func trackChatRoute() {
        let runsOwnTools = withObservationTracking {
            aiChatCoordinator.everyChatRunsItsOwnTools
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackChatRoute() }
        }
        // Re-read on every streaming flush, so only a changed verdict reaches the servers.
        defer { chatsRunTheirOwnTools = runsOwnTools }
        guard let previous = chatsRunTheirOwnTools, previous != runsOwnTools else { return }
        mcpCoordinator.applyEnabled()
    }

    // MARK: - Settings file

    // MARK: - Dialogs, routed here so `dialogs` stays the single owner

    func showNotice(title: String, message: String, symbol: String, tone: DialogTone) async {
        await dialogs.notice(title: title, message: message, symbol: symbol, tone: tone)
    }

    /// `tone` styles the glyph, `confirmRole` the button; separate on purpose. `queued` waits
    /// behind an open dialog instead of declining, for consent to a tool call.
    func confirm(
        title: String, message: String?, symbol: String?, confirmTitle: String,
        tone: DialogTone = .danger, confirmRole: DialogAction.Role = .destructive,
        dismissTitle: String = "Cancel", queued: Bool = false
    ) async -> Bool {
        await dialogs.confirm(
            title: title, message: message, symbol: symbol, tone: tone, confirmTitle: confirmTitle,
            confirmRole: confirmRole, dismissTitle: dismissTitle, queued: queued)
    }

    /// A question with more than two answers; the returned index is into `options`.
    func choose(
        title: String, message: String?, symbol: String?, options: [DialogAction],
        defaultIndex: Int, tone: DialogTone = .neutral, queued: Bool = false
    ) async -> Int {
        await dialogs.choose(
            title: title, message: message, symbol: symbol, tone: tone, options: options,
            defaultIndex: defaultIndex, queued: queued)
    }

    /// The transient success/info pill, so `messageHUD` stays single-owned alongside `dialogs`.
    func showMessage(_ message: String, tone: DialogTone = .success) {
        messageHUD.show(message: message, tone: tone)
    }

}
