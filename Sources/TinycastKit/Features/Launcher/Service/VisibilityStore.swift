import Foundation

/// A category that is off runs nothing, so it gates shortcuts as well as the list.
@MainActor
@Observable
final class VisibilityStore {
    private let defaults: UserDefaults
    private let itemsKey = "hiddenLauncherItems"
    private let kindsKey = "hiddenLauncherKinds"

    private(set) var hiddenItemKeys: Set<String>
    private(set) var disabledKinds: Set<String>
    /// AppIndex includes this in its result key, invalidating a list when the visible set moves.
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hiddenItemKeys = Set(defaults.stringArray(forKey: itemsKey) ?? [])
        disabledKinds = Set(defaults.stringArray(forKey: kindsKey) ?? [])
    }
}
