import Foundation

/// Built by `EntryNaming.profile` alone.
struct SearchProfile: Sendable, Hashable {
    var title: SearchText
    var alternateTitles: [SearchText]
    var subtitle: SearchText?
    /// Match to appear, never to rank.
    var keywords: [SearchText]

    /// What an entry holds before its first index pass: nothing a query can reach.
    static let unnamed = SearchProfile(
        title: SearchText(units: []), alternateTitles: [], subtitle: nil, keywords: [])
}
