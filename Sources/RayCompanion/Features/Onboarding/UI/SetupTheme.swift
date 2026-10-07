import SwiftUI

enum SetupTheme {
    static let windowSize = CGSize(width: 350, height: 430)
    enum Control { static let radius: CGFloat = 13 }
    enum Card {
        static let inset: CGFloat = 13
        static var fill: Color { Color(nsColor: NSColor(name: nil) { mode in
            mode.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.055) : NSColor(white: 1, alpha: 0.52)
        }) }
        static var stroke: Color { Color(nsColor: NSColor(name: nil) { mode in
            mode.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.10) : NSColor(white: 0, alpha: 0.16)
        }) }
    }
}
