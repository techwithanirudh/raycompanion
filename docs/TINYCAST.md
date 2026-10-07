# Tinycast source integration

Upstream: https://github.com/abue-ammar/tinycast
Revision: `71279c8de18fe77c56aa1cfaaeb68bf07748bbdd`.

`Sources/TinycastKit` is a source copy of upstream Tinycast, compiled as a SwiftPM module. RayCompanion uses the original `RootPaletteView`, `AIScreen`, `ChatHistoryScreen`, `ChatHistoryList`, `ChatHistoryPreview`, `MenuPanelController`, `PopoverMenu`, `AIModelMenu`, native markdown and math renderer, and standalone AI Chat sidebar/composer/toolbar. The earlier QuickChat chat and settings wrappers are removed.

The full AI backend is included: AIChatCoordinator, QuickAICoordinator, AIChatSurfacesState, SQLite ChatHistoryStore, AIProviderFactory, HTTP providers, Apple Intelligence, installed CLI providers, model discovery, MCP tools/OAuth, attachments, reasoning, title generation, context budgeting, conversation pin/rename/export/delete, per-chat model selection, and AI settings/provider editors. Installed providers, network accounts, models and MCP servers still need the user's configuration; source inclusion is not an end-to-end test of those external services.

## Integration changes

- `App/QuickChatAdapter.swift` exposes AI operations to the small QuickChat host and migrates previous provider/history data without deleting the originals.
- `AppCore.startAIOnly()` starts AI/MCP lifecycle and appearance observers. It does not run the upstream launcher startup, global hotkeys, Hyper Key, snippet listener, clipboard collection, or update checking.
- `PaletteWindowController` accepts an external frame and dismissal callback so the panel occupies Raycast's captured frame and Escape restores Raycast. Its global Command–Escape tap is disabled for QuickChat.
- The original settings split view is used, with sidebar/search restricted to AI, Dictation, General and About. General adds the Raycast Tab toggle and PermissionFlow accessibility button.
- Upstream app entry/delegate are excluded. The dictation worker lives in Sources/DictationHelper and builds separately from the UI module.
- AI command combinations load through Carbon without starting the upstream modifier tap monitor. Bare modifier shortcuts have not been enabled in this integration.
- The system prompt describes QuickChat accurately instead of advertising the unused Tinycast launcher features. The test-only settings/menu entry points do not synthesize keyboard events.
- Assets are compiled with `actool`; native glass, icons, spacing, menu geometry and menu animations remain upstream implementations.

The library includes upstream supporting features because the AI coordinators and palette reference the shared AppCore. These do not start through `startAIOnly()`. A later reduction must preserve the original AI paths and avoid replacing working upstream components with local approximations.

## Validation

The upstream `ai-chat-test.swift`, `ai-provider-test.swift` and `chat-markdown-test.swift` are retained in `Checks` and compiled against the actual integrated module with `@testable import TinycastKit`:

```
swift run AIChatChecks
swift run AIProviderChecks
swift run MarkdownChecks
```

The local HTTP test server in `scripts/test-provider.py` tests streaming without credentials. Only a separate `.testing` app bundle can install the fixture connection; the production app never synthesizes replies. Desktop proof is saved in `evidence`. Physical Raycast Tab/typing/focus testing remains a separate requirement.

Upstream license and asset notices are retained in `docs/licenses` and the app bundle.

Current checks: 305 chat/state/history, 790 provider/model/stream and 45 native Markdown checks passed; the seven ChatCore tests also passed. HTTP streaming, history preview, provider editor and the ⌘J window transfer were captured on the desktop. Physical Tab/typing/Escape must still be confirmed after installing this build.

RayCompanion retains the native AI and Dictation components, with app branding and About promotions replaced. Calendar permission UI/search and its usage description are removed. Accessibility/Microphone controls use centered HStacks. The host uses an AppKit entry point to avoid SwiftUI creating an empty duplicate Settings scene. The history divider extends beneath the floating footer. Dictation key combinations use Carbon; modifier-only hooks remain disabled. The original bundle identifier stays stable to preserve settings, history, Keychain and Accessibility approval.

See [cleanup review](CLEANUP.md) for removed source and the shared feature dependencies still retained. Sparkle is included as an external package; update controls live in About. See [release setup](RELEASING.md). The user confirmed exact Tab delivery, normal typing and Escape in the installed full-source build.

Manual app launch and reopen use the full chat window, or unfinished onboarding. Only Raycast Tab uses the inline palette. Login detection uses LaunchAtLogin-Modern at `a04ec1c363be3627734f6dad757d82f5d4fa8fcc`. Empty Tab expands a collapsed Raycast bar to the native panel height. Accidental focus dismissal preserves the inline draft and arms a one-time return when Accessibility confirms Raycast root has reopened; Escape cancels that return. No Command-Space keyboard hook is added.

RayCompanion restricts palette modes to AI and chat history. The upstream Tab cycle is disabled in this scope, so it cannot reveal Clipboard, Dictionary or launcher screens. Calendar and Clipboard search warmup do not run for the AI-only palette. Accessibility root checks batch attributes through Apple's API, and the adapter does not reset the view after the coordinator opens it. The palette tint was adjusted using the supplied Raycast screenshots; System appearance remains the default, with Light/Dark choices in General.

The host installs a standard Edit menu with actions routed through the native first responder. Select All was verified in both composers with a native action and desktop screenshots. Settings opening clears any pending inline return and hides the palette without activating Raycast. About and app menus include Replay setup and update controls; checking for updates stays disabled until a signed feed is configured.

Onboarding keeps setup unfinished while PermissionFlow or the native provider panel is open. Continue starts PermissionFlow directly; provider Done returns to setup, and Start chatting completes it. Reopening the app preserves the unfinished step. The optional Exa key uses native MCP Keychain storage and the hosted search/fetch tools; authenticated search still needs a user key for end-to-end verification. The context card shows a short summary by default, with technical details available from the context indicator.
