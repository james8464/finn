# Plumb iPhone Squat MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person can use a real iPhone camera to capture a side-view bodyweight squat set, receive an honest, evidence-linked post-set result, and compare a second set without saving video.

**Architecture:** AVFoundation owns capture and Vision converts sampled frames into small, normalized pose records. A deterministic, pure-Swift squat analyzer and cue selector produce the facts; SwiftUI manages the session flow; a local JSON repository stores only derived summaries. No network, Watch, AirPods, Foundation Models, or subscription dependency is on this path.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Vision, Swift Testing, XCTest UI testing, Xcode 27.0. No third-party packages.

**Spec:** [`planning.md`](../../../planning.md), especially sections 2–4 and 6–7. Current product state is in [`README.md`](../../../README.md).

## Product objective and challenge strategy

**User objective:** A solo lifter can understand one camera-visible change in their own squat set, try a specific adjustment, and see whether that measured pattern changed in a second set. Success is the person's comprehension and repeat use, not a universal “form score.”

**Business objective:** Prove that this loop is more useful than recording and manually reviewing a clip. Test setup friction, cue relevance, willingness to repeat, and willingness to pay for deeper history with the interviews in the product plan. Do not build subscriptions before this value is demonstrated.

**Challenge objective:** The [Build Challenge brief](https://luma.com/cmdf-bc2) asks for a clear use case, working core experience, path to monetization, and a build submitted through App Store Connect. It names Apple Intelligence/Foundation Models, on-device AI, Liquid Glass, App Intents, and StoreKit as technologies teams *can* explore. It publishes no scoring rubric. Our strategy is an inference from that brief: make a reliable, memorable **scan → evidence → one cue → try again → compare** demo, show a credible business test, and use Apple technology only where it improves that loop.

**Apple-native moment:** Vision extracts 2D pose points on device; SwiftUI uses system controls and restrained Liquid Glass for navigation over the camera preview; Foundation Models can explain a validated set-to-set comparison in plain language on eligible devices. The deterministic fallback produces the same facts when the model is unavailable. This demonstrates on-device intelligence and privacy without asking a language model to judge biomechanics or invent measurements. Apple recommends model availability checks and guided generation, while its HIG asks apps to disclose AI use and limits. See [Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models), [guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation), [Generative AI HIG](https://developer.apple.com/design/human-interface-guidelines/generative-ai), and [materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials).

**Release distinction:** By 16 October, target an App Store Connect build and complete listing draft; actual App Review approval and public availability are outside the team's control. Remove starter/placeholder text from the submitted binary. Apple requires complete metadata, a selected build, truthful screenshots, and app privacy disclosures; a fitness app must avoid unsupported accuracy or physical-safety claims. See [submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app), [app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

**What should make the pitch memorable:** In three minutes, show a real first set, point to exactly which reps caused one observation, and show a second set with a measured change or an honest “no clear change.” State what Vision measured, what Foundation Models merely worded (if available), and what stays on the device. Pair that with two or three user interview findings and a simple willingness-to-pay test; the event explicitly expects business teammates to test assumptions and prepare the launch. Have a labeled recorded run ready in case venue lighting disrupts the live camera. Do not spend demo time on a speculative Watch screen or a decorative AI chat.

**Decision gates:** First, the six-rep scripted trace and physical camera preview must work. Next, enough consenting real sets and expert review must support any automated cue the app displays. Only then add generated recap wording. If the rubric misses the validation threshold, submit a narrower app that presents measured reps and transparent “view too weak” outcomes; do not claim accurate technique diagnosis. Separately, verify Apple Developer Program and App Store Connect access now: the team reported that access is not yet confirmed on 11 October.

| Approach considered | Decision for this challenge |
| --- | --- |
| Ask a multimodal foundation model to judge each video frame | Defer. It could produce a persuasive but unmeasured form claim, and frame-by-frame inference adds latency. [Apple's Foundation Models guidance](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) says its on-device language model is not the right tool for basic math; Vision joints plus a deterministic rubric are easier to audit. |
| Vision 3D pose and absolute joint angles | Evaluate later. [Vision 3D](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images) can estimate 3D joints, but depth and camera view vary; a side-view within-person comparison is the smaller claim to validate first. |
| Watch heart rate, AirPods speech, or an App Intent in the first demo | Defer until the iPhone loop works. These extend context and convenience but cannot establish whether a squat rep was measured correctly. |
| Vision 2D + deterministic evidence + optional Foundation Models recap | Build. It gives the demo a visible Apple-native measurement and a useful AI explanation, while preserving an offline fallback and a clear line between fact and wording. |

## Global Constraints

- First calibrated exercise: **bodyweight squat from a side view**. No universal form score, diagnosis, load prescription, or claim of injury prevention.
- One cue at most per set, supported by named reps and a measured signal. Abstain when evidence is weak; a valid result may have no cue.
- Camera frames stay on device and are not recorded to a movie file in this milestone. Persist only derived set summaries; no microphone or HealthKit permission. A failed analysis shows a retake path in-app; a separate recorded demo is clearly identified as such.
- Keep the current iOS 27.0 deployment target, as confirmed on 11 October 2026. Change the first shipping target to iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) until an iPad flow is designed and tested.
- Use system typography, Dynamic Type, VoiceOver labels, clear visual recording status, large start/stop controls, and reduced-motion-safe feedback.
- Use the restrained Plumb palette and typography in [`Design/README.md`](../../../Design/README.md); native controls and SF Symbols are preferred over custom dashboard chrome.
- A simulator proves flow and logic only. A physical iPhone is required to validate camera framing, pose quality, heat, and latency.
- A Foundation Models feature may describe or simplify validated observations only. It must check availability, use a typed output, validate references against local evidence, disclose AI wording, and fall back to reviewed copy.

## Review Focus

1. **Camera denied or unavailable:** the user sees recovery instructions and never sees a false recording state. Test in Task 3.
2. **Partial body, bystander, or lost joints:** the app asks for a retake and emits no precise rep count or cue. Test in Tasks 2 and 4.
3. **Interrupted or very short set:** capture stops, no stale frames enter the next set, and the result explains the missing evidence. Test in Tasks 3 and 4.
4. **Slow or dropped frames:** processing stays bounded and rep timing uses timestamps rather than frame indexes. Test in Tasks 1 and 3.
5. **Repeated set or deleted history:** comparison uses the same exercise session and deletes its summaries cleanly. Test in Task 5.

---

## File map and contracts

The Xcode project uses synchronized source groups, so new Swift files under `Plumb/Plumb` and test files under `Plumb/PlumbTests` should be included automatically. Confirm this in the first build.

| File | Responsibility |
| --- | --- |
| `Plumb/Plumb/Workout/WorkoutModels.swift` | `BodyJoint`, `JointPoint`, `PoseFrame`, `RepMetric`, `SetAnalysis`, `Cue`, `SetSummary`, `WorkoutSessionSummary`, and outcome enums; all persisted values `Codable` |
| `Plumb/Plumb/Workout/SquatAnalyzer.swift` | `SquatAnalyzer.analyze(_ frames: [PoseFrame]) -> AnalysisOutcome`; deterministic rep phases and metrics |
| `Plumb/Plumb/Workout/EvidenceGate.swift` | `EvidenceGate.assess(_ frames: [PoseFrame]) -> EvidenceAssessment`; framing and confidence rules |
| `Plumb/Plumb/Workout/CueSelector.swift` | `CueSelector.select(from: SetAnalysis) -> Cue?`; reviewed, deterministic copy and evidence |
| `Plumb/Plumb/Workout/SetComparison.swift` | `SetComparison.compare(_ first: SetAnalysis, _ second: SetAnalysis) -> Comparison?` |
| `Plumb/Plumb/Capture/CameraPoseSource.swift` | Camera authorization/session, bounded frame sampling, Vision 2D pose conversion; `start() async throws -> AsyncStream<PoseFrame>` and `stop()` |
| `Plumb/Plumb/Capture/CameraPreview.swift` | SwiftUI wrapper around the capture preview layer |
| `Plumb/Plumb/Workout/WorkoutSessionModel.swift` | `@MainActor` session state, countdown, frame collection, cancellation, outcome routing |
| `Plumb/Plumb/Workout/WorkoutViews.swift` | Setup, framing, capture, result, comparison, and failure views |
| `Plumb/Plumb/Workout/LocalSessionStore.swift` | `load() throws -> [WorkoutSessionSummary]`, `save(_:) throws`, `delete(id:) throws`; atomic local JSON |
| `Plumb/Plumb/Workout/ComparisonNarrator.swift` | deterministic recap plus optional Foundation Models recap from structured `Comparison` facts |
| `Plumb/Plumb/ContentView.swift`, `Plumb/Plumb/PlumbApp.swift` | Replace starter copy with entry point and dependency wiring |
| `Plumb/Plumb.xcodeproj/project.pbxproj` | Camera usage string and iPhone-only target family; retain iOS 27.0 |

Contract conventions: `PoseFrame.time` is seconds from capture start; joint coordinates are normalized to an upright preview (`x` rightward, `y` downward) with confidence in `0...1`. `SetAnalysis.reps` contains `RepMetric` values with one-based `number`, start/end time, normalized hip travel, and duration. `EvidenceAssessment` is `.usable(side)` or `.reject(reason)`, with `isRejected: Bool`; `AnalysisOutcome` is `.analyzed(SetAnalysis)`, `.insufficientView(reason)`, or `.failed(reason)`. `WorkoutSessionModel.phase` is a simple state enum (`ready`, `framing`, `countdown`, `capturing`, `analyzing`, `result`, `permissionDenied`, `interrupted`) and `result: WorkoutResult?` carries `.observation`, `.noMeaningfulChange`, `.insufficientView`, or `.analysisFailed`, with a case-only `kind` for tests. `Cue.repNumbers` identifies evidence; `Comparison` carries the two set IDs and metric deltas. Every result carries the rubric version; provisional thresholds are versioned and frozen before the labeled holdout test.

`SetSummary` stores set/session IDs, exercise and rubric version, side-view camera angle, start/end times, rep metrics and boundaries, cue evidence, confidence, and the person's cue response. It has no video or clip URL field in this version.

Provisional `SquatRubric.v1` starting values: required joint confidence ≥0.6 on ≥80% of sampled frames; at least four complete reps before an automated cue; a rep lasting 0.8–8 seconds; a depth-range cue only when the median of the last two valid reps is at least 15% shorter than the median of the first two. Limit a set to two minutes and 1,800 sampled pose frames. These are engineering hypotheses, not movement standards. Tune against a development set, then freeze before the holdout evaluation.

## Task 1: Deterministic squat analysis

**Files:** Create `WorkoutModels.swift`, `SquatAnalyzer.swift`; create `Plumb/PlumbTests/SquatAnalyzerTests.swift`; replace placeholder `PlumbTests.swift` only if needed.

**Interfaces:** Consumes `[PoseFrame]`; produces `AnalysisOutcome` with timestamped `RepMetric` records. No AVFoundation or Vision types enter this layer.

- [x] Write failing Swift Testing cases for six complete reps, an incomplete final rep, dropped frames, stationary motion, and an empty trace. The six-cycle fixture asserts numbered reps and bounded duration/range using seconds rather than frame indexes.
- [x] Run the new tests and observe compilation fail because `PoseFrame` and the analyzer do not exist yet.
- [x] Implement smoothing plus standing/down/up hysteresis in `SquatAnalyzer.analyze(_:)`. Normalize hip travel to the subject's standing hip-to-ankle distance; calculate within-set range and tempo only. Keep initial thresholds in `SquatRubric` and label them provisional.
- [x] Rerun the new tests and full scheme: 8 tests pass, 0 fail on iPhone 18 Pro simulator (iOS 27.0). Commit this task.

## Task 2: Evidence quality and cue rules

**Files:** Create `EvidenceGate.swift`, `CueSelector.swift`; create `Plumb/PlumbTests/EvidenceAndCueTests.swift`.

**Interfaces:** `EvidenceGate.assess(_:)` decides whether the side-view trace supports analysis. `CueSelector.select(from:)` returns at most one `Cue` with rep numbers, measured contrast, plain-language observation, and one optional next action; `nil` means no supported cue.

- [x] Write failing tests for missing required joints, low confidence, bystanders, short traces, unstable framing, stable range, and later shorter range. Add a regression test that the analyzer abstains when the gate rejects a view.
- [x] Run the tests and observe the missing gate/selector failure, then the analyzer-abstention regression failure.
- [x] Implement one persistent-side choice, ≥80% required-joint coverage, bystander and ankle-drift checks, and one conservative range-change cue. The analyzer consumes the gate's side decision.
- [x] Rerun the full scheme: 17 tests pass, 0 fail on iPhone 18 Pro simulator (iOS 27.0). The exact cue copy still requires qualified trainer review before any public accuracy claim; commit this task.

## Task 3: Real camera and pose stream

**Files:** Create `CameraPoseSource.swift`, `CameraPreview.swift`; modify `Plumb/Plumb.xcodeproj/project.pbxproj`; create `Plumb/PlumbTests/CameraStateTests.swift`.

**Interfaces:** `CameraPoseSource.start() async throws -> AsyncStream<PoseFrame>` checks `.video` authorization and owns `AVCaptureSession`; `stop()` ends capture and finishes the stream. The preview displays the same session. It reports denied, unavailable, and interrupted states distinctly.

- [x] Write tests `cameraDenied`, `cameraUnavailable`, `captureInterrupted`, and `restartAfterStop` with an injected authorization/capture seam. The second attempt starts at time zero; a fifth test checks the two-minute cap.
- [x] Run unit tests and confirm the missing capture protocol fails compilation before implementation.
- [x] Add `NSCameraUsageDescription` with a plain reason for on-device movement analysis and set `TARGETED_DEVICE_FAMILY = 1` in both app configurations, retaining iOS 27.0. Use the front camera, unmirrored analysis coordinates, serial video output with late-frame discard, at most 15 Vision samples per second, and only normalized pose records. Capture stops at two minutes. Portrait rotation is configured but still requires physical-device confirmation.
- [x] Reset the two-minute timer when the set begins, so time spent positioning the camera in preview does not consume the recording limit. The focused camera tests and full 50-test iOS 27 simulator suite pass.
- [ ] Run unit tests and a simulator build; then check a physical iPhone for preview orientation, camera interruption, and bounded memory. The full iOS 27 simulator suite passed (22 tests, 0 failures) on 11 October; physical iPhone 16 Pro Max was listed as unavailable to Xcode, so the device check remains open.

## Task 4: One complete SwiftUI set

**Files:** Create `WorkoutSessionModel.swift`, `WorkoutViews.swift`; modify `ContentView.swift`, `PlumbApp.swift`; create `Plumb/PlumbTests/WorkoutSessionModelTests.swift` and `Plumb/PlumbUITests/WorkoutFlowUITests.swift`.

**Interfaces:** The model moves through `ready → framing → countdown → capturing → analyzing → result`, with permission, interruption, insufficient-view, and analysis-failed exits. It accepts an injected pose source so tests can feed known traces.

- [x] Write failing model tests for start/stop, countdown cancellation, background exit, short sets, stable sets, interrupted capture, denied camera, and duration limit. The UI test uses a labeled six-rep demo source, checks the evidence-linked cue, and starts another set.
- [x] Run the model tests before implementation and confirm the missing model fails compilation; run the UI test against the implemented flow.
- [x] Build setup and framing guidance, explicit recording indicator, large controls, countdown, and measured/insufficient/interrupted/error results. Show rep numbers and compact relative-range and duration evidence. Offer **Try another set**, **Not relevant**, and a clear retake path. Use native SwiftUI controls and label the simulator-only demo input.
- [x] Clarify that one to three measured reps are too few for a pattern observation; keep other no-cue wording neutral. A dismissed cue now acknowledges the person's feedback instead of claiming no pattern. The new UI regression and full 52-test iOS 27 simulator suite pass.
- [ ] Rerun the full simulator suite, inspect light/dark mode and Dynamic Type, and verify VoiceOver order and that the Stop control remains visible. The full iOS 27 simulator suite passed 34 tests, including a dark-mode, large-text Stop control UI check, on 11 October. Physical-device layout, capture, and VoiceOver inspection remain open.

## Task 5: Local history and second-set comparison

**Files:** Create `LocalSessionStore.swift`, `SetComparison.swift`; extend `WorkoutSessionModel.swift` and `WorkoutViews.swift`; create `Plumb/PlumbTests/SessionStoreAndComparisonTests.swift`.

**Interfaces:** Each `WorkoutSessionSummary` has a stable ID and one or more `SetSummary` values; comparison becomes available after the second set. `SetComparison.compare(_:_:)` compares only like exercise/rubric/angle records and returns `nil` when evidence is incompatible. The store saves derived summaries and user cue responses, never raw frames or movie paths in this milestone.

- [x] Write failing tests for summary round-trip, second-set comparison, incompatible view/rubric/session, delete, and corrupt-store recovery. Assert two sets persist and serialized records contain no frames or clip URL.
- [x] Run unit tests and confirm the missing summary model fails compilation before implementation.
- [x] Implement atomic Application Support storage and a confirmed delete action. Show the first and second set side by side using measured range/tempo and a cautious “changed / no clear change” statement. Keep a damaged file as a backup only after an explicit recovery action.
- [ ] Rerun the full simulator suite and manually complete two sets on a physical iPhone. The full iOS 27 simulator suite passed 41 tests, including the two-set UI flow, on 11 October; physical iPhone remains unavailable to Xcode.

## Task 6: Grounded Foundation Models recap

**Files:** Create `ComparisonNarrator.swift`; extend `WorkoutViews.swift`; create `Plumb/PlumbTests/ComparisonNarratorTests.swift`.

**Interfaces:** `ComparisonNarrator.recap(for: Comparison) async -> Recap` returns a short, typed recap plus `.appleIntelligence` or `.template` provenance. The model sees only the two set summaries, accepted metric delta, cue category, and evidence rep numbers. It never sees pixels, raw pose frames, or Health data.

- [x] Write failing tests for unavailable model, invalid rep reference, unsupported claim, timeout, and valid generated wording. The recap always carries the same deterministic comparison facts.
- [ ] Run unit tests and confirm failure. The missing narrator failed compilation, then five focused tests passed. A real Apple Intelligence-eligible iPhone is still needed to verify availability and actual output.
- [x] Implement a small `@Generable` response with one plain-language explanation and an evidence-rep list. Validate direction, references, length, numeric and medical/safety terms; fall back to reviewed copy on unavailability, error, or timeout. Label generated wording only when used; measured facts stay visible separately.
- [x] Make the three-second fallback independent of model-task cancellation. A regression test with a generator that ignores cancellation failed at 358 ms for a 20 ms limit, then passed with the new race; the full iOS 27 simulator suite passed 51 tests.
- [ ] Review real generated outputs against a fixed prompt set, including poor tracking and no-clear-change cases. Eligible-device output review remains open. Do not present simulated fallback as a successful model run.

## Task 7: Validation and demo gate

**Files:** Create `docs/validation/squat-v1-protocol.md`, `docs/validation/squat-v1-template.csv`, `docs/validation/score_squat_v1.py`, and `docs/validation/squat-v1-results.md`; update `README.md` and `planning.md` with measured status only.

**Interfaces:** A frozen `SquatRubric.v1` plus annotated set fixtures yields a reproducible report: setup success, exact-match rep count, emitted-cue coverage and expert agreement, post-set latency, device/lighting breakdown, and failure examples.

- [x] Write the annotation protocol before tuning: consent, device/iOS, angle, distance/height, lighting, body visibility, human rep boundaries, and expert cue judgment. Keep participants separate between tuning and holdout.
- [x] Add a blank collection template and reproducible holdout scorer. It rejects split leaks and mixed commits, shows denominator and breakdowns, and cannot pass incomplete or underpowered gates. No participant data has been entered.
- [ ] Capture at least 30 consenting squat sets, including difficult views, and have a qualified trainer or movement specialist review every emitted cue category. Mark any recording used for the demo as recorded.
- [ ] Run the full `PlumbTests` and `PlumbUITests` suites, then measure the spec's proposed gates on physical devices: setup 80% within two attempts, rep count 90% exact-match, emitted-cue agreement 80%, and result within 5 seconds. Record coverage alongside cue agreement.
- [ ] If a gate fails, suppress the affected claim and keep the honest retake path; any *presentation* fallback must be explicitly introduced as a recorded test set. Publish the measured result and remaining limits in `squat-v1-results.md`; update project status, then commit.

## Task 8: App Store Connect submission track

**Files:** Create `docs/release/app-store-submission.md`, `docs/release/privacy-policy.md`, and final listing copy; update `README.md` with actual build/submission status.

**Interfaces:** A release candidate has a stable bundle ID and version/build number, iPhone-only screenshots of real implemented screens, support and privacy URLs, app privacy answers, review notes explaining camera-only analysis and any optional AI wording, and an archived/uploaded build. Account access and signing are external dependencies.

- [ ] Confirm Apple Developer Program membership, App Store Connect role, signing team, bundle ID ownership, and a physical iOS 27 test iPhone early. Xcode team ID is configured, but membership/distribution rights are unconfirmed; James indicated he can purchase the membership. Physical iPhone 16 Pro Max is listed as unavailable to Xcode.
- [ ] Draft truthful listing copy and capture screenshots only from implemented screens. Listing, support, privacy, and App Review note drafts now exist in `docs/release`; a normal-app setup screenshot has been captured from an iOS 27 iPhone 18 Pro Max simulator. Result/comparison screenshots, public HTTPS URLs, publisher/contact fields, and final App Privacy answers remain open.
- [ ] Run a Release build and physical-device smoke pass: first launch, permission denied/recovered, set capture, retake, comparison, delete, no-network fallback, and background interruption. An unsigned iPhone Release build and archive succeed, the archive contains expected app metadata/icon assets without team-only documents, and 52 simulator tests pass; physical-device smoke pass remains open.
- [ ] Archive, upload, and select the build in App Store Connect; complete metadata and review notes. Record the actual status: uploaded, ready for review, submitted, or approved. Do not describe an upload as App Review approval. Submission is a team/account action and may require the account holder's credentials.

## Subsequent plans, after the iPhone gate

Tasks 1 and 3 can advance in parallel; Task 2 needs Task 1's models; Task 4 joins Tasks 1–3; Task 5 follows Task 4. Start Task 7's consent and annotation protocol and Task 8's account/metadata checks immediately, then collect sets as soon as capture runs. Task 6 follows Task 5 only if the physical-device core loop is stable. For the 16 October challenge, prioritize a truthful camera-to-result build and submission readiness. A validation report constrains which claims appear in the app and demo; uploading a build does not establish that its coaching accuracy is validated.

| Order | Independent plan | Entry condition |
| --- | --- | --- |
| 1 | Spoken post-set cue through system audio, including paired AirPods | Core cue wording approved; audio remains optional |
| 2 | Apple Watch workout context and user-controlled HealthKit save | iPhone loop stable; watchOS target and paired-device testing available |
| 3 | Push-up rubric and then carefully gated live cues | Separate labeled data, expert review, latency and distraction tests |
| 4 | Saved clips, sharing, subscriptions | Explicit retention/deletion design and user value validated |

## Platform references

- [Apple camera authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [Apple video output frame delivery and dropping](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/setsamplebufferdelegate%28_%3Aqueue%3A%29)
- [Apple Vision 2D body pose](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest)
- [Apple Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
