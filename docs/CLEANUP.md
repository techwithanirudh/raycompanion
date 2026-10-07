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

## Still required by copied source

The original RootPaletteView, PaletteState, HotKeyManager, AppSettings and AppCore still name launcher/clipboard/snippet/window/extension types. SettingsEnvironment and TextInjector also reference these types. Their background feature startup is removed, but some shared stores still construct during view/environment initialization. These files are retained to preserve the exact upstream AI UI and dictation output paths; this is not a claim that every remaining file is AI-only.

A complete removal of those feature directories requires first extracting the AI-only palette and settings environment, reducing the command/shortcut catalogs, and separating TextInjector's clipboard/snippet dependencies. That should be a dedicated change with the full AI checks and physical Tab/typing/Escape regression checks, not bulk deletion of files that still compile into shared types.

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

The second review removed the unused Tinycast onboarding flow, editor panels, launcher/favorite UI, emoji grid, and unrelated clipboard-adjacent palette screens. The palette keeps the original AI and history screens, menu handling and window layout. Settings no longer injects unused room, calendar, quicklink, snippet or custom-command coordinators. The app host now lives under `Sources/RayCompanion`; its executable is RayCompanion, and the bundle identifier stays stable to preserve permissions and stored data.

Shared models and services that still compile into AI, shortcut storage, the palette state or dictation insertion remain under their feature directories. This review does not replace them with empty implementations.

This pass removed 57 Swift files. The removed files include 50 unreferenced components, four old onboarding files, two editor views whose shared request models moved into Model, and the unused onboarding dialog mock. The full chat/provider/Markdown/core suite passed after removal.
