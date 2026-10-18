import AppKit
import ImageIO

/// Downsampled, memory-capped image loading: ImageIO decodes to exactly the size needed.
enum ImageThumbnail {
    private static let cache = ThumbnailCache(
        rowBytes: 8 * 1024 * 1024, previewBytes: 48 * 1024 * 1024)

    /// Frees the preview bitmaps on dismiss; row thumbnails stay warm for a re-open.
    static func purgePreviews() {
        cache.purgePreviews()
    }
}
