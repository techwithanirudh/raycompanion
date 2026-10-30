import Foundation

@testable import TinycastKit

extension AIChatTests {
    static func instructionsNameTools() {
        let sources = ["a calculator", "Klack"]
        let off = AIInstructions.compose(userPrompt: "Be brief.", isEnabled: false, toolSources: sources)
        expect(
            off == AIInstructions.toolNote(sources),
            "Tools are named even with custom instructions off")
        expect(
            AIInstructions.compose(userPrompt: "Be brief.", isEnabled: false) == nil,
            "No tools and no instructions send nothing")
        let on = AIInstructions.compose(userPrompt: "Be brief.", isEnabled: true, toolSources: sources) ?? ""
        expect(
            on.hasPrefix(AIPreamble.text) && on.hasSuffix("Be brief.") && on.contains("Klack"),
            "The tool note sits between the preamble and the user's text")
        expect(
            AIInstructions.compose(userPrompt: "  ", isEnabled: true) == AIPreamble.text,
            "Blank custom instructions leave the preamble alone")
    }
}
