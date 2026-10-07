import AppKit
import ApplicationServices
import TinycastKit
import LaunchAtLogin
import ChatCore
import PermissionFlow

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var ai: TinycastAI!
    private var bridge: RaycastBridge!
    private var settings: Settings!
    private var onboarding: OnboardingWindowController!
    private var destination: RaycastWindow?
    private var statusItem: NSStatusItem?
    private var chatReturn = InlineChatReturn()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let backgroundLaunch = CommandLine.arguments.contains("--background") || LaunchAtLogin.wasLaunchedAtLogin
        if CommandLine.arguments.contains("--inspect-raycast") {
            RaycastBridge.inspectCurrentRoot(); NSApp.terminate(nil); return
        }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else {
            NSApp.terminate(nil); return
        }
        settings = Settings(testing: CommandLine.arguments.contains("--demo"))
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let url = Bundle.main.url(forResource: name, withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        bridge = RaycastBridge(settings: settings)
        ai = TinycastAI()
        ai.onShow = { [weak self] in self?.bridge.setOverlayOpen(true) }
        ai.onFocusDismiss = { [weak self] in
            guard let self, destination != nil else { return }
            chatReturn.lostFocus()
            bridge.shouldResume = true
        }
        ai.onDismiss = { [weak self] restore in
            guard let self else { return }
            if restore { chatReturn.leave(); bridge.shouldResume = false; destination?.restore(); destination = nil }
            else if !chatReturn.isWaiting { destination = nil }
            bridge.setOverlayOpen(false)
        }
        onboarding = OnboardingWindowController(
            onFinish: { [weak self] in self?.openMainWindow() },
            onConfigureAI: { [weak self] window, done in self?.ai.configureProviders(attachedTo: window, onDone: done) },
            onVisibilityChanged: { [weak self] window, visible in self?.ai.setupWindow(window, isOpen: visible) })
        ai.onReplaySetup = { [weak self] in self?.replaySetup() }
        ai.onSettingsOpening = { [weak self] in
            guard let self else { return }
            chatReturn.leave(); bridge.shouldResume = false; destination = nil
        }
        bridge.onPrompt = { [weak self] prompt, frame in
            guard let self else { return false }
            chatReturn.leave(); bridge.shouldResume = false
            destination = RaycastWindow()
            ai.closeSettings()
            return ai.ask(prompt, at: appKitFrame(frame))
        }
        bridge.onRootOpened = { [weak self] frame in
            guard let self, chatReturn.resume() else { return }
            bridge.shouldResume = false
            destination = RaycastWindow()
            ai.resumeInline(at: appKitFrame(frame))
        }
        if CommandLine.arguments.contains("--enable-tab") { settings.interceptTab = true }
        if !settings.isTesting { bridge.start() }
        installMenu()
        if CommandLine.arguments.contains("--provider-fixture") { ai.configureFixture() }
        if backgroundLaunch { return }
        if CommandLine.arguments.contains("--alert-demo") { ai.previewAlert() }
        else if settings.isTesting && CommandLine.arguments.contains("--editing-demo") {
            if CommandLine.arguments.contains("--inline-demo") { ai.show() }
            else { ai.continueInWindow() }
            NSApp.activate(ignoringOtherApps: true)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else {
                    FileHandle.standardOutput.write(Data("Select All check: no focused editor\n".utf8)); return
                }
                editor.string = "Select all check"
                editor.didChangeText()
                let routed = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                FileHandle.standardOutput.write(Data("Select All check: routed=\(routed), selected=\(editor.selectedRange().length)\n".utf8))
            }
        }
        else if CommandLine.arguments.contains("--about") { ai.about() }
        else if CommandLine.arguments.contains("--permissions") { ai.permissions() }
        else if CommandLine.arguments.contains("--settings") { openSettings() }
        else if settings.isTesting && CommandLine.arguments.contains("--ai-setup-demo") { onboarding.show(step: 2) }
        else if CommandLine.arguments.contains("--onboarding") { onboarding.show() }
        else if settings.isTesting && CommandLine.arguments.contains("--compact-frame-demo"), let screen = NSScreen.screens.first {
            NSApp.activate(ignoringOtherApps: true)
            ai.ask("", at: CGRect(x: screen.visibleFrame.midX - 375, y: screen.visibleFrame.maxY - 180, width: 750, height: 64))
        }
        else if CommandLine.arguments.contains("--overlay-demo") {
            ai.ask("How can a custom chat feel at home in Raycast?", at: nil)
            if CommandLine.arguments.contains("--window-demo") { ai.continueInWindow() }
            if CommandLine.arguments.contains("--history-demo") { ai.history() }
            if CommandLine.arguments.contains("--actions-demo") {
                Task { @MainActor in try? await Task.sleep(for: .seconds(4)); ai.actions() }
            }
        } else { openMainWindow() }
    }
    func application(_ application: NSApplication, open urls: [URL]) { ai?.open(urls) }
    func applicationWillTerminate(_ notification: Notification) { bridge?.stop(); ai?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openMainWindow(); return false }
    private func installMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let mark = Bundle.main.url(forResource: "RayCompanionMark", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
        mark?.size = NSSize(width: 18, height: 18)
        mark?.isTemplate = true
        statusItem?.button?.image = mark
        statusItem?.button?.setAccessibilityLabel("RayCompanion")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open RayCompanion", action: #selector(openChat), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        let tab = menu.addItem(withTitle: "Open chat with Tab", action: #selector(toggleTab), keyEquivalent: "")
        tab.state = settings.interceptTab ? .on : .off
        menu.addItem(withTitle: "\(String(localized: PermissionFlowResources.accessibilityNameResource))…", action: #selector(openAccessibility), keyEquivalent: "")
        menu.addItem(withTitle: "Replay setup…", action: #selector(replaySetup), keyEquivalent: "")
        menu.addItem(withTitle: "Check for updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit RayCompanion", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        let applicationMenu = NSMenu(title: "RayCompanion")
        let about = applicationMenu.addItem(withTitle: "About RayCompanion", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        applicationMenu.addItem(.separator())
        let settingsItem = applicationMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        let replay = applicationMenu.addItem(withTitle: "Replay setup…", action: #selector(replaySetup), keyEquivalent: "")
        replay.target = self
        let update = applicationMenu.addItem(withTitle: "Check for updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        applicationMenu.addItem(.separator())
        let quitItem = applicationMenu.addItem(withTitle: "Quit RayCompanion", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        let mainMenu = NSMenu()
        let applicationItem = mainMenu.addItem(withTitle: "RayCompanion", action: nil, keyEquivalent: "")
        applicationItem.submenu = applicationMenu
        let fileMenu = NSMenu(title: "File")
        let close = fileMenu.addItem(withTitle: "Close Window", action: #selector(closeWindow), keyEquivalent: "w")
        close.target = self
        mainMenu.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = fileMenu
        let edit = mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "")
        edit.submenu = EditMenu.make()
        let viewMenu = NSMenu(title: "View")
        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        mainMenu.addItem(withTitle: "View", action: nil, keyEquivalent: "").submenu = viewMenu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        let helpMenu = NSMenu(title: "Help")
        let help = helpMenu.addItem(withTitle: "RayCompanion Help", action: #selector(openHelp), keyEquivalent: "")
        help.target = self
        mainMenu.addItem(withTitle: "Help", action: nil, keyEquivalent: "").submenu = helpMenu
        NSApp.helpMenu = helpMenu
        NSApp.mainMenu = mainMenu
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(closeWindow) { return NSApp.keyWindow != nil }
        return item.action == #selector(checkForUpdates) ? ai.canCheckForUpdates : true
    }
    private func openMainWindow() {
        chatReturn.leave(); bridge.shouldResume = false; destination = nil
        ai.closeSettings()
        if onboarding.isInProgress || !UserDefaults.standard.bool(forKey: "hasCompletedSetup") { ai.closeChatWindow(); onboarding.show() }
        else { ai.continueInWindow() }
    }
    @objc private func openChat() { openMainWindow() }
    @objc private func openSettings() { chatReturn.leave(); bridge.shouldResume = false; destination = nil; ai.settings() }
    @objc private func openAbout() { chatReturn.leave(); bridge.shouldResume = false; destination = nil; ai.about() }
    @objc private func checkForUpdates() { ai.checkForUpdates() }
    @objc private func replaySetup() {
        chatReturn.leave(); bridge.shouldResume = false; destination = nil
        ai.hide(); ai.closeSettings(); ai.closeChatWindow()
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
        onboarding.show(step: 0)
    }
    private func appKitFrame(_ frame: CGRect?) -> CGRect? {
        frame.flatMap { bounds in
            NSScreen.screens.first.map { CGRect(x: bounds.minX, y: $0.frame.maxY - bounds.maxY, width: bounds.width, height: bounds.height) }
        }
    }
    @objc private func toggleTab(_ sender: NSMenuItem) { settings.interceptTab.toggle(); sender.state = settings.interceptTab ? .on : .off; bridge.refresh() }
    @objc private func openAccessibility() { onboarding.show(step: 1) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func closeWindow() { NSApp.keyWindow?.performClose(nil) }
    @objc private func openHelp() { NSWorkspace.shared.open(URL(string: "https://github.com/techwithanirudh/raycompanion#readme")!) }
}
