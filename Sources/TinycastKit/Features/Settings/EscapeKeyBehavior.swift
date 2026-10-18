import Foundation

/// What Escape does on the palette once the search field it would have cleared is already empty.
enum EscapeKeyBehavior: String, CaseIterable, Identifiable, Sendable {
    case navigateBackOrClose
    case closeAndPopToRoot

    var id: String { rawValue }
}
