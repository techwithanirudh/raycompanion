import Foundation

/// ⌘1…⌘9 then ⌘0 for the tenth; favorites past it are listed but carry no chord.
enum FavoriteSlots {
    /// ANSI number-row key codes in visual order 1…9,0. This is layout-independent.
    private static let numberRowKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]

    /// The favorite a physical number-row key launches, or nil when that key is not a slot.
    static func index(forKeyCode keyCode: UInt16) -> Int? {
        numberRowKeyCodes.firstIndex(of: keyCode)
    }
}
