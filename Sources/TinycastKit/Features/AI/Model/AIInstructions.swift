import Foundation

/// Every turn carries `AIPreamble`, the tools it may use, then the user's text.
/// Turned off, it carries only the tools.
enum AIInstructions {
    /// The user's own text goes last, so it can qualify the preamble rather than fight it.
    static func compose(userPrompt: String?, isEnabled: Bool, toolSources: [String] = []) -> String? {
        let tools = toolNote(toolSources)
        guard isEnabled else { return tools }
        let trimmed = userPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return [AIPreamble.text, tools, trimmed.isEmpty ? nil : trimmed]
            .compactMap { $0 }.joined(separator: "\n\n")
    }

    /// Named because a route with many tools hides them behind a search the model must choose to run.
    static func toolNote(_ sources: [String]) -> String? {
        guard !sources.isEmpty else { return nil }
        return "This chat can act through tools: \(sources.joined(separator: ", ")). "
            + "When a request needs one of them, use the tool instead of saying you cannot."
    }
}
