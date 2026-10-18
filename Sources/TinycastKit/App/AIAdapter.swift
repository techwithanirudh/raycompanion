import AppKit
import SwiftUI

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
    public func importRaycastTools() { core.aiExtensionTools.importInstalled() }
    public func settings() { hide(); core.settingsCoordinator.showSettings(tab: .ai) }
    public func about() { hide(); core.settingsCoordinator.showAbout() }
    public func permissions() { hide(); core.settingsCoordinator.showSettings(tab: .permissions) }
    public func focusSettings() -> Bool { core.settingsCoordinator.focusExisting() }
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
        core.localTools.stop()
        core.mcp.stop()
        core.mcpOAuth.stop()
    }

    public func previewExtensionTool() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        core.aiExtensionTools.importInstalled()
        core.aiExtensionTools.enabledNames = ["base64"]
        _ = ask("Encode hello as Base64. Use the Base64 extension.", at: nil)
        core.quickAICoordinator.continueInChat()
    }

    public func previewLocalTools() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        _ = ask("What is 2 × (3 + 4)? Use the calculator.", at: nil)
        core.quickAICoordinator.continueInChat()
    }

    public func previewFocusTransitions() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        settings()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            let settingsWindow = NSApp.keyWindow
            _ = focusSettings()
            show()
            try? await Task.sleep(for: .milliseconds(200))
            let inlineKeptFocus = core.windowController.isVisible && NSApp.keyWindow !== settingsWindow
            FileHandle.standardOutput.write(Data("Focus check: immediate inline=\(inlineKeptFocus)\n".utf8))
            show()
            _ = focusSettings()
            try? await Task.sleep(for: .milliseconds(200))
            let settingsRestored = settingsWindow?.isVisible == true && NSApp.keyWindow === settingsWindow
            let inlineDismissed = !core.windowController.isVisible
            FileHandle.standardOutput.write(Data("Focus check: settings restored=\(settingsRestored), inline dismissed=\(inlineDismissed)\n".utf8))
        }
    }

    public func previewAlert() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        permissions()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            await core.showNotice(title: "Enable Dictation?", message: "RayCompanion records audio only while dictating. Speech is processed on this Mac.", symbol: "waveform", tone: .neutral)
        }
    }

    public func previewImageAttachment(at url: URL) {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".testing") == true else { return }
        core.quickAICoordinator.show()
        _ = core.quickAICoordinator.attachPastedFile(files: [url])
        Task { @MainActor [weak self] in
            for _ in 0..<100 {
                guard let self else { return }
                if !core.aiChats.quickAI.pendingAttachments.isEmpty {
                    core.quickAICoordinator.send("")
                    return
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
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

}
