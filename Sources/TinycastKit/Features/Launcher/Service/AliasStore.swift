import Foundation

/// The user's per-entry aliases, keyed like favorites and ranking by `preferenceKey`.
@MainActor
@Observable
final class AliasStore {
    private let defaults: UserDefaults
    private let defaultsKey = "launcherAliases"

    private(set) var aliases: [String: String]
    /// AppIndex includes this in its result key, invalidating a ranking when an alias changes.
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aliases = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }
}
