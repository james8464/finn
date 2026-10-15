# Finn: integrated app and interface review

15 October 2026. Continues the [branch consolidation](branch-cleanup-2026-10-15.md). Bundle identifiers, app group and saved-data compatibility remain unchanged.

## Changes found through testing and visual review

- Removed duplicate Language and Workout feedback sections left by integration. Removed the duplicate stage observer that played set-start and set-finish feedback twice.
- Rebuilt Options as a native grouped Form, retaining every preference, Health action, language selection, welcome replay and Debug coach control.
- Rebuilt Privacy around three short facts and expandable complete disclosures. Added explicit Apple Intelligence / Private Cloud Compute handling for Coach questions and saved summaries.
- Supporting pages now follow system light/dark appearance, semantic surfaces and native text styles. Home retains the approved charcoal/pink design. Supporting navigation uses compact visible titles.
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
| Presentation and accessibility | Light/dark captures, largest text, Reduce Motion, clipping/contrast/hit-target audits, keyboard layouts, saved session inspection and rendered chart bars |

## Evidence and limits

Work is isolated on `finn/interface-review`, as requested after other agents began concurrent work. This branch is intended for review; it does not merge into main.

The comprehensive simulator candidate ran 582 tests: 565 passed, 16 failed and one physical-camera check was skipped. All 501 Swift unit tests passed. The failures exposed both stale UI expectations and accessibility issues; their corrected checks are rerun separately and recorded below. The original failing result is retained at `/tmp/Finn-ui-full-final.xcresult`.

Python validation passed 24 checks with one optional classifier check skipped. Sixteen recorded-video variants and the feet-hidden framing guard passed. These exercise the real Vision analysis path, including refusal/recovery behavior, without writing synthetic workouts to Health.

Earlier failing candidates remain in local result bundles. Final targeted checks and screenshot provenance follow after verification.

Physical iPhone installation was attempted with the existing MWM team and bundle identifiers. Xcode rejected signing because the connected iPhone is not included in the development profiles and this account cannot register devices. Real-device camera, Apple Health authorization/write, headphones and Apple Intelligence/PCC service behavior therefore still need device verification by an authorized team member. Simulator and fixture tests cannot certify those external services or App Store acceptance.

The editable local Figma export can be refreshed with actual simulator images. The live Figma connector is unavailable in this session, so this review does not claim that a hosted presentation was synchronized.
