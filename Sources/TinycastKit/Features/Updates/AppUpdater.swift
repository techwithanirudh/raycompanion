import Combine
import Observation
@preconcurrency import Sparkle

@MainActor @Observable final class AppUpdater {
    private(set) var canCheck = false
    private(set) var lastCheck: Date?
    private var automaticChecks = false
    private var automaticDownloads = false
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations = Set<AnyCancellable>()

    var isConfigured: Bool { controller != nil }
    var checksAutomatically: Bool {
        get { automaticChecks }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }
    var downloadsAutomatically: Bool {
        get { automaticDownloads }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    func start() {
        guard controller == nil,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in Task { @MainActor in self?.canCheck = value } }
            .store(in: &observations)
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .sink { [weak self] value in Task { @MainActor in self?.lastCheck = value } }
            .store(in: &observations)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .sink { [weak self] value in Task { @MainActor in self?.automaticChecks = value } }
            .store(in: &observations)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .sink { [weak self] value in Task { @MainActor in self?.automaticDownloads = value } }
            .store(in: &observations)
        controller.startUpdater()
    }

    func checkForUpdates() {
        guard canCheck else { return }
        controller?.checkForUpdates(nil)
    }
}
