# Remotely onboarding reference

Source: https://github.com/techwithanirudh/remotely
Revision: `633f41dd4214dd56bf9a355c9b15b62ab76db5a9` (main).

RayCompanion adapts Remotely's compact onboarding, progress markers, StepLayout, PanelButton and DoneLine. The setup window is 350 by 430 points. Local SetupTheme holds the values used by the adapted components.

The flow is specific to this app: welcome → Raycast Accessibility → AI provider setup. PermissionFlow presents the Accessibility guidance and suggested app URL. Permission state refreshes without keyboard synthesis; Continue waits for actual approval. Closing postpones setup rather than marking it complete. Choose AI opens the native provider panel inside setup. Its Done action returns to setup; Start chatting completes onboarding and opens the full chat window. Dictation permission/model downloads stay optional in Dictation settings.

The MIT notice for these components is in `docs/licenses/Remotely.txt`. The app bundle includes it. No remote-control, HDMI-CEC, gesture engine or input-synthesis code is copied.
