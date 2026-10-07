# Current implementation

QuickChat uses the native Tinycast AI palette through a small Accessibility/Tab adapter. The Raycast extension described below is historical and has been removed. See TINYCAST.md for the current source integration.

# Raycast integration

## Current behavior

QuickChat’s main chat is a Raycast extension. The Swift app opens settings by default and provides the Raycast-only Tab hook. No keyboard events are synthesized for command launching. The native chat is retained for explicit `--native` development use.

At confirmed root search, Tab captures the field’s exact AXValue. The helper writes a 0600 one-use prompt file, then opens `raycast://extensions/techwithanirudh/quickchat/chat` with a launch-context handoff ID. The extension only consumes the matching prompt, preventing an older command launch from stealing a newer prompt. The URL contains the ID rather than the question. Raycast may require deeplink confirmation.

The extension streams Markdown in List.Item.Detail. The search bar is the follow-up composer; Enter sends. History uses Raycast navigation and returns to the chat when a conversation is selected. Provider configuration is in Raycast extension preferences; the Swift Models page opens those preferences. The native app’s previous provider settings do not configure the extension.

Raycast controls the window position, dimensions, styling, and Escape navigation. We do not resize its window. Escape returning to root with the expected position and size was confirmed by the user.

## Custom UI investigation

Public UI: https://developers.raycast.com/api-reference/user-interface
FAQ: https://developers.raycast.com/misc/faq
Navigation: https://developers.raycast.com/api-reference/user-interface/navigation
Deeplinks: https://developers.raycast.com/information/lifecycle/deeplinks

The public API exposes List, Grid, Detail, Form, and ActionPanel. It does not expose an arbitrary HTML/CSS/WebView or custom SwiftUI surface. AI SDK supplies model streaming, while Raycast components supply the UI; AI SDK web UI components cannot be mounted directly here.

Read-only inspection of installed Raycast 2.7.0.0 on October 7, 2026 found a bundled `frontend/ai-chat-window.html`, JavaScript modules, and chat-layout CSS in `macos-app_RaycastDesktopApp.bundle`. Thus the older docs describing purely AppKit rendering do not fully describe the installed app’s internal implementation. These internal files are not a documented extension API.

Options:

- Native extension: implemented. Raycast owns placement, theme, focus, actions, and back navigation. Layout is limited to exposed components.
- Separate SwiftUI panel: feasible with the already captured AX bounds, a matching visual design, and reactivation of Raycast on Escape. Focus, Space/display changes, restored root text, and resizing would need physical testing. It remains a separate window. Not implemented as the main flow.
- Images/SVG in Markdown: possible for static visuals, but no interactive DOM or custom text controls. This does not solve a richer chat composer.
- Patch bundled frontend files: technically a resource-modification experiment, not a supported integration. Installed Raycast has hardened runtime and sealed signed resources. Editing resources invalidates that seal; a modified copy would need its own signing and may change macOS permissions and update behavior. Updates can replace the files. No app patch or code injection was attempted, and arbitrary custom UI compatibility has not been established.

Recommendation: keep the native extension for the first version. If a bottom composer or custom message layout becomes essential, build a separate panel with deliberate focus restoration rather than depend on Raycast’s private frontend.

## Verification

- Native app builds and is installed at /Applications/QuickChat.app.
- Extension build/typecheck succeeds.
- Inbox tests cover exact Unicode/whitespace, one-use consumption, expired/public-readable files, and stale launch IDs.
- The helper’s direct test command delivered a known Unicode prompt; the inbox was consumed and Raycast displayed it with a streamed demo reply. Screenshot: ../evidence/raycast-chat.png.
- User confirmed Escape returns correctly. User confirmed the updated physical root-Tab-to-extension path delivers the exact question.
- Real paid-provider responses have not been verified with a user API key in this extension. Demo mode is enabled.
