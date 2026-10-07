# Tasks

- [x] Rename the remaining executable/product to RayCompanion while keeping the stable data and permission identity.
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
