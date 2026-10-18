import Foundation

/// One extension as the store lists it, before anything is downloaded.
struct ExtensionListing: Identifiable, Hashable, Sendable {
    let id: String
    /// The manifest `name`, which is what an install is keyed by.
    let name: String
    let title: String
    let summary: String
    let author: String
    let lightIconURL: URL?
    let darkIconURL: URL?
    let commandCount: Int
    let downloadCount: Int?
    /// A built zip; the store signs these, so the URL is fetched at install, never reused.
    let downloadURL: URL
    /// What an update check compares: it moves with every version the store publishes.
    let commitSHA: String?
}
