# RayCompanion

- Build with SwiftPM and scripts/build-app.sh. Do not create an Xcode project.
- Keep tasks in TODO.md; mark complete only after the relevant verification.
- RayCompanion's host is small. Actual AI UI, settings, coordinators and providers come from the pinned Tinycast source in Sources/TinycastKit. Read docs/TINYCAST.md before changing it.
- Preserve upstream component implementations. Make Raycast integration changes in the adapter and window boundary; do not recreate Tinycast views or replace its backend with canned answers.
- Keep the feature-oriented upstream Model/UI/Service/Settings structure.
- Never run AppCore.start() from RayCompanion. Use startAIOnly(); global launcher, Hyper Key, clipboard collection and snippet hooks must stay out of this app's startup.
- PermissionFlow and Sparkle are pinned. Read their documentation/source before changing integration.
- Keep source license and asset notices in the repo and app bundle.
- No commits or pushes without the user's explicit request. Repository creation authorizes its initial commit/push only. Keep credentials in Keychain, never logs or fixtures.
- Verify the actual desktop and capture screenshots. Do not synthesize keyboard input; the user tests physical Tab, typing and Escape. Stop manually started test app/server instances after proof.
