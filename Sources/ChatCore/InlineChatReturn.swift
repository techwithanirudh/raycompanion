public struct InlineChatReturn: Sendable {
    public private(set) var isWaiting = false

    public init() {}

    public mutating func lostFocus() { isWaiting = true }
    public mutating func leave() { isWaiting = false }

    public mutating func resume() -> Bool {
        guard isWaiting else { return false }
        isWaiting = false
        return true
    }
}
