import Foundation

/// One entry's usage: a decaying score, and the terms it was last opened by.
struct LauncherVisit: Codable, Hashable, Sendable {
    /// When the decayed score falls back to 1, so a later anchor is always the higher score.
    var anchor: Date
    var openedAt: Date
    /// Distinct and folded, most recent last, at most `LauncherRankingStore.termLimit`.
    var searchTerms: [String]
}

/// Learns what the user opens, and by which query, as bounded on-device frecency data.
@MainActor
@Observable
final class LauncherRankingStore {
    private let fileURL: URL
    private let now: () -> Date

    private(set) var visits: [String: LauncherVisit]
    /// Part of `AppIndex`'s cache key, invalidating a result after a visit or a reset.
    private(set) var revision = 0

    init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.now = now
        let decoded =
            (try? Data(contentsOf: self.fileURL))
            .flatMap { try? JSONDecoder().decode([String: LauncherVisit].self, from: $0) } ?? [:]
        visits = Self.live(decoded, at: now())
    }

    /// A passed anchor scores 1 with its terms gated off, which is exactly an entry never opened.
    private nonisolated static func live(
        _ table: [String: LauncherVisit], at timestamp: Date
    ) -> [String: LauncherVisit] {
        table.filter { !$0.key.isEmpty && $0.value.anchor > timestamp }
    }

    /// Application Support, not Caches: relearning a ranking takes the user weeks of use.
    private static func defaultFileURL() -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tinycast.app"
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("launcher-ranking.json")
    }
}
