import Foundation
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

@Test func streamingContentAndCompletion() throws {
    var parser = EventStream()
    #expect(try parser.consume(line: ": keepalive") == nil)
    #expect(try parser.consume(line: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello 🦊\"}}]}") == nil)
    #expect(try parser.consume(line: "") == .text("Hello 🦊"))
    #expect(try parser.consume(line: "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}") == nil)
    #expect(try parser.consume(line: "") == nil)
    _ = try parser.consume(line: "data: [DONE]")
    #expect(try parser.consume(line: "") == .done)
}

@Test func providerErrorsAreNotSilentlyAccepted() throws {
    var parser = EventStream()
    _ = try parser.consume(line: "data: {\"error\":{\"message\":\"private upstream details\"}}")
    #expect(throws: EventStream.Failure.providerError) { try parser.consume(line: "") }
    _ = try parser.consume(line: "data: broken")
    #expect(throws: (any Error).self) { try parser.consume(line: "") }
}

@Test func rootGateRejectsOtherContexts() {
    #expect(RootSearchGate.accepts(isRaycast: true, hasRootResults: true, isSearchField: true, hasOverlay: false, plainTab: true))
    for flags in [(false, true, true, false, true), (true, false, true, false, true), (true, true, false, false, true), (true, true, true, true, true), (true, true, true, false, false)] {
        #expect(!RootSearchGate.accepts(isRaycast: flags.0, hasRootResults: flags.1, isSearchField: flags.2, hasOverlay: flags.3, plainTab: flags.4))
    }
}

@Test func historyRoundTripPreservesPrompts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = HistoryFile(url: directory.appendingPathComponent("history.json"))
    #expect(try file.load().isEmpty)
    var conversation = Conversation()
    conversation.messages = [.init(role: .user, content: "  exact\nprompt 🦊  "), .init(role: .assistant, content: "## A reply")]
    try file.save([conversation])
    #expect(try file.load() == [conversation])
}

@Test func credentialsOnlyGoToValidEndpoints() throws {
    let config = APIConfiguration(baseURL: "https://openrouter.ai/api/v1", model: "chosen-model", key: "")
    #expect(try config.endpoint().absoluteString == "https://openrouter.ai/api/v1/chat/completions")
    for invalid in ["http://example.com/v1", "https://key@example.com/v1", "https://example.com/v1?key=secret", "not a URL"] {
        #expect(throws: (any Error).self) { try APIConfiguration(baseURL: invalid, model: "chosen-model", key: "").endpoint() }
    }
}
