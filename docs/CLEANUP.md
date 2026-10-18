# Tinycast dependency review

The app keeps Tinycast's actual AI and Dictation implementations. This review removes unused features without replacing working native components or restarting keyboard hooks.

## Removed

- The old custom update checker/downloader/installer/relauncher and its UI. Sparkle replaces that path.
- Donation windows and reminder scheduling, promotional About links and the unused upstream menu-bar implementation.
- Nineteen unused settings panes and their local-only editor views; the settings detail route/search now expose General, AI, Dictation and About only.
- The full launcher startup, launcher feature-observer registration, auxiliary-window reopen routing and update/support interruption logic.
- Calendar permission UI/search and unrelated permission declarations.
- The unused Inter font, upstream app icon, app plist/entitlements and duplicate worker source tree. The speech worker remains under Sources/DictationHelper.

Forty-seven old Swift files were removed or relocated, including six unused duplicate dictation worker files. `ToolRunner` is retained under Platform because Apple Shortcut execution still references it. Two small shared request models were extracted from deleted settings files. The old AppCore shrank from 980 to 649 lines; the settings search catalog was also reduced.

## Feature directory removal (16 October)

Periphery 3.8 (`periphery scan --retain-objc-accessible --retain-codable-properties`, all targets including the checks) mapped what the app reaches; two passes removed every file it reported fully unused. The WindowManagement, WindowSwitcher, Notes, Emoji, Snippets, Backup, Calendar, QuickActions, CustomCommands, Quicklinks, Uninstall, SystemActions, MenuSearch, Camera, AppleShortcuts and Dictionary directories are gone, along with the settings.json mirror (`SettingsFileSchema` and its value/issue/JSON types), `AppIndex`, the clipboard and calculator screens, and the dialog volume, event and snippet-argument accessories. TinycastKit went from roughly 101k to 65k lines.

`AppEntry` now lives in `Launcher/Service/AppEntry.swift`. `CommandID` keeps its cases as inert identifiers so the launcher-shaped palette, hotkey and settings switches stay intact; the four built-in quick-action names and symbols are inlined. `HotKeyAction` keeps only palette, dictation, command, app, settings-pane and extension-command bindings. `AppCore` no longer creates the removed stores at launch.

## Still required by copied source

The palette still treats the launcher as its home mode, so `PaletteMode`, `CommandID`, `CommandCatalog`, the ranking/alias/visibility/favorite stores and the extension subsystem (`ExtensionManager`, installer, store client) remain. The extension runtime also backs the imported AI tools. `AppSettings` still declares settings for removed features; Periphery's member-level report lists them for a later pass. Rebuilding the palette around AI alone would mean replacing upstream views, which AGENTS.md rules out.

The only keyboard routes started are the root-only Raycast Tab tap and Carbon AI/dictation key combinations. Launcher, Hyper Key, snippet and modifier-only keyboard hooks do not start.

## Validation

Run `./scripts/check.sh` and `./scripts/build-app.sh`. Keep UI/HTTP fixtures in a `.testing` bundle. Physical Tab, exact prompt, normal typing and Escape were confirmed by the user before this cleanup; handoff changes require another physical check.

## File inventory

- `App/MenuBarItem.swift`
- `Features/AppleShortcuts/Settings/AppleShortcutsSettingsView.swift`
- `Features/Backup/Settings/BackupSettingsView.swift`
- `Features/Calendar/Settings/CalendarSettingsView.swift`
- `Features/Clipboard/Settings/ClipboardSettingsView.swift`
- `Features/CustomCommands/Settings/CommandsSettingsView.swift`
- `Features/Emoji/Settings/EmojiSettingsView.swift`
- `Features/Extensions/Settings/ExtensionsSettingsView.swift`
- `Features/FileSearch/Settings/FileSearchSettingsView.swift`
- `Features/Launcher/Settings/ApplicationsSettingsView.swift`
- `Features/Launcher/Settings/FallbacksSettingsView.swift`
- `Features/Launcher/Settings/SystemSettingsSettingsView.swift`
- `Features/Notes/Settings/NotesSettingsView.swift`
- `Features/QuickActions/Settings/QuickActionsSettingsView.swift`
- `Features/Quicklinks/Settings/QuicklinksSettingsView.swift`
- `Features/Settings/Panes/GeneralSettingsView.swift`
- `Features/Settings/Panes/NavigationSettingsView.swift`
- `Features/Snippets/Settings/SnippetsSettingsView.swift`
- `Features/Support/Model/SupportReminderSchedule.swift`
- `Features/Support/Service/SupportReminderStore.swift`
- `Features/Support/UI/SupportCoordinator.swift`
- `Features/Support/UI/SupportWindowView.swift`
- `Features/SystemActions/Settings/SystemActionsSettingsView.swift`
- `Features/Updates/Model/AppVersion.swift`
- `Features/Updates/Model/ReleaseArchitecture.swift`
- `Features/Updates/Model/ReleaseChannel.swift`
- `Features/Updates/Model/ReleaseFeed.swift`
- `Features/Updates/Model/ReleaseNotes.swift`
- `Features/Updates/Model/UpdateReadiness.swift`
- `Features/Updates/Service/BundleSignature.swift`
- `Features/Updates/Service/Quarantine.swift`
- `Features/Updates/Service/RelaunchRunner.swift`
- `Features/Updates/Service/ToolRunner.swift`
- `Features/Updates/Service/UpdateCheckStore.swift`
- `Features/Updates/Service/UpdateDownloader.swift`
- `Features/Updates/Service/UpdateFailure.swift`
- `Features/Updates/Service/UpdateInstaller.swift`
- `Features/Updates/UI/ReleaseNotesView.swift`
- `Features/Updates/UI/UpdateCoordinator.swift`
- `Features/Updates/UI/UpdateWindowView.swift`
- `Features/WindowManagement/Settings/WindowManagementSettingsView.swift`

## Public-release cleanup

The second review removed the unused Tinycast onboarding flow, editor panels, launcher/favorite UI, emoji grid, and unrelated clipboard-adjacent palette screens. The palette keeps the original AI and history screens, menu handling and window layout. Settings no longer injects unused room, calendar, quicklink, snippet or custom-command coordinators. The app host now lives under `Sources/RayCompanion`; its executable is RayCompanion, and its bundle identifier is `com.anirudh.raycompanion`.

Shared models and services that still compile into AI, shortcut storage, the palette state or dictation insertion remain under their feature directories. This review does not replace them with empty implementations.

This pass removed 57 Swift files. The removed files include 50 unreferenced components, four old onboarding files, two editor views whose shared request models moved into Model, and the unused onboarding dialog mock. The full chat/provider/Markdown/core suite passed after removal.

## Additional dependency cleanup

Removed twelve unreferenced calendar, file-preview and extension-setup views and helpers, totaling 1,215 lines. Removed two obsolete host menu actions and unused palette environment reads. Shared launcher stores remain in AppCore. AI command settings now contain shortcut controls only. Provider dependencies are also supplied directly to the AI pane to preserve its SwiftUI environment across navigation.

## Startup and lifecycle review

Eight unrelated stores now initialize on demand instead of during app startup: quicklinks, window layouts, custom window sizes, rooms, room minimums, room parking, snippets and notes. The palette no longer injects the unused quicklink and snippet stores. Removed four uncalled feature-update helpers, an unused health ticker and three obsolete shutdown methods. RayCompanion keeps its adapter shutdown and the original AI/dictation services. The integration adapter is named AIAdapter.swift.

## Follow-up reference review

Removed seven unused calendar, dictionary, room, window-layout, clipboard and extension-settings UI files. Removing those views left the launcher actions menu and window-layout draft without callers, so those two files were removed too. Shared scrolling, tooltip, focus, dialog and extension-field modifiers remain because other views still call them. AI and dictation views are unchanged.

## Launcher and branding review

Removed the unused launcher settings list and table, command-argument row and file media player. Removed alias editing controls and the old QuickChat provider/history migration. RayCompanion and its dictation helper now have their own bundle identifiers. AI shortcut controls now live in AI/Settings, without launcher visibility controls. Shared launcher models used by AppCore and shortcut storage remain.

## MCP SDK review

Reviewed the official [Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) at `a0ae212ebf6eab5f754c3129608bc5557637e605`. Its typed client, protocol negotiation and streaming HTTP support are useful candidates for a future migration. The package has not been added.

The SDK's stdio transport accepts file descriptors; RayCompanion would still own subprocess launch and shutdown. OAuth still needs app-specific browser callbacks and Keychain token storage. The public HTTP initializer accepts a URLSessionConfiguration but constructs its own session, so replacing the current transport requires preserving the app's same-origin redirect rules through a supported integration. Existing transport checks must be ported before a switch.
