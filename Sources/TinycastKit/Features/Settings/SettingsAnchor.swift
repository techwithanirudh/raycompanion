import Foundation
import PermissionFlow

/// One `Section` inside a pane, named once so the catalog and the pane cannot disagree: the search
/// result carries the anchor, the pane's `.settingsAnchor(_:)` marks the section it scrolls to.
struct SettingsAnchor: Hashable, Sendable {
    let tab: SettingsTab
    /// The `Section`'s own header text, which is also what a result's breadcrumb reads.
    let title: String
}

// Named `<pane><Section>` throughout, so the constant for a section is always guessable from it.
extension SettingsAnchor {
    static let aiAI = Self(tab: .ai, title: "AI")
    static let aiProviders = Self(tab: .ai, title: "Providers")
    static let aiDefault = Self(tab: .ai, title: "Default")
    static let aiChat = Self(tab: .ai, title: "Chat")
    static let aiWebSearch = Self(tab: .ai, title: "Web search")
    static let aiConversations = Self(tab: .ai, title: "Conversations")
    static let aiSystemPrompt = Self(tab: .ai, title: "System prompt")
    static let aiMCPServers = Self(tab: .ai, title: "MCP Servers")
    static let aiCommands = Self(tab: .ai, title: "Commands")

    static let dictationDictation = Self(tab: .dictation, title: "Dictation")
    static let dictationCommands = Self(tab: .dictation, title: "Commands")
    static let dictationModel = Self(tab: .dictation, title: "Model")
    static let dictationMemory = Self(tab: .dictation, title: "Memory")
    static let dictationOutput = Self(tab: .dictation, title: "Output")

    static let extensionsInstalled = Self(tab: .extensions, title: "Installed")

    static let permissionsAccessibility = Self(tab: .permissions, title: String(localized: PermissionFlowResources.accessibilityNameResource))
    static let permissionsMicrophone = Self(tab: .permissions, title: "Microphone")

    static let aboutAbout = Self(tab: .about, title: "About")
}

/// Where a search result lands: a whole section, or one row inside it.
enum SettingsTarget: Hashable, Sendable {
    case section(SettingsAnchor)
    /// The row's visible title, which is also the catalog entry's — they are the same string.
    case row(SettingsAnchor, String)

    var anchor: SettingsAnchor {
        switch self {
        case .section(let anchor), .row(let anchor, _): return anchor
        }
    }

    var tab: SettingsTab { anchor.tab }
}

/// One jump asked for by a search result. The token is what makes picking the same result twice
/// scroll and pulse again, rather than comparing equal and doing nothing.
struct SettingsScrollRequest: Equatable, Sendable {
    let target: SettingsTarget
    let token: Int
}
