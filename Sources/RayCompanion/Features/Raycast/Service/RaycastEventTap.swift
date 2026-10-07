import AppKit
import ApplicationServices
import ChatCore

final class RaycastEventTap: @unchecked Sendable {
    enum Result: Sendable {
        case ready, failed, captured(String, CGRect?, RaycastSearchField), rejected(String)
    }
    let pid: pid_t
    private let report: @Sendable (Result) -> Void
    private let lock = NSLock()
    private var runLoop: CFRunLoop?
    private var stopped = false
    private var consumedTab = false

    init(pid: pid_t, report: @escaping @Sendable (Result) -> Void) { self.pid = pid; self.report = report }
    func start() {
        Thread { [self] in
            let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    let engine = Unmanaged<RaycastEventTap>.fromOpaque(context).takeUnretainedValue()
                    return engine.handle(type, event) ? nil : Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { report(.failed); return }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let loop = CFRunLoopGetCurrent()
            lock.lock()
            runLoop = loop
            let shouldRun = !stopped
            lock.unlock()
            if shouldRun {
                CFRunLoopAddSource(loop, source, .commonModes)
                report(.ready)
                CFRunLoopRun()
                CFRunLoopRemoveSource(loop, source, .commonModes)
            }
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }.start()
    }
    func stop() {
        lock.lock()
        stopped = true
        let loop = runLoop
        lock.unlock()
        if let loop { CFRunLoopStop(loop) }
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            report(.failed)
            stop()
            return false
        }
        guard event.getIntegerValueField(.keyboardEventKeycode) == 48 else { return false }
        if type == .keyUp && consumedTab { consumedTab = false; return true }
        guard type == .keyDown,
              event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return false }
        guard let capture = captureRoot() else { return false }
        consumedTab = true
        report(.captured(capture.0, capture.1, capture.2))
        return true
    }
    func inspect() -> (String, CGRect?)? { captureRoot().map { ($0.0, $0.1) } }
    private func captureRoot() -> (String, CGRect?, RaycastSearchField)? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.025)
        guard let active = elementAttribute(system, kAXFocusedApplicationAttribute) else { return nil }
        var activePID: pid_t = 0
        guard AXUIElementGetPid(active, &activePID) == .success, activePID == pid else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.025)
        guard let focused = elementAttribute(app, kAXFocusedUIElementAttribute),
              let window = elementAttribute(app, kAXFocusedWindowAttribute) else {
            report(.rejected("Tab passed through · no focused search field")); return nil
        }
        guard let field = attributes(focused, [kAXRoleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute, kAXTitleAttribute, kAXValueAttribute]) else { return nil }
        let role = field[0] as? String
        let labels = field[1...3].compactMap { $0 as? String }
        let fieldMatches = role == kAXTextFieldRole as String && labels.contains("Search for apps or commands…")
        guard fieldMatches, let prompt = field[4] as? String else {
            report(.rejected("Tab passed through · not the root search input")); return nil
        }
        var root = false
        var overlay = false
        var pending = [window]
        var visited = 0
        let deadline = Date().addingTimeInterval(0.15)
        while let element = pending.popLast() {
            visited += 1
            guard visited < 300, Date() < deadline else {
                report(.rejected("Tab passed through · root check timed out")); return nil
            }
            guard let values = attributes(element, [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXChildrenAttribute]) else { return nil }
            let role = values[0] as? String ?? ""
            let title = values[1] as? String ?? ""
            let description = values[2] as? String ?? ""
            if title == "Root search results" || description == "Root search results" { root = true; continue }
            if role == kAXMenuRole as String || role == kAXSheetRole as String { overlay = true }
            let children = values[3] as? [AXUIElement] ?? []
            pending.append(contentsOf: children.reversed())
        }
        guard RootSearchGate.accepts(isRaycast: true, hasRootResults: root, isSearchField: fieldMatches, hasOverlay: overlay, plainTab: true) else {
            report(.rejected("Tab passed through · root view not confirmed")); return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        if let position = attribute(window, kAXPositionAttribute),
           let dimensions = attribute(window, kAXSizeAttribute),
           CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(dimensions) == AXValueGetTypeID(),
           AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(dimensions as! AXValue, .cgSize, &size) {
            return (prompt, CGRect(origin: point, size: size), RaycastSearchField(focused))
        }
        return (prompt, nil, RaycastSearchField(focused))
    }
    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func attributes(_ element: AXUIElement, _ names: [String]) -> [CFTypeRef]? {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &values) == .success,
              let result = values as? [CFTypeRef], result.count == names.count else { return nil }
        return result
    }
}
