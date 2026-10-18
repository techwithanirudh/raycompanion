import SwiftUI

/// What a row hands to the app it is dropped on, and the image that follows the pointer there.
struct RowDragItem {
    let writer: any NSPasteboardWriting
    let image: NSImage
}

