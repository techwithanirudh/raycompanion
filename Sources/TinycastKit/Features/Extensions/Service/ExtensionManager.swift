import AppKit
import Foundation

/// What the palette is showing for the running command.
enum ExtensionSessionState: Equatable {
    case idle
    case launching
    case rendered(RenderTree)
    case failed(String)
    /// A no-view command that ran to completion.
    case finished
}

/// Owns the installed set, the runtime and the running command.
@MainActor
@Observable
final class ExtensionManager: ExtensionRuntimeDelegate, ExtensionHostContext {
    private(set) var installed: [InstalledExtension] = []
    /// The store's newer version of each installed extension that has one, keyed by manifest name.
    private(set) var updates: [String: ExtensionListing] = [:]
    private(set) var updating: Set<String> = []
    private(set) var menuBars: ExtensionMenuBarManager?
    private(set) var state: ExtensionSessionState = .idle
    /// The command whose session is live, if any.
    private(set) var running: ExtensionCommandRef?
    /// Toasts the running command asked for, newest last.
    private(set) var toasts: [ExtensionToast] = []
    /// Depth of the extension's own navigation stack; >1 means Escape should pop rather than close.
    private(set) var navigationDepth = 1
    /// Each search-bar dropdown's choice, keyed by node so a pushed screen keeps its own.
    private(set) var accessoryValues: [Int: String] = [:]

    /// Off means nothing scanned, published or held: the feature costs an unused stored property.
    private(set) var isEnabled = false
    /// Whether the commands reach the launcher at all; independent of `isEnabled`.
    private(set) var showsInLauncher = true

    var isAuthorizing: Bool { oauthSession.isAuthorizing }

    let storage: ExtensionStorage
    /// Extension-scoped state the launcher and Settings read through here, like `storage`.
    let appearances = ExtensionAppearanceStore()
    private let commandMetadata = ExtensionCommandMetadataStore(
        fileURL: ExtensionCatalog.commandMetadataFile())
    @ObservationIgnored private let runtime: ExtensionRuntime
    @ObservationIgnored private let bridge: ExtensionHostBridge
    @ObservationIgnored private let oauthSession = ExtensionOAuthSession()
    @ObservationIgnored private weak var coordinator: ExtensionCoordinator?

    @ObservationIgnored private var sessionID: String?
    @ObservationIgnored private var backgroundSessionID: String?
    @ObservationIgnored private var backgroundRef: ExtensionCommandRef?
    @ObservationIgnored private var backgroundContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var backgroundFailure: String?
    @ObservationIgnored private var backgroundTask: Task<Void, Never>?
    @ObservationIgnored private var nextToastID = 1
    @ObservationIgnored private var lastOAuthExtensionName: String?

    init(clipboardStore: ClipboardStore) {
        storage = ExtensionStorage(directory: ExtensionCatalog.storageDirectory())
        bridge = ExtensionHostBridge(clipboardStore: clipboardStore)
        runtime = ExtensionRuntime(hostAPI: bridge)
        bridge.context = self
    }

    // MARK: - Installed set

    func extensionNamed(_ name: String) -> InstalledExtension? {
        installed.first { $0.manifest.name == name }
    }

    /// One command as a row; a chosen appearance replaces the shipped icon for all of them.
    private func entry(for command: ExtensionCommand, in owner: InstalledExtension) -> AppEntry {
        let appearance = appearances.appearance(for: owner.manifest.name)
        let reference = ExtensionCommandRef(
            extensionName: owner.manifest.name, commandName: command.name)
        let metadata = commandMetadata.metadata(
            extension: owner.manifest.name, command: command.name)
        // A dropped `interval` retires the dot with it, however stale the stored flag is.
        let schedulable = ExtensionRefreshPolicy.isSchedulable(
            mode: command.mode, interval: command.interval)
        return AppEntry(
            id: reference.entryID,
            name: command.title,
            url: owner.directory,
            bundleID: nil,
            kind: .extensionCommand,
            subtitle: ExtensionRefreshPolicy.displaySubtitle(
                manifest: command.subtitle, override: metadata.subtitle, ownerTitle: owner.title),
            backgroundRefresh: ExtensionRefreshPolicy.indicator(
                schedulable: schedulable, backgroundEnabled: metadata.backgroundEnabled,
                lastError: metadata.lastError),
            keywords: command.keywords,
            iconOverride: icon(for: command, in: owner, appearance: appearance),
            ownerName: owner.title, installedAt: owner.installedAt)
    }

    /// An appearance wins, else the shipped artwork; the launcher gets the answer.
    private func icon(
        for command: ExtensionCommand, in owner: InstalledExtension,
        appearance: ExtensionAppearance?
    ) -> EntryIcon {
        if let appearance {
            return .tintedSymbol(name: appearance.symbol, tint: appearance.tint.symbolTint)
        }
        guard let path = commandIconPath(command, in: owner) ?? owner.iconPath else {
            return .symbol("puzzlepiece.extension")
        }
        return .artwork(path: path, extent: ExtensionIconCache.extent)
    }

    private func commandIconPath(_ command: ExtensionCommand, in owner: InstalledExtension) -> String? {
        guard let icon = command.icon else { return nil }
        let candidate = owner.directory.appendingPathComponent("assets").appendingPathComponent(icon)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : nil
    }

    // MARK: - Running a command

    /// Resolve a launcher row to a command, or nil when the row isn't an extension command.
    func resolve(_ entry: AppEntry) -> (InstalledExtension, ExtensionCommand)? {
        guard let reference = ExtensionCommandRef(entryID: entry.id),
            let owner = extensionNamed(reference.extensionName),
            let command = owner.command(named: reference.commandName)
        else { return nil }
        return (owner, command)
    }

    /// A deep link names owner/extension/command; the owner is a hint, the slug decides.
    func resolve(_ link: ExtensionDeepLink) -> (InstalledExtension, ExtensionCommand)? {
        let candidates = installed.filter { link.matches(manifestName: $0.manifest.name) }
        guard
            let owner = link.extensionCandidates.lazy.compactMap({ want in
                candidates.first { $0.manifest.name.lowercased() == want.lowercased() }
            }).first ?? candidates.first,
            let command = owner.manifest.commands.first(where: {
                $0.name.lowercased() == link.commandName.lowercased()
            })
        else { return nil }
        return (owner, command)
    }

    func run(
        _ owner: InstalledExtension, command: ExtensionCommand, arguments: [String: String] = [:],
        fallbackText: String? = nil, launchType: ExtensionLaunchType = .userInitiated,
        launchContext: [String: RenderValue] = [:]
    ) async {
        guard isEnabled else { return }
        if command.mode == .menuBar || (command.mode == .noView && launchType == .background) {
            menuBars?.run(
                owner, command: command, arguments: arguments, type: launchType, context: launchContext)
            return
        }
        await stop()
        guard isEnabled else { return }
        let schemas = owner.manifest.preferences + command.preferences
        let missing = storage.missingRequiredPreferences(
            extension: owner.manifest.name, schemas: schemas)
        guard missing.isEmpty else {
            running = ExtensionCommandRef(
                extensionName: owner.manifest.name, commandName: command.name)
            state = .failed(ExtensionLaunchError.missingPreferences(missing).localizedDescription)
            return
        }
        guard let bundle = owner.bundleURL(for: command) else {
            running = ExtensionCommandRef(
                extensionName: owner.manifest.name, commandName: command.name)
            state = .failed(ExtensionLaunchError.notBuilt(command.title).localizedDescription)
            return
        }

        running = ExtensionCommandRef(extensionName: owner.manifest.name, commandName: command.name)
        navigationDepth = 1
        state = .launching

        // The runtime holds one context: a background tick in flight yields to the manual run.
        await abortBackgroundRun()

        // Raycast activates the schedule on first manual open; the run itself is the first refresh.
        if ExtensionRefreshPolicy.isSchedulable(mode: command.mode, interval: command.interval) {
            commandMetadata.activateBackgroundRefresh(
                extension: owner.manifest.name, command: command.name, now: Date())
            restartBackgroundLoop()
        }

        let supportPath = ExtensionCatalog.supportPath(for: owner.manifest.name)
        try? FileManager.default.createDirectory(at: supportPath, withIntermediateDirectories: true)

        do {
            // No-op while a context is already up; after `stop()` this builds a fresh one.
            try await runtime.boot(config: .current(supportDirectory: supportPath))
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        // Reading a few hundred KB of bundle is IO; keep it off the main actor.
        let code = await Task.detached(priority: .userInitiated) {
            (try? String(contentsOf: bundle, encoding: .utf8)) ?? ""
        }.value
        guard !code.isEmpty else {
            state = .failed(ExtensionLaunchError.notBuilt(command.title).localizedDescription)
            return
        }

        let session = UUID().uuidString
        sessionID = session
        let context = makeLaunchContext(
            owner: owner, command: command, arguments: arguments, supportPath: supportPath,
            fallbackText: fallbackText,
            launchType: command.mode == .view ? .userInitiated : launchType,
            launchContext: launchContext)

        await runtime.start(
            session: session, code: code, file: bundle, mode: command.mode, context: context)
    }

    private func makeLaunchContext(
        owner: InstalledExtension, command: ExtensionCommand, arguments: [String: String],
        supportPath: URL, fallbackText: String? = nil, launchType: ExtensionLaunchType,
        launchContext: [String: RenderValue] = [:]
    ) -> ExtensionLaunchContext {
        let schemas = owner.manifest.preferences + command.preferences
        return ExtensionLaunchContext(
            extensionName: owner.manifest.name,
            extensionTitle: owner.title,
            commandName: command.name,
            commandMode: command.mode,
            assetsPath: owner.assetsPath,
            supportPath: supportPath.path,
            preferences: storage.resolvedPreferences(
                extension: owner.manifest.name, schemas: schemas),
            caches: storage.caches(extension: owner.manifest.name),
            arguments: command.completeArguments(arguments),
            fallbackText: fallbackText,
            launchType: launchType,
            isDarkAppearance: NSApp.effectiveAppearance.isDark,
            launchContext: launchContext)
    }

    func stop() async {
        oauthSession.cancel()
        guard let sessionID else {
            resetSessionState()
            return
        }
        self.sessionID = nil
        await runtime.stop(session: sessionID)
        // Discard the context outright, so nothing left behind reaches the next run.
        runtime.shutdown()
        storage.flush()
        resetSessionState()
    }

    private func resetSessionState() {
        state = .idle
        running = nil
        toasts = []
        navigationDepth = 1
        accessoryValues = [:]
    }

    // MARK: - Background refresh

    /// Starts the loop once, and only when a command wants it: with nothing enabled there is
    /// no task at all, so an unused schedule costs nothing.
    private func ensureBackgroundLoop() {
        guard isEnabled, backgroundTask == nil, hasEnabledBackgroundCommands else { return }
        backgroundTask = Task { [weak self] in await self?.backgroundLoop() }
    }

    /// Whether any installed command currently wants background ticks.
    private var hasEnabledBackgroundCommands: Bool {
        schedulableCommands().contains { owner, command in
            commandMetadata.metadata(extension: owner.manifest.name, command: command.name)
                .backgroundEnabled
        }
    }

    private func restartBackgroundLoop() {
        backgroundTask?.cancel()
        backgroundTask = nil
        ensureBackgroundLoop()
    }

    private func backgroundLoop() async {
        try? await Task.sleep(for: .seconds(5))
        while !Task.isCancelled {
            guard isEnabled else { return }
            await runDueBackgroundCommands()
            if Task.isCancelled { return }
            // The last schedule going away stops the loop itself; enabling restarts it.
            guard hasEnabledBackgroundCommands else {
                backgroundTask = nil
                return
            }
            try? await Task.sleep(for: .seconds(nextBackgroundDelay()))
        }
    }

    private func schedulableCommands() -> [(InstalledExtension, ExtensionCommand)] {
        installed.flatMap { owner in
            owner.manifest.commands.compactMap { command in
                guard
                    ExtensionRefreshPolicy.isSchedulable(mode: command.mode, interval: command.interval)
                else { return nil }
                return (owner, command)
            }
        }
    }

    /// Due commands within one window fire as a batch, so close ticks share a single wakeup.
    private func runDueBackgroundCommands() async {
        guard running == nil, backgroundSessionID == nil else { return }
        let now = Date()
        let due = schedulableCommands().filter { owner, command in
            let reference = ExtensionCommandRef(
                extensionName: owner.manifest.name, commandName: command.name)
            let metadata = commandMetadata.metadata(
                extension: owner.manifest.name, command: command.name)
            guard metadata.backgroundEnabled, let interval = command.interval else { return false }
            return ExtensionRefreshPolicy.nextDue(
                lastRun: metadata.lastRun, now: now, interval: interval,
                consecutiveFailures: metadata.consecutiveFailures, entryID: reference.entryID)
                <= now.addingTimeInterval(ExtensionRefreshPolicy.coalescingWindow)
        }
        guard !due.isEmpty else { return }
        for (owner, command) in due {
            guard !Task.isCancelled, isEnabled, running == nil else { break }
            await runInBackground(owner, command: command)
        }
    }

    /// Capped, so an install or a toggle surfaces without anyone restarting the loop.
    private func nextBackgroundDelay() -> TimeInterval {
        guard running == nil else { return ExtensionRefreshPolicy.coalescingWindow }
        let now = Date()
        var delay = ExtensionRefreshPolicy.idleHeartbeat
        for (owner, command) in schedulableCommands() {
            let reference = ExtensionCommandRef(
                extensionName: owner.manifest.name, commandName: command.name)
            let metadata = commandMetadata.metadata(
                extension: owner.manifest.name, command: command.name)
            guard metadata.backgroundEnabled, let interval = command.interval else { continue }
            let due = ExtensionRefreshPolicy.nextDue(
                lastRun: metadata.lastRun, now: now, interval: interval,
                consecutiveFailures: metadata.consecutiveFailures, entryID: reference.entryID)
            delay = min(delay, max(due.timeIntervalSince(now), 5))
        }
        return delay
    }

    /// A headless `no-view` run: the palette never moves and no feedback fires, only the subtitle can.
    private func runInBackground(_ owner: InstalledExtension, command: ExtensionCommand) async {
        guard backgroundSessionID == nil, running == nil, let interval = command.interval else {
            return
        }
        guard let bundle = owner.bundleURL(for: command) else { return }
        let reference = ExtensionCommandRef(
            extensionName: owner.manifest.name, commandName: command.name)
        let supportPath = ExtensionCatalog.supportPath(for: owner.manifest.name)
        try? FileManager.default.createDirectory(at: supportPath, withIntermediateDirectories: true)

        let session = UUID().uuidString
        backgroundSessionID = session
        backgroundRef = reference
        backgroundFailure = nil
        var succeeded = false
        defer {
            // Gone mid-run means uninstalled: recording would resurrect its storage file.
            if extensionNamed(reference.extensionName) != nil {
                commandMetadata.recordBackgroundResult(
                    extension: reference.extensionName, command: reference.commandName,
                    success: succeeded, error: succeeded ? nil : (backgroundFailure ?? "Timed out."),
                    now: Date())
            }
            backgroundSessionID = nil
            backgroundRef = nil
            backgroundFailure = nil
            backgroundContinuation = nil
            storage.flush()
            commandMetadata.flush()
        }

        do {
            try await runtime.boot(config: .current(supportDirectory: supportPath))
        } catch {
            backgroundFailure = error.localizedDescription
            return
        }
        let code = await Task.detached(priority: .utility) {
            (try? String(contentsOf: bundle, encoding: .utf8)) ?? ""
        }.value
        guard !code.isEmpty else {
            backgroundFailure = ExtensionLaunchError.notBuilt(command.title).localizedDescription
            return
        }
        let context = makeLaunchContext(
            owner: owner, command: command, arguments: [:], supportPath: supportPath,
            launchType: .background)
        await runtime.start(
            session: session, code: code, file: bundle, mode: command.mode, context: context)
        succeeded = await waitForBackgroundResult(
            timeout: ExtensionRefreshPolicy.timeout(interval: interval))
        // An abort already tore the session down; touching the runtime here would take the
        // manual run's fresh context with it.
        guard backgroundSessionID == session else { return }
        await runtime.stop(session: session)
        runtime.shutdown()
    }

    private func waitForBackgroundResult(timeout: TimeInterval) async -> Bool {
        await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            group.addTask { [weak self] in await self?.backgroundSettled() ?? false }
            group.addTask { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(timeout))
                } catch {
                    // Cancelling the loop preempts the tick; only a real timeout is a failure.
                    await self?.resumeBackground(with: true)
                    return true
                }
                await self?.resumeBackground(with: false)
                return false
            }
            defer { group.cancelAll() }
            return await group.next() ?? false
        }
    }

    /// Suspends until the run settles, times out, or is preempted; `resumeBackground` is every exit.
    private func backgroundSettled() async -> Bool {
        await withCheckedContinuation { continuation in backgroundContinuation = continuation }
    }

    /// Ends the in-flight background run as a success so its schedule survives the preemption.
    private func abortBackgroundRun() async {
        guard let session = backgroundSessionID else { return }
        backgroundSessionID = nil
        backgroundRef = nil
        await runtime.stop(session: session)
        runtime.shutdown()
        resumeBackground(with: true)
    }

    /// Main-actor serial, so no two of those exits can resume the same continuation.
    private func resumeBackground(with result: Bool) {
        guard let continuation = backgroundContinuation else { return }
        backgroundContinuation = nil
        continuation.resume(returning: result)
    }

    // MARK: - Events from the palette

    func dispatch(handler: String, arguments: [Any] = []) {
        guard let sessionID else { return }
        let payload = ExtensionRuntime.jsonString(from: arguments)
        Task { await runtime.dispatch(session: sessionID, handler: handler, payload: payload) }
    }

    // MARK: - Search-bar dropdowns

    /// What the dropdown shows: the extension's own `value` when it controls one, else the pick.
    func accessorySelection(_ accessory: ExtensionSearchAccessory) -> String? {
        accessory.controlledValue ?? accessoryValues[accessory.nodeID]
    }

    /// A pick persists where the dropdown asked it to, then tells the extension.
    func chooseAccessorySelection(_ accessory: ExtensionSearchAccessory, value: String) {
        accessoryValues[accessory.nodeID] = value
        if let key = accessory.storageKey, let name = running?.extensionName {
            storage.setAccessoryValue(extension: name, key: key, value: value)
        }
        guard let handler = accessory.onChange else { return }
        dispatch(handler: handler, arguments: [value])
    }

    /// Raycast reports a dropdown's opening choice through `onChange`, and an extension that
    /// filters its rows by that value draws nothing until it arrives. A controlled one needs none.
    private func seedSearchBarAccessory(in tree: RenderTree) {
        guard
            let accessory = ExtensionSearchAccessory(
                node: tree.activeRoot?.node("searchBarAccessory")),
            accessory.controlledValue == nil, accessoryValues[accessory.nodeID] == nil,
            let value = accessory.initialValue(stored: storedAccessoryValue(accessory))
        else { return }
        accessoryValues[accessory.nodeID] = value
        guard let handler = accessory.onChange else { return }
        dispatch(handler: handler, arguments: [value])
    }

    private func storedAccessoryValue(_ accessory: ExtensionSearchAccessory) -> String? {
        guard let key = accessory.storageKey, let name = running?.extensionName else { return nil }
        return storage.accessoryValue(extension: name, key: key)
    }

    /// Pops the extension's stack; false when there is nothing to pop and the palette should close.
    func popNavigation() async -> Bool {
        guard let sessionID, navigationDepth > 1 else { return false }
        return await runtime.popNavigation(session: sessionID)
    }

    func runToastAction(token: String) {
        Task { await runtime.runToastAction(token: token) }
    }

    // MARK: - ExtensionRuntimeDelegate

    func runtime(_ runtime: ExtensionRuntime, session: String, didRender tree: RenderTree) {
        guard session == sessionID else { return }
        state = .rendered(tree)
        navigationDepth = tree.depth
        seedSearchBarAccessory(in: tree)
    }

    func runtime(_ runtime: ExtensionRuntime, session: String, didFail message: String) {
        if session == backgroundSessionID {
            backgroundFailure = message
            resumeBackground(with: false)
            return
        }
        guard session == sessionID else { return }
        state = .failed(message)
    }

    func runtime(_ runtime: ExtensionRuntime, session: String, navigationDepth depth: Int) {
        guard session == sessionID else { return }
        navigationDepth = depth
    }

    func runtime(_ runtime: ExtensionRuntime, session: String, didFinish: Void) {
        if session == backgroundSessionID {
            resumeBackground(with: true)
            return
        }
        guard session == sessionID else { return }
        // A no-view command is done: the palette is already closing, so just release the session.
        state = .finished
        Task { await stop() }
    }

    func runtime(_ runtime: ExtensionRuntime, log level: String, message: String) {
        #if DEBUG
            print("[extension \(level)] \(message)")
        #endif
    }

    // MARK: - ExtensionHostContext

    var activeExtensionName: String? { backgroundRef?.extensionName ?? running?.extensionName }
    var activeLaunchType: ExtensionLaunchType {
        backgroundSessionID != nil ? .background : .userInitiated
    }
    var pasteTarget: NSRunningApplication? { coordinator?.pasteTarget }
    var applicationURLs: [URL] { coordinator?.applicationURLs ?? [] }

    func closeMainWindow(clearRootSearch: Bool) {
        coordinator?.closeMainWindow()
    }

    func reopenPalette() {
        coordinator?.reopenPalette(hasRunningCommand: running != nil)
    }

    func popToRoot() {
        coordinator?.popExtensionToRoot()
    }

    func clearSearchBar() {
        coordinator?.clearSearchBar()
    }

    func openPreferences(scope: String) {
        guard let running, let owner = extensionNamed(running.extensionName) else { return }
        coordinator?.showExtensionSettings(for: owner)
    }

    /// The running command's row metadata; a missing key leaves the subtitle alone.
    func updateCommandMetadata(subtitle: String?) {
        guard let reference = backgroundRef ?? running else { return }
        updateCommandMetadata(subtitle: subtitle, for: reference)
    }

    func updateCommandMetadata(subtitle: String?, for reference: ExtensionCommandRef) {
        commandMetadata.setSubtitle(
            subtitle, extension: reference.extensionName, command: reference.commandName)
    }

    func present(toast: ExtensionToast) -> Int {
        var stamped = toast
        stamped.id = nextToastID
        nextToastID += 1
        // A no-view command's toast has no palette to appear in, so show a HUD.
        guard coordinator?.isPaletteVisible == true else {
            coordinator?.showHUD(
                [toast.title, toast.message].compactMap { $0 }.joined(separator: " — "))
            return stamped.id
        }
        toasts = [stamped]
        // Non-animated toasts self-dismiss; an animated one stays until the command hides it.
        if stamped.style != .animated { scheduleToastDismissal(id: stamped.id) }
        return stamped.id
    }

    func update(toast id: Int, with toast: ExtensionToast) {
        guard let index = toasts.firstIndex(where: { $0.id == id }) else { return }
        var stamped = toast
        stamped.id = id
        toasts[index] = stamped
        if stamped.style != .animated { scheduleToastDismissal(id: id) }
    }

    func hide(toast id: Int) {
        toasts.removeAll { $0.id == id }
    }

    private func scheduleToastDismissal(id: Int) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.hide(toast: id)
        }
    }

    func showHUD(_ text: String) {
        coordinator?.showHUD(text)
    }

    func confirmAlert(_ alert: ExtensionAlert) async -> Bool {
        await coordinator?.confirmExtensionAlert(alert) ?? false
    }

    func openWithPicker(path: String) async {
        let target = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let candidates = NSWorkspace.shared.urlsForApplications(toOpen: target)
        guard candidates.count > 1 else {
            NSWorkspace.shared.open(target)
            return
        }
        let panel = NSAlert()
        panel.messageText = "Open With"
        panel.informativeText = target.lastPathComponent
        for candidate in candidates.prefix(4) {
            panel.addButton(withTitle: candidate.deletingPathExtension().lastPathComponent)
        }
        panel.addButton(withTitle: "Cancel")
        let response = panel.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard response >= 0, response < min(candidates.count, 4) else { return }
        NSWorkspace.shared.open(
            [target], withApplicationAt: candidates[Int(response)],
            configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    /// `launchCommand` from a running command: same extension unless it names another.
    func launch(
        command name: String, extensionName: String?, arguments: [String: String],
        fallbackText: String?, launchType: ExtensionLaunchType, launchContext: [String: RenderValue]
    ) throws {
        let owningName = extensionName ?? activeExtensionName
        guard let owningName, let owner = extensionNamed(owningName),
            let command = owner.command(named: name)
        else { throw ExtensionLaunchError.unknownCommand(name) }
        guard isEnabled else { throw ExtensionLaunchError.unsupported("Extensions are disabled.") }
        guard launchType != .background || command.mode != .view else {
            throw ExtensionLaunchError.unsupported("A view command cannot run in the background.")
        }
        coordinator?.runExtensionCommand(
            entry(for: command, in: owner), arguments: arguments, fallbackText: fallbackText,
            launchType: launchType, launchContext: launchContext)
    }

    func launch(_ link: ExtensionDeepLink) throws {
        guard let (owner, command) = resolve(link) else {
            throw ExtensionLaunchError.unknownCommand(link.commandName)
        }
        coordinator?.runExtensionCommand(
            entry(for: command, in: owner), arguments: link.arguments,
            fallbackText: link.fallbackText, launchType: link.launchType)
    }

    func authorizeOAuth(options: ExtensionOAuthAuthorizeOptions) async throws -> ExtensionOAuthAuthorizeResult
    {
        lastOAuthExtensionName = running?.extensionName
        return try await oauthSession.authorize(options: options)
    }

    func getOAuthTokens(providerId: String) -> String? {
        guard let extName = running?.extensionName ?? lastOAuthExtensionName else { return nil }
        return ExtensionOAuthKeychain.getTokens(extensionName: extName, providerId: providerId)
    }

    func setOAuthTokens(providerId: String, tokens: String) {
        guard let extName = running?.extensionName ?? lastOAuthExtensionName else { return }
        ExtensionOAuthKeychain.setTokens(tokens, extensionName: extName, providerId: providerId)
    }

    func removeOAuthTokens(providerId: String) {
        guard let extName = running?.extensionName ?? lastOAuthExtensionName else { return }
        ExtensionOAuthKeychain.removeTokens(extensionName: extName, providerId: providerId)
    }
}
