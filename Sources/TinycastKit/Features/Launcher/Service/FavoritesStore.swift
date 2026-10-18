import Foundation

/// Favorite apps as an ordered key list, pinned to the top while the search is empty.
@MainActor
@Observable
final class FavoritesStore {
    private let defaults = UserDefaults.standard
    private let key = "favoriteApps"

    private(set) var keys: [String]
    /// AppIndex includes this in its result key, invalidating a list when the pinning changes.
    private(set) var revision = 0

    init() {
        keys = defaults.stringArray(forKey: key) ?? []
    }
}
