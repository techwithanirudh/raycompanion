import ApplicationServices
import Foundation

final class RaycastSearchField: @unchecked Sendable {
    private let element: AXUIElement
    init(_ element: AXUIElement) { self.element = element }

    func clear(ifUnchanged prompt: String) {
        guard !prompt.isEmpty else { return }
        var value: CFTypeRef?
        var settable = DarwinBoolean(false)
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              value as? String == prompt,
              AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
              settable.boolValue else { return }
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, "" as CFString)
    }
}
