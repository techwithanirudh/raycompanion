import AppKit
import SwiftUI
import Security

@MainActor public final class TinycastAI {
    private let core: AppCore
    public var onDismiss: ((Bool) -> Void)?
    public var onShow: (() -> Void)?
    public var onFocusDismiss: (() -> Void)?
    public var onReplaySetup: (() -> Void)? { didSet { core.onReplaySetup = onReplaySetup } }
    public var onSettingsOpening: (() -> Void)? { didSet { core.onSettingsOpening = onSettingsOpening } }
    private var suspendedDraft: String?
    private var setupPresenter: SettingsEditorPresenter?

    public init() {
        UserDefaults.standard.register(defaults: [AppSettingsKey.aiNewChatAfter.rawValue: AINewChatAfter.never.rawValue])
        core = AppCore.shared
        core.windowController.allowsGlobalCommandEscape = false
        core.palette.prepare(mode: .ai)
        core.palette.permittedModes = [.ai, .aiHistory]
        core.palette.onUnavailableMode = { [weak self] mode in
            guard let self, mode == .launcher, core.windowController.isVisible else { return }
            core.paletteCoordinator.hidePalette()
        }
        if UserDefaults.standard.object(forKey: AppSettingsKey.aiEnabled.rawValue) == nil { core.settings.aiEnabled = true }
        core.settings.compactMode = false
        core.windowController.onExternalDismiss = { [weak self] restore in self?.onDismiss?(restore) }
        core.windowController.onExternalFocusLost = { [weak self] in
            guard let self else { return }
            suspendedDraft = core.palette.query
            onFocusDismiss?()
        }
        core.paletteCoordinator.onScreenOpening = { [weak self] _ in self?.onShow?() }
        if Bundle.main.bundleIdentifier?.hasSuffix(".testing") != true { migrateProvider(); migrateHistory() }
        core.startAIOnly()
        core.palette.prepare(mode: .ai)
        core.windowController.prewarm()
    }

    @discardableResult
    public func ask(_ prompt: String, at frame: CGRect?) -> Bool {
        suspendedDraft = nil
        core.windowController.externalFrame = frame
        return core.quickAICoordinator.ask(prompt)
    }
    public func show(at frame: CGRect? = nil) {
        core.windowController.externalFrame = frame
        core.paletteCoordinator.showPalette(mode: .ai)
    }
    public func resumeInline(at frame: CGRect?) {
        core.windowController.externalFrame = frame
        core.paletteCoordinator.showPalette(mode: .ai)
        if let suspendedDraft { core.palette.query = suspendedDraft }
        suspendedDraft = nil
    }
    public func open(_ urls: [URL]) { for url in urls { core.handleOpenURL(url) } }
    public func hide() { core.paletteCoordinator.hidePalette(restoreFocus: false) }
    public func settings() { hide(); core.settingsCoordinator.showSettings(tab: .ai) }
    public func about() { hide(); core.settingsCoordinator.showAbout() }
    public func permissions() { hide(); core.settingsCoordinator.showSettings(tab: .permissions) }
    public func closeSettings() { core.settingsCoordinator.closeSettings() }
    public func closeChatWindow() { core.aiChatCoordinator.closeWindow() }
    public func setupWindow(_ window: NSWindow, isOpen: Bool) {
        if isOpen { core.activationPolicy.windowDidOpen(window) }
        else { core.activationPolicy.windowDidClose(window) }
    }
    public var canCheckForUpdates: Bool { core.updater.canCheck }
    public func checkForUpdates() { core.updater.checkForUpdates() }
    public func configureProviders(attachedTo window: NSWindow, onDone: @escaping () -> Void) {
        let presenter = setupPresenter ?? SettingsEditorPresenter(core: core, navigation: SettingsNavigationState(tab: .ai))
        setupPresenter = presenter
        presenter.attach(to: window)
        let id = UUID()
        presenter.present(id: id, onDismiss: {}) {
            AIProvidersPanel(onDone: { [weak presenter] in presenter?.dismiss(id: id); onDone() })
        }
    }
    public func continueInWindow() {
        if let suspendedDraft { core.palette.query = suspendedDraft }
        suspendedDraft = nil
        core.quickAICoordinator.continueInChat()
    }
    public func history() { core.quickAICoordinator.showHistory() }
    public func actions() { Task { @MainActor in await Task.yield(); core.palette.externalActions?() } }
    public func stop() {
        setupPresenter?.dismissAll()
        core.dictationCoordinator.prepareForTermination()
        core.dictationAudioDucker.restoreImmediately()
        core.aiChats.reset()
        core.installedAI.stop()
        core.chatGPTSubscription.stop()
        core.mcp.stop()
        core.mcpOAuth.stop()
    }

    public func previewAlert() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        permissions()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            await core.showNotice(title: "Enable Dictation?", message: "RayCompanion records audio only while dictating. Speech is processed on this Mac.", symbol: "waveform", tone: .neutral)
        }
    }

    public func configureFixture() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        let connection = AIConnection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Local test server", provider: .openAICompatible,
                                      baseURL: "http://127.0.0.1:18764/v1", models: ["fixture-model"])
        core.aiSettings.save(connection)
        core.aiSettings.select(.api(connection: connection.id, model: "fixture-model", effort: nil))
        core.aiSettings.systemPromptEnabled = false
    }

    private func migrateProvider() {
        let defaults = UserDefaults.standard
        guard core.aiSettings.connections.isEmpty,
              let model = defaults.string(forKey: "model"), !model.isEmpty,
              let baseURL = defaults.string(forKey: "baseURL"),
              (try? AIEndpointPolicy.validate(baseURL)) != nil else { return }
        let kind = AIProviderKind(rawValue: defaults.string(forKey: "providerKind") ?? "") ?? .openAICompatible
        let connection = AIConnection(name: "Existing provider", provider: kind, baseURL: baseURL, models: [model])
        var value: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.anirudh.quickchat",
                                   kSecAttrAccount as String: baseURL,
                                   kSecReturnData as String: true,
                                   kSecMatchLimit as String: kSecMatchLimitOne]
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        guard status == errSecSuccess || status == errSecItemNotFound else { return }
        do {
            if let data = value as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty {
                try KeychainSecretStore.aiAPIKeys.setSecret(key, for: connection.id)
            }
            core.aiSettings.save(connection)
            core.aiSettings.select(.api(connection: connection.id, model: model, effort: nil))
        } catch { core.showMessage("The previous API key could not be imported. It remains in Keychain.", tone: .danger) }
    }

    private func migrateHistory() {
        let legacy = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickChat")
        let old = legacy.appendingPathComponent("ai-chats.sqlite3")
        let destination = AppPaths.applicationSupport().appendingPathComponent("ai-chats.sqlite3")
        guard !FileManager.default.fileExists(atPath: destination.path), FileManager.default.fileExists(atPath: old.path) else { return }
        core.chatHistory.close()
        do {
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: old.path + suffix)
                if FileManager.default.fileExists(atPath: source.path) {
                    try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: destination.path + suffix))
                }
            }
            core.chatHistory.load()
        } catch { core.showMessage("Previous chat history could not be imported. The original is preserved.", tone: .danger) }
    }
}
