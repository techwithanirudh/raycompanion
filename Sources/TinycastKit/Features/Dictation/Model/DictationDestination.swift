import Foundation

enum DictationDestination: String, CaseIterable, Identifiable, Sendable {
    case paste
    case copy
    case both

    var id: Self { self }
    var title: String {
        switch self {
        case .paste: "Paste in active app"
        case .copy: "Copy to clipboard"
        case .both: "Paste and copy"
        }
    }

    var pastes: Bool { self != .copy }
    var copies: Bool { self != .paste }
}
