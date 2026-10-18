- [x] Remove PhotoZoomUI and use native NSScrollView magnification. Signed build and 1,154 checks passed; native double-click zoom, Fit and outside dismissal verified. Reviewed MCP, history and shortcut library candidates.
# Tasks

- [ ] Remove unreachable Tinycast code found by Periphery: sixteen feature directories, the settings.json mirror, `AppIndex`, unused palette/dialog hooks and unused ChatCore types; drop the `tinycast://` scheme. A member-level pass with `scripts/unused.sh` removed about 4,400 more lines. TinycastKit fell from about 101k to 61k lines; build, signed bundle and all checks pass. The inline chat, Settings and dictation still need a physical pass in the installed app.

- [ ] Review fixes from 16 October: share one local tool bridge across chats so Codex no longer relaunches between chats; always honor an extension's exported confirmation; stop leaked Raycast event taps from swallowing Tab; build 3 and release guards for the designated requirement and build number. Checks pass; physical Tab handoff and a Codex turn across two chats are not yet verified.

- [ ] Medium review fixes from 16 October for tool calls: the local bridge keeps one task per connection and cancels it on client hang-up, the 180 s idle drop and `stop()`; a failed bridge start is retried instead of cached; local, extension and MCP tools re-check cancellation after every consent dialog and before running; an extension's 90 s timeout pauses while its confirmation waits, and cancelling the call dismisses that confirmation. Tool consent dialogs queue behind an open dialog instead of reporting "declined", a cancelled call withdraws its queued or visible dialog, and a held ↵/Esc no longer repeats into the next dialog. `raycompanion` is a reserved MCP handle (stored servers holding it are moved aside on load); chat and CLI-consent routing use exact membership in the offered tool list and re-check local enablement and the chat's tools menu; bridge names split on the first `__`. Verified by ./scripts/check.sh (366 chat checks including 33 new routing/reserved-handle/bridge-restart/hang-up/stop/confirmation-cancel checks, 790 provider, 45 Markdown, swift test) and a clean build with 0 warnings. Not yet physically verified: two parallel tool calls showing queued consent dialogs one after another, Stop dismissing a visible consent dialog, a Codex turn cancelled mid-dialog, and an extension confirmation left open past 90 s still running when approved.

- [x] Add calculator, scoped file search/read and selected-text tools to supported API routes and a local MCP bridge for CLI routes. Native calculator execution, file policy/read tests and transport checks passed.
- [ ] Physically verify selected-text capture and authenticated Codex/Claude tool calls in the installed app.
- [x] Import installed Raycast AI-tool bundles without launcher startup. Native Base64 execution, confirmation/result checks, argument-free tool schemas and aligned settings were verified. Preferences/storage use separate Keychain scopes; OAuth and some APIs remain unsupported.

- [x] Compare Raycast AI tools and Tinycast provider/runtime design. Official CLI schema generation and Tinycast runtime-harness confirmation/result checks passed; findings and implementation plan are in docs/AI-TOOLS.md. Native extension integration is not implemented.

- [x] Fix Settings reopen and delayed focus races. Native focus checks and reopening General passed; all 1,154 checks passed. Reviewed the official MCP SDK and documented migration requirements; it is not added. Physical Raycast shortcut reliability remains a separate check.

- [x] Remove backdrop dimming and preserve outside dismissal; native popup screenshot verified.

- [x] Add temporary Quick Chat without history persistence and save when continuing in the chat window. Seven lifecycle checks passed, including disk reload and cancellation; native setting verified.
- [x] Add an image zoom popup within the existing chat and equal image-only bubble padding. Click, zoom, Fit, close and outside dismissal verified on desktop; physical Escape and pinch remain user checks.

- [ ] Start the Raycast Tab hook immediately on focus notifications and retry until ready; verify the first physical Tab.

- [x] Preserve Settings on app reopen; General remained open without a chat window. Added the native startup warning and verified its Grant Access action opens PermissionFlow in an isolated bundle. Signed build and core tests passed.
- [ ] Replace the process-specific tap after doubled Raycast typing; run the session tap only while Raycast is frontmost, then verify physically.

- [ ] Limit the Tab event tap to Raycast and verify physical typing and handoff after the doubled-input report.

- [x] Align the General Tab default with startup. Signed build passed and installed switch is on.
- [ ] Verify physical Tab after permission approval. The installed app now reports Granted; typing is normal, but handoff still needs verification after the focused-application check.

- [x] Move Exa key setup, replacement and deletion into a native modal; keep disabling search separate, and verify the layout. All 1,147 checks and the signed build passed; desktop layout verified.

- [x] Review copy across reachable chat, onboarding, settings and provider screens; remove redundant explanations and unused launcher components, then verify. All 1,147 checks and the signed build passed; desktop layout verified.

- [x] Finish RayCompanion bundle rebrand, remove legacy migration and alias controls, center editor labels, and verify the app. All 1,147 checks and the signed build passed; desktop layout verified.

- [x] Simplify README copy and refresh its cover; give web search a native section and search-type picker, balance the Providers header, combine permission status with its button, and verify the installed UI. All 1,147 checks and the signed build passed; desktop layout verified.

- [x] Review newly unreferenced components after the startup cleanup. Removed nine unused files and 1,321 lines; all 1,147 checks and the signed build passed. Settings and Providers Manage/Done verified on the desktop.

- [x] Remove the Providers subtitle; defer eight unused feature stores and remove dead lifecycle helpers. All 1,147 checks and the signed build passed; Providers Manage/Done verified on the desktop.

- [x] Remove twelve unreferenced upstream views/helpers and obsolete host actions. All 1,147 checks and the signed build passed; AI Settings and Providers Manage/Done verified on the desktop.

- [x] Fix Settings crashing from chat actions, simplify the menu-bar menu, and remove the About footer. Native three-dot Settings reopen and Providers Manage/Done passed; About screenshot verified.

- [x] Rename the executable/product to RayCompanion. The later full rebrand also replaced the bundle identifier.
- [ ] Retry Raycast root readiness after accidental dismissal and recover a disabled Tab tap; verify physically.

- [x] Keep updates and onboarding replay in About, use a flat sidebar, and follow Remotely's settings layout.
- [x] Use PermissionFlow's macOS-aware permission name, use SF Symbols consistently, and allow skipping Raycast permissions.
- [x] Review unused code again, remove unreachable components, and organize the app host by feature.
- [x] Generate a dedicated Sparkle key in Keychain, publish the signed HTTPS appcast/archive, and verify an isolated upgrade. Sparkle installed build 2 from the public release and relaunched; signature and executable hash matched.
- [x] Refresh README/screenshots, squash the source history into one commit, and publish the existing repository as public.

- [x] Build a SwiftPM macOS app without an Xcode project.
- [x] Research Raycast extension limitations and direct prompt handoff; recorded in docs/RAYCAST.md.
- [x] Remove the previous Raycast extension and Luminare settings shell.
- [x] Replace all AI UI/backend paths with actual Tinycast source; build, run upstream checks, and capture chat, actions, history, settings and standalone-window proof.
- [x] Verify normal physical typing, exact Raycast Tab prompt delivery, overlay stacking and Escape after the full Tinycast integration (user confirmed).
- [ ] Verify externally configured API/installed/MCP provider routes with real user accounts when available.

- [x] Rename the app to RayCompanion, replace promotional branding/icon, remove Calendar permissions, and center permission controls; verify installed UI.

- [x] Rename Permissions to General and make Tab handoff the default first-run path.
- [x] Adapt Remotely onboarding using PermissionFlow and native AI/provider setup.
- [x] Review and remove unused Tinycast source and old update/support code; retained dependencies documented in docs/CLEANUP.md.
- [x] Add Sparkle with signing/feed configuration and release instructions.
- [x] Configure a signed HTTPS update feed and test a real Sparkle upgrade.
- [x] Create a private GitHub repository with a verified README and CI configuration.
- [ ] Verify the first GitHub CI run.

- [ ] Center alerts over their parent window, constrain dimming to rounded bounds, and reduce Raycast handoff flashing.
- [ ] Verify minimum chat height after empty Tab and install the corrected build.
- [x] Center and polish onboarding, simplify General wording, and remove the duplicate General sidebar heading; window bounds and desktop screenshots verified.
- [x] Replace the app icon and soften its About shadow; user approved the coral mark.
- [ ] Use the new mark in the menu bar and dictation helper, and verify the appearance selector and lighter panel tint.
- [ ] Restrict inline navigation to AI/chat history and verify Tab/Backspace cannot reveal launcher, Clipboard or Dictionary screens.
- [ ] Verify faster Tab capture using batched Accessibility reads; physical handoff timing still requires the user.
- [x] Restore the standard Edit menu; native Select All selects the entire text in both composers. Physical shortcut confirmation remains pending.
- [ ] Rename AI Settings actions to Settings, add Replay setup and standard update controls to About/app menus.
- [ ] Keep the last conversation when reopening chat; preserve explicit user timeout settings.
- [x] Install the requested unslop skill and apply it to the new app text.
- [x] Verify manual launch/reopen returns to unfinished onboarding or the full chat window, and --background opens no window. Login-event detection uses LaunchAtLogin; a real OS login is not yet tested.
- [x] Restore an accidentally dismissed inline chat when Raycast reopens, while Escape explicitly returns to Raycast; user confirmed both physically.

- [ ] Verify Settings opens without activating Raycast, including the inline action menu.

- [x] Keep onboarding open while configuring providers; provider Done returned to setup with Start chatting as the final action.
- [ ] Simplify the context summary and show technical details only on request.
- [ ] Add an Exa API key field backed by Keychain and the existing MCP search tools; verify configuration and tool routing.
- [ ] Clear the captured Raycast query only after a successful chat handoff, without keyboard synthesis; verify physically.
- [x] Use Continue to start PermissionFlow directly, and remove the duplicate permission button; the native guide opened on the desktop.
- [x] Preserve unfinished onboarding when reopening the app, including while PermissionFlow is open; the permission step remained visible after app reopen.
- [ ] Add standard File, View, Window and Help menus, and route Close Window to native chat, setup and provider panels; verify physically with Command-W.

- [x] Add Enable all, the three-choice tool approval menu with Allow reads as default, and scroll-edge fades. Native checkbox toggles, approval choices and edge fades verified; 333 chat checks passed.

- [ ] Investigate Codex reporting no MCP tools with all imported extensions enabled; verify server discovery and a live tool call.
