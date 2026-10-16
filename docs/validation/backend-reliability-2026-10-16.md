# Backend reliability and Coach crash investigation

16 October 2026. Branch: `finn/backend-reliability`, based on `3c8af26`.

## What changed

- **Input integrity:** reject non-finite or out-of-frame landmarks, invalid image geometry,
  malformed classifier features, hidden athletes and broken capture clocks. Decoded replay data
  goes through the same checks as camera data. Invalid points are no longer clamped to image edges.
- **Counting:** a time-bounded three-point median rejects isolated pose spikes. Tracking gaps
  abandon an unfinished movement; the shoulder fallback no longer invents a downward movement
  behind an occlusion. The deepest-frame selector uses the same filter as the counter.
- **Technique:** hip sag/pike, chest drop, torso lean and knee bend are checked throughout a rep.
  A fault requires at least three supporting readings over 0.2 seconds, with adequate observed
  duration. Depth checks use a 0.3-second window around the measured bottom. A single noisy frame
  cannot establish a fault. Reps filmed at an unsuitable observed angle are excluded individually.
  Counting from hips or shoulders alone does not produce side-view technique advice.
- **Reusability and work per update:** timestamp binary searches locate rep windows instead of
  filtering the whole capture for every rep. Checks share those windows and angle assessments.
  Live catch-up cues reuse one form review while restricting each cue to evidence from that rep
  or earlier. This removes repeated geometric analysis; the main counter still analyses its
  bounded capture buffer, so this is not a fully incremental constant-time counter.
- **Saved results:** validate session/set identities, chronology, finite measurements and cue
  references before writing or using decoded history. Invalid writes leave the good file intact;
  damaged existing history uses the existing explicit backup/recovery flow.
- **Code consistency:** British spelling for app-owned identifiers, clearer comments about
  assumptions, and shared model-request lifetime handling. Persisted keys, Apple API spellings,
  app identity and all `ai.mwm.build.challenge.team.08` bundle identifiers remain compatible.

Changed counting semantics have new rubric versions. Historical results are not silently relabelled
as new measurements. Four-language observation text describes the actual measurement window.

## Coach crash

The previous standard selector instantiated Apple's Private Cloud Compute model on iOS 27 even
though this app's entitlements do not include `com.apple.developer.private-cloud-compute`.
Device-level model availability does not authorise the app. Apple's [integration guidance][pcc]
and [managed entitlement documentation][entitlement] require that entitlement. A framework trap
cannot be handled with ordinary Swift `catch`; the normal selector now avoids this path entirely.

Coach uses the available on-device model, then recorded facts on failure. Its prompt, response and
conversation sizes are bounded. Empty history avoids inference. Leaving the screen cancels the
request, and changing/deleting its history prevents a stale reply being appended. Coach and the
comparison narrator share a generation gate: a timed-out or cancelled request continues to occupy
its slot until the underlying operation really ends. Repeated taps cannot accumulate overlapping
requests to that engine. Errors are logged without prompts or workout facts.

The Send button also has an explicit 44-point tap area, verified with the keyboard open.

The PCC path is a plausible cause of the reported phone crash, not a confirmed crash-log diagnosis. No
matching Finn report was returned from the connected phone's crash-log listing; a later request
lost its device connection. Live Apple Intelligence inference on that physical iPhone remains
unverified. The follow-up below adds genuine on-device model tests in the simulator, alongside
the deterministic fallback and injected-engine checks. The explicit
Debug-only Claude option remains separate; it is not enabled or used by these checks.

## Research and design decisions

1. Apple [Vision 2D guidance][vision2d] emphasises visible landmarks, adequate image size and
   confidence. Missing landmarks are missing evidence, rather than movement to interpolate.
2. Apple [Vision 3D guidance][vision3d] describes estimated joints and the most prominent person;
   it is not a calibrated motion-capture ground truth. The existing athlete correspondence and
   angle checks remain important. This update does not infer spinal curvature or frontal faults
   from side-view observations.
3. [Fitness-AQA][aqa] studies exercise-specific temporal representations and expert-labelled form
   assessment. Its findings motivate whole-rep temporal evidence and exercise-specific checks.
   No new learned model was trained or validated here.
4. Apple's [guided generation][guided] supports structured output. Coach's model selects known
   saved-set references; Finn renders recorded facts and validates selections. A language model
   is not used to invent counts or certify unseen technique. Apple's current framework supports
   more than text, but that alone is not evidence of reliable exercise assessment.

## Verification

- iPhone simulator: **531 tests in 63 suites passed**. The app and embedded Watch target
  compile successfully.
- **Three targeted UI flows passed:** Coach sends replies and survives tab changes; the recorded
  squat displays six reps; covered-feet footage produces a measured result. The first Coach UI
  run exposed an unregistered Send tap; an explicit rectangular hit area and plain button style
  fixed it. The recorded-set assertion now reads the combined accessible number and label. One
  intervening simulator runner aborted before starting tests; the isolated rerun passed.
- Camera/Vision replay: **15 strict fixture checks passed**, plus the mirrored diagnostic
  (six measured reps) and covered-feet framing assertion. Clear, dim, distant-but-readable,
  slower, bright, warm, low-resolution, off-centre and tilted fixtures each measured six reps.
  Standing still, hidden lower body, too-small footage, strong blur and camera movement returned
  a retake. The feet-hidden fixture counted six without side-view form measurements.
- Important limit: blur and camera movement each produced one provisional live count before the
  final refusal. The tests do not establish zero live false positives.
- The suite includes 600 seeded varied squat traces, all supported exercise paths, sustained
  faults outside the bottom, isolated glitches, high-frame-rate noise, insufficient coverage,
  wrong-angle reps, malformed history, cancellation, timeouts and unsupported model output.
- `tools/test_backend.sh`: **237 tests in 19 suites passed** on macOS 27, using shared
  production analysis/Coach sources without a simulator.
  `tools/replay/test_generated_videos.sh` exercises the real Vision path;
  replay JSON now includes form measurements and supported findings as well as rep counts.

## Accuracy claims still require real-person validation

Synthetic geometry and rendered-video regressions demonstrate specific behaviours, not human
technique accuracy. The earlier labelled-video results in [form-checks-v1.md](form-checks-v1.md)
were used to choose thresholds and are not a held-out evaluation of this update. Their original
external clips were unavailable for this run. The new time/coverage thresholds also remain
product hypotheses.

Before an accuracy release claim, evaluate participant-disjoint, independently annotated videos
covering every exercise, intended fault, camera angle, body proportion, clothing, lighting,
occlusion and pace. Report exact-count accuracy, count error, per-fault precision/recall, false
alarms on clean reps, measurement coverage/refusals and live latency separately. Retain unknown
checks as unknown, including in improvement trends. Missing a flag cannot certify good form.
Physical-device model inference, camera performance and Watch wrist-down behaviour remain
separate checks. This work does not claim perfect accuracy or complete freedom from crashes.

[vision2d]: https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images
[vision3d]: https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images
[aqa]: https://arxiv.org/abs/2202.14019
[guided]: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
[pcc]: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
[entitlement]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute

## PR #34 follow-up: Coach and variable-rate evidence

The follow-up keeps the same bundle identifiers and works on the PR branch, separately from the
active interface checkout.

- The Coach prompt now retains whole, bounded records from the newest sets, with their dates.
  Previously, cutting the first 4,000 characters could remove the newest workout entirely.
- The fixed greeting is no longer labelled as an Apple Intelligence response. It refreshes when
  history changes before the conversation starts. Actual replies retain their engine source.
- The on-device selector uses greedy guided generation. A session can prewarm when the person
  focuses the composer; each submitted turn consumes that session exactly once. This follows
  Apple's [prewarming guidance](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm%28promptprefix%3A%29).
  No measured latency improvement is claimed here.
- Coach scrolling follows the latest message identity, including after the 40-message limit;
  pending replies can be cancelled. The information button moves to the toolbar, leaving room
  for the composer at accessibility text sizes. Missing Spanish Coach explanations are translated.
- Hip-only squat counting checks ankle speed in both axes, using elapsed time and one consistently
  tracked ankle. The former per-frame horizontal threshold varied with frame rate and missed
  vertical camera motion. The fallback rubric is `squat-trunk-v3`.
- Technique summaries weight readings by observed time. A dense, brief burst cannot dominate a
  longer clear view. Bottom-position checks require temporal coverage, and sustained faults are
  compared by duration instead of sample count. Hidden athletes cannot supply anchor evidence.

### Native Apple Intelligence test

`NativeCoachIntegrationTests` is opt-in with `TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1`. It checks
availability and locale support, invokes the production on-device engine, and requires the exact
recorded answer with engine `.onDevice`; a fallback fails. A separate UI test uses a synthetic
camera recording but the real production model. Ordinary CI explicitly skips these native tests
unless enabled, because runner model assets are not guaranteed.

The first native integration run passed all four locale cases in 22.834 seconds on the iOS 27
simulator, using this Mac's model. Apple explains that simulator inference uses the host Mac's
assets and requires compatible OS/runtime versions in its
[developer forum guidance](https://developer.apple.com/forums/thread/787445).
This is real model inference, not evidence of performance or crash freedom on an iPhone.

The full unit suite at that point passed 535 Swift tests across 63 suites. The 15 strict rendered
video fixtures and the mirrored/framing checks also passed. Strong blur and camera movement can
still produce a provisional live count before the final rejection; this limitation is unchanged.

### CI and merged interface verification

The original PR #34 run (`38818094226`) failed four time-formatting tests and eighteen interface
checks. The time formatter used the host time zone even when its caller supplied a calendar in
another zone. It now applies that calendar and zone to both date and time, with an additional
regression across a day boundary. The 45 Coach/Siri tests passed with the test runner set to UTC.

The interface branch at `ce50d5b` is incorporated, preserving its contrast, camera-primer, navigation,
large-text and Release launch fixes. British-spelt wrapper arguments were reconciled with the
backend branch. Coach's composer is a normal keyboard-aware layout child; the previous bottom
inset could leave its visual and interactive positions inconsistent during keyboard transitions.

The merged build passed the native model selection test in all four languages (9.755 seconds for
the combined integration test), the full recorded-demo-set-to-native-Coach UI flow (43.342 seconds),
and the largest-text composer flow in English UK, English US, French and Spanish (83.400 seconds).
These are execution durations, not a controlled inference-performance benchmark.

The in-app privacy disclosure now matches the on-device production selector and published policy.
Graphify's local-only code graph was used to follow Coach and generation-gate dependencies; generated
graph files are not part of the app or repository changes.

The software keyboard's Send key exposed a separate multiline-field issue: SwiftUI inserted a
newline without calling `onSubmit`. An initial draft-difference workaround passed once but failed on repetition because SwiftUI can
coalesce multiple edits. It has been replaced by a native `UITextView` delegate that handles the
keyboard Send action directly, preserves pasted paragraphs, and bounds the draft length. The updated privacy disclosure UI check also passed.
The UI assertion checks the latest visible reply rather than assuming a lazy transcript retains
every off-screen accessibility row.

A final context audit found that sorting sessions by their start time could choose an older set
as “latest” when sessions overlapped. Context now orders individual sets by capture time, with a
stable identity tie-break, and preserves within-session comparison predecessors. It only builds
comparison wording for the retained (at most 32) facts. Chronological sorting remains O(n log n);
this change reduces unnecessary text construction without claiming a constant-time history scan.
User-rejected observations and their next-action advice are also excluded from Coach prompts.
Regression tests cover overlapping sessions, comparison evidence outside the retained window,
input-order independence, and rejected advice.

The platform-independent backend run at `e00a152` passed **245 tests in 19 suites**, including
chronology and rejected-observation regressions. The draft-difference test was subsequently removed
with that workaround; the native keyboard is exercised through UI tests.

Repeated keyboard tests also exposed a focus feedback loop in the first native-editor candidate
and a transcript-following bug. UIKit now owns keyboard focus; model-to-view text updates cannot
write back through the delegate. Auto-scroll is suspended only for actual user scrolling, so
keyboard resizing or a newly inserted reply cannot silently disable following. The UI regression
requires exact submitted text and the complete new reply above the composer at standard text size.

At the largest text size, a delayed SwiftUI text snapshot could still overwrite a newer native
edit. The composer now uses an explicit reset identity: UIKit owns current keystrokes, and only a
successful submission deliberately replaces its text. Large-text tests assert that every typed
character survives before sending, and retain a screenshot when a reply cannot be reached.

Keyboard-driven geometry corrections now scroll without animation. New-message transitions still
respect Reduce Motion; intermediate layout positions cannot start another animated correction.
The current standalone backend suite passed **244 tests in 19 suites**. Small-screen accessibility
fixes also use the existing native text wrapper for result and unavailable-Health explanations.
