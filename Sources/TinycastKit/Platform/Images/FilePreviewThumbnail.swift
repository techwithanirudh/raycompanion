import AppKit
import QuickLookThumbnailing

/// Content thumbnails for any file type — a poster frame, a PDF's page, else the type's icon.
enum FilePreviewThumbnail {
    private static let cache = ThumbnailCache(
        rowBytes: 8 * 1024 * 1024, previewBytes: 32 * 1024 * 1024)

    static func purgePreviews() {
        cache.purgePreviews()
    }
}
