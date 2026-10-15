# Finn: integrated app and interface review

Updated 16 October 2026. Continues the [branch consolidation](branch-cleanup-2026-10-15.md). Bundle identifiers, app group and saved-data compatibility remain unchanged.

## Changes found through testing and visual review

- Removed duplicate Language and Workout feedback sections left by integration. Removed the duplicate stage observer that played set-start and set-finish feedback twice.
- Rebuilt Options as a native grouped Form, retaining every preference, Health action, language selection, welcome replay and Debug coach control.
- Rebuilt Privacy around three short facts and expandable complete disclosures. Added explicit Apple Intelligence / Private Cloud Compute handling for Coach questions and saved summaries.
- Finn is dark-only at the SwiftUI presentation root and in its iOS configuration, including sheets and UIKit controls. Removed light-specific navigation and colour branches. Supporting pages use semantic dark surfaces and native text styles. Home retains the approved charcoal/pink design. Supporting navigation uses compact visible titles.
- Simplified Workout setup and results into opaque content cards with one pink primary action. Result counts expose the measured total to accessibility. Rep charts use categorical rep positions; a rendered-pixel regression checks highlighted bars.
- Coach has a readable introductory card, native toolbar information action, and an opaque keyboard composer. Posture retains the measured-evidence rules and illustrated exercise guide, with accessible playback controls and Reduce Motion support.
- Session detail uses grouped sections per set, with vertically stacked counts at accessibility sizes. Settings uses the Finn mark and wraps replay text.
- Kept real front-view push-up counting without side-view posture advice. Updated obsolete refusal expectations and navigation tests to the integrated behavior; accessibility audits remain enabled.

## Integrated feature coverage

| Area / originating improvements | Coverage |
| --- | --- |
| Form analysis, trends, partial visibility, tracking and recognition | Analyzer, FormChecks, FormTrend, FormFrameSelection, PartialVisibility, AthleteTracking, DetectionRecovery, recognition and fixture tests; generated videos through Vision |
| Workout lifecycle, hands-free, privacy, saved history and comparisons | CameraState, LiveSet, SetWindow, WorkoutSessionModel, MultiExerciseSession, SessionStoreAndComparison tests; full WorkoutFlow UI suite including save/delete/recovery and comparison |
| Coach conversation and grounded model selection | Coach, EvidenceAndCue, ComparisonNarrator tests; Coach navigation, source explanation and keyboard UI checks |
| Watch delivery, messages and rhythm | WatchSync, WatchMessages, WatchCoachRules, Accessories tests; Watch app launch and waiting-state inspection. Paired live delivery still requires verification. |
| Health/Fitness and personalization | FitnessSession, FitnessWorkout, HealthPersonalization tests and AppleFitness UI checks; no synthetic Health writes |
| Feedback, localization, onboarding and demo | WorkoutFeedback, SpokenObservation, OnboardingProfile tests; onboarding tours, French screen checks, preference uniqueness regression |
| Home, Posture, badges, widgets, Siri and sharing | DashboardActivity, PostureGuide, BadgeRules, WidgetSharing, Intents, SetShareSummary tests and destination checks |
| Presentation and accessibility | Dark-only captures with the simulator set to light, largest text, Reduce Motion, clipping/contrast/hit-target audits, keyboard layouts, saved session inspection and rendered chart bars |

## Evidence and limits

Work is isolated on `finn/interface-review`, as requested after other agents began concurrent work. This branch is intended for review; it does not merge into main.

The comprehensive simulator candidate ran 582 tests: 565 passed, 16 failed and one physical-camera check was skipped. All 501 Swift unit tests passed. The failures exposed both stale UI expectations and accessibility issues; their corrected checks are rerun separately and recorded below. The original failing result is retained at `/tmp/Finn-ui-full-final.xcresult`.

Python validation passed 24 checks with one optional classifier check skipped. Sixteen recorded-video variants and the feet-hidden framing guard passed. These exercise the real Vision analysis path, including refusal/recovery behavior, without writing synthetic workouts to Health.

### Initial dark-only candidate (superseded)

Source commit `ea7259a` includes the latest main comment cleanup. A token comparison confirmed that merging that cleanup introduced no non-comment Swift changes. Other agents’ ongoing icon and backend branches remain separate.

`/tmp/Finn-ui-dark-final.xcresult` ran **22 tests: 20 passed, 2 failed**, on the reserved iPhone 18 Pro Max / iOS 27 simulator. Its system appearance was set to **light**. The supporting-page matrix checked rendered background pixels and passed for Workout, Options, Privacy, Coach, Awards, History and Posture. All six screen tours passed. Also passed: nested navigation through camera presentation, camera primer at both text sizes, largest-text controls and Coach keyboard, Reduce Motion, visible measured chart bars, unique preferences, complete privacy disclosures, camera-denial recovery, large-text workout audit, both Privacy audits, and setup/Reduce Transparency audits.

That run’s two failures were `testCaptureAndResultAccessibilityAudits` and `testComparisonAndSavedHistoryAccessibilityAudits`, both contrast audits. Failure crops show the black-on-yellow Debug DEMO INPUT banner together with the entire navigation header, and a white result sentence partially behind that header after scrolling. The audit also reports an unnamed SwiftUI node with no element bounds; it was subsequently isolated to the toolbar Done button (see the follow-up below). Actual result screenshots were inspected and are readable, but this is **not an all-green accessibility run**. These historical failures are retained. Both now pass without audit exclusions, as recorded below. The Debug banner is absent from Release. Largest-text result checks and the rendered-chart regression passed.

Failures and complete issue descriptions are retained in `/tmp/finn-dark-final-audits`. Representative crops are saved alongside the review screenshots. Earlier candidates remain in their local result bundles. The full baseline’s 501 unit tests and replay evidence remain applicable to the unchanged workout logic; this final run specifically exercises the changed interface.

### Contrast and Release follow-up — 16 October

Source `98a8f33` resolves both result audits. A temporary component-isolation run identified the previously unnamed node as the toolbar **Done** button. It now uses a measured native text label and a 44-point hit region. The synthetic-input banner has yellow text on black and its own layout row. Result guidance and earned-badge detail use the existing measured text component, preventing incorrect clipped-text bounds. The chart now retains native chart accessibility with a label and measured value for each rep.

The temporary diagnostic test and all isolation flags were removed. The offscreen-result contrast exemption was removed, and saved history now receives the full accessibility audit, including contrast.

`/tmp/Finn-contrast-toolbar-fix.xcresult`: **5/5 passed**, zero failures:

- Capture/result full audit, including after scrolling.
- Comparison and saved-history full audits.
- Largest-text setup/capture/result audits.
- Rendered measured-chart bars.
- Production launch and navigation across all tabs, Options and Privacy.

The coordinated icon session also found and verified a Release-only blank-tab bug on the physical iPhone: an empty `safeAreaInset` remained when its Debug contents were compiled out. This branch applies the same narrow fix by guarding the complete modifier. The result presentation uses a real content row instead of that inset.

`/tmp/Finn-release-navigation-final.xcresult`: **1/1 passed**, running the production launch/navigation test against an optimised Release simulator build. The `Finn-ReleaseSmoke` shared scheme contains only UI tests so it does not require Debug test hooks in the production module. CI now runs this Release check in addition to the full Debug suite, video replays and validation tests. Superseded runs are cancelled by branch concurrency.

The updated unsigned archive `/tmp/Finn-contrast-release.xcarchive` built successfully and passed `verify-archive.sh`, including exclusion of Debug/demo code and privacy/Health purpose-text checks. `ScreenTourUITests.test3SetPathWithDemoInput` also passed in `/tmp/Finn-contrast-screens.xcresult`; affected result/history captures and three screenshot references in the editable Figma export were refreshed and integrity-checked.

Passing captures are retained at `/tmp/finn-contrast-passing-screens`; the result, scrolled result and saved-history screenshots were inspected. Current CI status is available on [PR #33](https://github.com/james8464/finn/pull/33/checks). No changes were merged into main.

### Release archive

`/tmp/Finn-ui-review-release.xcarchive` built successfully from the final source using Release optimisation for iPhone, Watch and the widget extension. `docs/release/verify-archive.sh` passed: privacy manifest and Health purpose text are present, and Debug demo/validation code is excluded. The archived iPhone app reports `UIUserInterfaceStyle = Dark` and the unchanged bundle identifier `ai.mwm.build.challenge.team.08`. The archive is unsigned, so provisioning and signed HealthKit entitlements were not verified.

### Screenshots and editable design

The [design screenshots](../design/screenshots/finn) and [release candidates](../release/screenshots) now contain actual dark-only captures from the final candidate, with a 9:41 status bar. Review images include normal and largest text, Reduce Motion, keyboard, expanded privacy and saved demo results. Synthetic workouts remain explicitly labelled DEMO INPUT.

Eight screenshot blobs and their image references were replaced in `Design/Finn — Brand Theme.fig`, preserving the editable document structure. ZIP integrity and every image hash/reference were validated. The refreshed export was also copied to `~/Downloads/Finn — Brand Theme.fig`. Its cached overview thumbnail is unchanged; the editable screenshot contents are updated.

Inspected captures include [Workout](../design/screenshots/finn/06-choix-exercice-pompes.png), [Options](../design/screenshots/finn/12-options.png), [Privacy](../design/screenshots/finn/13-confidentialite.png), [Coach](../design/screenshots/finn/review/coach-dark.png), and [largest-text Coach with keyboard](../design/screenshots/finn/review/coach-largest-text-keyboard.png).

Physical iPhone installation was attempted with the existing MWM team and bundle identifiers. Xcode rejected signing because the connected iPhone is not included in the development profiles and this account cannot register devices. Real-device camera, Apple Health authorization/write, headphones and Apple Intelligence/PCC service behavior therefore still need device verification by an authorized team member. Simulator and fixture tests cannot certify those external services or App Store acceptance.

The live Figma connector is unavailable in this session; the hosted presentation was not synchronized.
