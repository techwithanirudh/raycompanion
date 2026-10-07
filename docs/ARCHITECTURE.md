# Architecture

RayCompanion has a small AppKit host and uses Tinycast's native chat and dictation components.

| Directory | Responsibility |
| --- | --- |
| `Sources/RayCompanion/App` | App lifecycle, menus and standard editing commands |
| `Sources/RayCompanion/Features/Raycast` | Root-search detection, Tab handoff and returning to Raycast |
| `Sources/RayCompanion/Features/Onboarding` | Setup screens and PermissionFlow |
| `Sources/RayCompanion/Windows` | Setup window ownership and reopening unfinished setup |
| `Sources/TinycastKit/Features/AI` | Conversations, native inline/full-window chat, providers and settings |
| `Sources/TinycastKit/Features/MCP` | MCP transport, OAuth, tools and Keychain-backed secrets |
| `Sources/TinycastKit/Features/Dictation` | Audio capture, speech models, shortcuts and text insertion |
| `Sources/TinycastKit/Features/Updates` | Sparkle controller and update preferences |
| `Sources/ChatCore` | Prompt gating, dismissal state and small transport/storage models |
| `Sources/DictationHelper` | Separate speech-model worker |

`AppDelegate` creates the host, starts `AppCore.startAIOnly()` through the adapter, and owns the Raycast handoff. Normal app opening shows unfinished setup or the full chat window. Login launches stay in the background. Raycast Tab opens the original inline AI screen at Raycast's captured position.

The native Raycast observer retries briefly while root search becomes ready. A periodic check covers missed notifications, and restoring consumes the pending return once. Escape and opening Settings cancel it.

Setup and chat windows register with the same activation-policy owner. Closing Settings cannot remove the Dock presence while setup is still open. Provider configuration uses the original provider panel attached to setup, and only the final setup action marks onboarding complete.

The palette mounts only AI and chat history. Unrelated launcher, clipboard, calendar, file-search and dictionary screens were removed. Some shared command models, stores and service types remain because the original coordinators and dictation text insertion still reference them. They do not start launcher, clipboard collection, snippets or Hyper Key hooks. See [the cleanup review](CLEANUP.md).

The updater reads Sparkle's own preferences and observes its last-check date. The release key stays in the login Keychain; only its public half is in the app. GitHub Releases hosts the signed feed and archive. See [release instructions](RELEASING.md).
