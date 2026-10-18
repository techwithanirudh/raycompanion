import Testing
@testable import ChatCore

@Test func accidentalDismissalResumesOnlyOnce() {
    var state = InlineChatReturn()
    let beforeDismissal = state.resume()
    #expect(!beforeDismissal)
    state.lostFocus()
    let firstOpen = state.resume()
    let secondOpen = state.resume()
    #expect(firstOpen)
    #expect(!secondOpen)
}

@Test func escapeCancelsAutomaticResume() {
    var state = InlineChatReturn()
    state.lostFocus()
    state.leave()
    let resumes = state.resume()
    #expect(!resumes)
}

@Test func rootGateRejectsOtherContexts() {
    #expect(RootSearchGate.accepts(isRaycast: true, hasRootResults: true, isSearchField: true, hasOverlay: false, plainTab: true))
    for flags in [(false, true, true, false, true), (true, false, true, false, true), (true, true, false, false, true), (true, true, true, true, true), (true, true, true, false, false)] {
        #expect(!RootSearchGate.accepts(isRaycast: flags.0, hasRootResults: flags.1, isSearchField: flags.2, hasOverlay: flags.3, plainTab: flags.4))
    }
}
