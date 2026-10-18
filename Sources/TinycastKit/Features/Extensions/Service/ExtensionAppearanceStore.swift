import Foundation

/// Keyed by manifest name like preferences, so a reinstall keeps the choice.
@MainActor
@Observable
final class ExtensionAppearanceStore {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let key = "extensionAppearances"

    private(set) var overrides: [String: ExtensionAppearance]

    init() {
        if let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String: ExtensionAppearance].self, from: data)
        {
            overrides = decoded
        } else {
            overrides = [:]
        }
    }

    func appearance(for extensionName: String) -> ExtensionAppearance? {
        overrides[extensionName]
    }
}
