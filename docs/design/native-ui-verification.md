# Native UI verification — 15 October 2026

## Scope

The redesign replaces the photo/glass dashboard with native tabs and semantic surfaces. It updates Workout, camera controls, results, History, Coach, onboarding, awards, Health prompts, widgets, Live Activities and Watch controls. Measurement rules and saved data formats are unchanged by this work.

[Design decisions](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG coverage](hig-ui-coverage.md)

## Preservation

The branch includes current main through `6173176`: French localization, best-set filtered history, squat visibility recovery and live/final rep-count reconciliation, movement-turn handling and the architecture documentation reorganization. The alternative single-screen redesign in `53e5646` and its follow-up UI commits through `6173176` were resolved in favour of this native-tab design at James’s explicit request; its commit remains in history. The subsequent integration includes the front-view push-up cue and award-celebration fixes plus the shared English test scheme. Existing translations and plural rules are retained; new interface copy has French entries. Other worktrees and their uncommitted work were left intact.

## Initial native pass: review findings

- Native tab destinations keep independent navigation state. Camera presentation keeps the underlying tab hierarchy alive, preserving nested destinations and Coach drafts. The new regression test reproduced the original reset before the fix.
- Accessibility layouts shorten the pinned privacy action, limit the instructional illustration’s growth, and keep the Coach information link readable with the keyboard open.
- Result navigation uses native toolbar actions; measured reps precede awards. Awards use readable rows in both appearances.
- White action labels use a deeper blue for contrast. The pinned privacy action uses primary text. The noninteractive Debug demo marker is excluded only from Dynamic Type auditing; it is absent from Release.
- The Health offer scrolls and opens at full height at accessibility text sizes.
- Demo Coach conversations use the existing local fallback. The unsigned iOS 27 simulator advertised Private Cloud Compute as available but trapped inside FoundationModels when asked to reply. Normal model selection is unchanged. This UI run does not validate live Apple Intelligence service access.

## Initial native pass: evidence

Verified on Xcode 27 / iOS 27, iPhone 18 Pro Max simulator:

| Check | Result |
|---|---|
| Unit tests | 468 passed across 53 suites after integration of the upstream fixes |
| Focused UI checks | 14 distinct checks passed across targeted review runs: four dashboard checks, four native-screen checks, two onboarding/award tours, one set tour and three accessibility audits |
| Final accessibility rerun | Workout setup → framing → capture → result passed after adapting the camera header and Done action for large text |
| Release build | Passed for the app, widget and embedded Watch targets; final layout changes compiled successfully |
| Translation preservation | Every entry from main at `6173176` retained unchanged; 46 additional UI entries |
| Motion and repository checks | Reduce Motion paths reviewed; local documentation links and whitespace checks passed |

The UI checks were run in focused batches, not as one complete UI-suite run. Setup and Privacy received full accessibility audits. The synthetic large-text flow checks descriptions, Dynamic Type, hit regions, clipping and traits; it excludes image-contrast sampling and the Debug marker’s intentionally capped text. The final camera header gives status a separate row at accessibility sizes, and Done moves below the result so it can scale.

### Initial captures

- [Summary](screenshots/2026-10-15-native-ui/summary.png) — normal launch, empty history.
- [Workout](screenshots/2026-10-15-native-ui/workout.png) — normal launch, camera not opened.
- [Large-text dark result](screenshots/2026-10-15-native-ui/result-large-text-dark-demo.png) — labelled synthetic input, from the passing final accessibility run.
- [Small widget](screenshots/2026-10-15-native-ui/widget-preview.png) — rendered preview.

The screen review also covered dark appearance, maximum text size with the Coach keyboard, the expanded Health sheet, French navigation, settings, privacy and awards. The yellow demo marker is a Debug annotation and is absent from Release.

The screen tours use explicitly labelled synthetic input. Widget and Live Activity captures are rendered previews. They are not evidence of camera accuracy, Health permission behaviour, physical Watch pairing or live model responses.

## Reproduce

Use the `Plumb` scheme with Xcode 27 and an iOS 27 iPhone simulator. Run `PlumbTests`, `DashboardUITests`, `NativeUIReviewUITests`, the onboarding tour, the demo set tour, and the setup/privacy/large-text accessibility audits in `WorkoutFlowUITests`.

Set `TEST_RUNNER_PLUMB_CAPTURE_DIR` for screen-tour PNGs and `TEST_RUNNER_PLUMB_WIDGET_RENDERS` for extension previews. Use `-collect-test-diagnostics never` if simulator failure diagnostics stall after a test run. Full test logs are local review artifacts, not committed build products.

## Monochrome widget refinement

James chose the earlier black-and-white exercise drawing over the coloured dashboard exploration. Summary now has a large exercise card, a real seven-day rep chart, compact Best set/Awards widgets and a recent workout only when saved data exists. Actions invert with system appearance. Removed introductory filler, redundant icons and the repeated Summary privacy footer; camera privacy remains beside Start and in Settings.

Workout and Coach use safe-area insets for their bottom controls. Summary uses automatic native title display: tests verify collapse on scrolling, expansion at the top and preserved position after a tab switch. Coach rejects blank or concurrent submissions before clearing its draft.

### Refinement evidence

- Two new activity aggregation tests passed: local capture date, midnight boundaries, future/out-of-range exclusion and the 25-hour autumn clock-change day.
- Nine focused UI checks passed across review batches: saved-session navigation, title/scroll preservation, native destinations, dark/largest text, French, light/dark setup audits, the demo set flow and the large-text setup/capture/result audit.
- Final corrected chart/scroll check and dark large-text workout audit both passed; screenshots confirm aligned bars and legible inverse result buttons. The final Release build passed.
- All 772 existing localization entries remain unchanged; six new keys include French translations.
- Review caught white result/error labels over the new dark-mode white buttons. Labels now use the inverse semantic foreground. The chart uses categorical weekdays so labels align with bars.

The earlier 468-test run belongs to the initial native pass; it was not repeated for this visual refinement. Large-text demo audits retain the contrast-sampling limitation described above. Physical camera accuracy and service integrations require device testing.

### Current captures

- [Summary](screenshots/2026-10-15-monochrome/summary.png) — normal launch.
- [Workout](screenshots/2026-10-15-monochrome/workout.png) — normal launch.
- [Saved activity](screenshots/2026-10-15-monochrome/summary-saved-demo.png) — labelled synthetic workout.
- [Dark Summary](screenshots/2026-10-15-monochrome/summary-dark-demo.png).
- [French Summary](screenshots/2026-10-15-monochrome/summary-french-demo.png).
- [Largest-text Workout](screenshots/2026-10-15-monochrome/workout-largest-text-demo.png).
- [Dark result with larger text](screenshots/2026-10-15-monochrome/result-large-text-dark-demo.png).
- [Largest-text Coach with keyboard](screenshots/2026-10-15-monochrome/coach-largest-text-keyboard-demo.png).

Keep this work on `ui/apple-native-revamp`, with PR 26 draft. Main and teammates' worktrees are unchanged by this refinement.
