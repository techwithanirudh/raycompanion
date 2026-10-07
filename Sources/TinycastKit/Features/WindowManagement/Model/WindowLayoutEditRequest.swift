import Foundation

struct WindowLayoutEditRequest: Identifiable {
    let id = UUID()
    var layout: WindowLayout?
    /// Set by capture, so the panel says what it is showing.
    var isCapture = false
}
