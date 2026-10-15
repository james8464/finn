# Native UI verification — 15 October 2026

## Scope

The redesign replaces the photo/glass dashboard with native tabs and semantic surfaces. It updates Workout, camera controls, results, History, Coach, onboarding, awards, Health prompts, widgets, Live Activities and Watch controls. Measurement rules and saved data formats are unchanged by this work.

[Design decisions](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG coverage](hig-ui-coverage.md)

## Preservation

The branch includes current main through `1056759`: French localization, best-set filtered history, squat visibility recovery and live/final rep-count reconciliation, movement-turn handling and the architecture documentation reorganization. Existing translations and plural rules are retained; new interface copy has French entries. Other worktrees and their uncommitted work were left intact.

## Review findings addressed

- Native tab destinations keep independent navigation state. Camera presentation keeps the underlying tab hierarchy alive, preserving nested destinations and Coach drafts. The new regression test reproduced the original reset before the fix.
- Accessibility layouts shorten the pinned privacy action, limit the instructional illustration’s growth, and keep the Coach information link readable with the keyboard open.
- Result navigation uses native toolbar actions; measured reps precede awards. Awards use readable rows in both appearances.
- White action labels use a deeper blue for contrast. The pinned privacy action uses primary text. The Debug demo marker sits below navigation and is excluded only from Dynamic Type auditing.
- The Health offer scrolls and opens at full height at accessibility text sizes.
- Demo Coach conversations use the existing local fallback. The unsigned iOS 27 simulator advertised Private Cloud Compute as available but trapped inside FoundationModels when asked to reply. Normal model selection is unchanged. This UI run does not validate live Apple Intelligence service access.

## Evidence

Final simulator results and representative captures are recorded here after the verification run.

The screen tours use explicitly labelled synthetic input. Widget and Live Activity captures are rendered previews. They are not evidence of camera accuracy, Health permission behaviour, physical Watch pairing or live model responses.

## Reproduce

Use the `Plumb` scheme with Xcode 27 and an iOS 27 iPhone simulator. Run `PlumbTests`, `DashboardUITests`, `NativeUIReviewUITests`, the onboarding tour, the demo set tour, and the setup/privacy/large-text accessibility audits in `WorkoutFlowUITests`.

Set `TEST_RUNNER_PLUMB_CAPTURE_DIR` for screen-tour PNGs and `TEST_RUNNER_PLUMB_WIDGET_RENDERS` for extension previews. Use `-collect-test-diagnostics never` if simulator failure diagnostics stall after a test run. Full test logs are local review artifacts, not committed build products.
