import AppKit

/// Unchecked: its whole state is two `let` `NSCache`s, thread-safe in themselves.
final class ThumbnailCache: @unchecked Sendable {
    private final class Cache: NSCache<NSString, NSImage> {}

    private let rows = Cache()
    private let previews = Cache()

    init(rowBytes: Int, previewBytes: Int) {
        rows.totalCostLimit = rowBytes
        previews.totalCostLimit = previewBytes
    }

    /// Frees the large bitmaps on dismiss; row tiles stay warm for a re-open.
    func purgePreviews() {
        previews.removeAllObjects()
    }
}
