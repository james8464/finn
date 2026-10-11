# Plumb iPhone Squat MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person can use a real iPhone camera to capture a side-view bodyweight squat set, receive an honest, evidence-linked post-set result, and compare a second set without saving video.

**Architecture:** AVFoundation owns capture and Vision converts sampled frames into small, normalized pose records. A deterministic, pure-Swift squat analyzer and cue selector produce the facts; SwiftUI manages the session flow; a local JSON repository stores only derived summaries. No network, Watch, AirPods, Foundation Models, or subscription dependency is on this path.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Vision, Swift Testing, XCTest UI testing, Xcode 27.0. No third-party packages.

**Spec:** [`planning.md`](../../../planning.md), especially sections 2–4 and 6–7. Current product state is in [`README.md`](../../../README.md).

## Global Constraints

- First calibrated exercise: **bodyweight squat from a side view**. No universal form score, diagnosis, load prescription, or claim of injury prevention.
- One cue at most per set, supported by named reps and a measured signal. Abstain when evidence is weak; a valid result may have no cue.
- Camera frames stay on device and are not recorded to a movie file in this milestone. Persist only derived set summaries; no microphone or HealthKit permission.
- Keep the current iOS 27.0 deployment target, as confirmed on 11 October 2026. Change the first shipping target to iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) until an iPad flow is designed and tested.
- Use system typography, Dynamic Type, VoiceOver labels, clear visual recording status, large start/stop controls, and reduced-motion-safe feedback.
- Use the restrained Plumb palette and typography in [`Design/README.md`](../../../Design/README.md); native controls and SF Symbols are preferred over custom dashboard chrome.
- A simulator proves flow and logic only. A physical iPhone is required to validate camera framing, pose quality, heat, and latency.

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
| `Plumb/Plumb/ContentView.swift`, `Plumb/Plumb/PlumbApp.swift` | Replace starter copy with entry point and dependency wiring |
| `Plumb/Plumb.xcodeproj/project.pbxproj` | Camera usage string and iPhone-only target family; retain iOS 27.0 |

Contract conventions: `PoseFrame.time` is seconds from capture start; joint coordinates are normalized to an upright preview (`x` rightward, `y` downward) with confidence in `0...1`. `SetAnalysis.reps` contains `RepMetric` values with one-based `number`, start/end time, normalized hip travel, and duration. `EvidenceAssessment` is `.usable(side)` or `.reject(reason)`, with `isRejected: Bool`; `AnalysisOutcome` is `.analyzed(SetAnalysis)`, `.insufficientView(reason)`, or `.failed(reason)`. `WorkoutSessionModel.phase` is a simple state enum (`ready`, `framing`, `countdown`, `capturing`, `analyzing`, `result`, `permissionDenied`, `interrupted`) and `result: WorkoutResult?` carries `.observation`, `.noMeaningfulChange`, `.insufficientView`, or `.analysisFailed`, with a case-only `kind` for tests. `Cue.repNumbers` identifies evidence; `Comparison` carries the two set IDs and metric deltas. Every result carries the rubric version; provisional thresholds are versioned and frozen before the labeled holdout test.

`SetSummary` stores set/session IDs, exercise and rubric version, side-view camera angle, start/end times, rep metrics and boundaries, cue evidence, confidence, and the person's cue response. It has no video or clip URL field in this version.

Provisional `SquatRubric.v1` starting values: required joint confidence ≥0.6 on ≥80% of sampled frames; at least four complete reps before an automated cue; a rep lasting 0.8–8 seconds; a depth-range cue only when the median of the last two valid reps is at least 15% shorter than the median of the first two. Limit a set to two minutes and 1,800 sampled pose frames. These are engineering hypotheses, not movement standards. Tune against a development set, then freeze before the holdout evaluation.

## Task 1: Deterministic squat analysis

**Files:** Create `WorkoutModels.swift`, `SquatAnalyzer.swift`; create `Plumb/PlumbTests/SquatAnalyzerTests.swift`; replace placeholder `PlumbTests.swift` only if needed.

**Interfaces:** Consumes `[PoseFrame]`; produces `AnalysisOutcome` with timestamped `RepMetric` records. No AVFoundation or Vision types enter this layer.

- [ ] Write failing Swift Testing cases `sixCompleteReps`, `incompleteFinalRep`, `irregularSpacing`, and `stationaryTrace`. A synthetic trace with six 2-second cycles must satisfy `#expect(reps.count == 6)` and `#expect(reps.map(\.number) == [1, 2, 3, 4, 5, 6])`; append a downward-only segment and assert the count remains six. Use fixture time in seconds, not frame positions.
- [ ] Run `xcodebuild -project Plumb/Plumb.xcodeproj -scheme Plumb -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:PlumbTests test`; confirm the new tests fail for missing implementation.
- [ ] Implement smoothing plus standing/down/up hysteresis in `SquatAnalyzer.analyze(_:)`. Normalize hip travel to the subject's standing hip-to-ankle distance; calculate within-set range and tempo only. Keep initial thresholds in a named `SquatRubric.v1` and label them provisional.
- [ ] Rerun the same command; tests pass. Commit this task.

## Task 2: Evidence quality and cue rules

**Files:** Create `EvidenceGate.swift`, `CueSelector.swift`; create `Plumb/PlumbTests/EvidenceAndCueTests.swift`.

**Interfaces:** `EvidenceGate.assess(_:)` decides whether the side-view trace supports analysis. `CueSelector.select(from:)` returns at most one `Cue` with rep numbers, measured contrast, plain-language observation, and one optional next action; `nil` means no supported cue.

- [ ] Write failing tests `missingRequiredJoints`, `lowConfidence`, `bystanderPresent`, `shortTrace`, `stableRange`, and `lateRangeDecrease`. Assert `#expect(gate.assess(weakTrace).isRejected)`, `#expect(selector.select(from: stableSet) == nil)`, and `#expect(selector.select(from: decreasingSet)?.repNumbers == [5, 6])`.
- [ ] Run the unit-test command from Task 1 and confirm failure.
- [ ] Implement a persistent-side choice and coverage gate. Suppress analysis if required points disappear for too much of the set or the subject scale/position changes enough that within-set range cannot be compared. Cue wording must describe the observed change, never its medical cause or an absolute depth target.
- [ ] Rerun unit tests; review the exact cue copy with a qualified trainer before automated coaching is presented as validated. Commit this task.

## Task 3: Real camera and pose stream

**Files:** Create `CameraPoseSource.swift`, `CameraPreview.swift`; modify `Plumb/Plumb.xcodeproj/project.pbxproj`; create `Plumb/PlumbTests/CameraStateTests.swift`.

**Interfaces:** `CameraPoseSource.start() async throws -> AsyncStream<PoseFrame>` checks `.video` authorization and owns `AVCaptureSession`; `stop()` ends capture and finishes the stream. The preview displays the same session. It reports denied, unavailable, and interrupted states distinctly.

- [ ] Write tests `cameraDenied`, `cameraUnavailable`, `captureInterrupted`, and `restartAfterStop` with an injected authorization/capture seam. Assert denied capture throws before session start, interruption finishes the stream, and `#expect((nextAttempt.first?.time ?? .infinity) < 0.2)` so the second attempt has a fresh time base.
- [ ] Run unit tests and confirm failure.
- [ ] Add `NSCameraUsageDescription` with a plain reason for on-device movement analysis and set `TARGETED_DEVICE_FAMILY = 1` in both app configurations, retaining iOS 27.0. Start with the front camera so the person can see framing; do not mirror the analysis coordinates. Configure `AVCaptureVideoDataOutput` on a serial queue with late-frame discard and a maximum 15 pose samples per second; run `VNDetectHumanBodyPoseRequest` and emit only normalized joints, counts, confidence, and timestamps. Handle camera orientation in the coordinate conversion. At two minutes, stop capture and finish analysis rather than growing the trace further.
- [ ] Run unit tests and a simulator build; then check a physical iPhone for preview orientation, camera interruption, and bounded memory. Commit this task.

## Task 4: One complete SwiftUI set

**Files:** Create `WorkoutSessionModel.swift`, `WorkoutViews.swift`; modify `ContentView.swift`, `PlumbApp.swift`; create `Plumb/PlumbTests/WorkoutSessionModelTests.swift` and `Plumb/PlumbUITests/WorkoutFlowUITests.swift`.

**Interfaces:** The model moves through `ready → framing → countdown → capturing → analyzing → result`, with permission, interruption, insufficient-view, and analysis-failed exits. It accepts an injected pose source so tests can feed known traces.

- [ ] Write failing model tests `startStop`, `cancelCountdown`, `backgroundStopsCapture`, `shortSetAbstains`, and `noMeaningfulChange`. Assert `#expect(model.result?.kind == .insufficientView)` after an unusable trace and `#expect(model.isRecording == false)` after interruption. Write one UI test that starts from setup, follows a scripted six-rep pose source, sees evidence-linked result, and can retake.
- [ ] Run the relevant unit and UI tests; confirm failure.
- [ ] Build setup and framing guidance, explicit recording indicator, large controls, progress/countdown, and four distinct result states. Show the observed rep numbers and a small range/tempo timeline behind the cue; offer **Try this next set**, **Not relevant**, and **Retake**. When the evidence gate rejects a set, show a concrete placement tip and do not present a confident rep count. Use a launch argument only for deterministic UI testing; label any in-app demo data as demo.
- [ ] Rerun tests, inspect light/dark mode and Dynamic Type, and verify VoiceOver order and that the Stop control remains visible. Commit this task.

## Task 5: Local history and second-set comparison

**Files:** Create `LocalSessionStore.swift`, `SetComparison.swift`; extend `WorkoutSessionModel.swift` and `WorkoutViews.swift`; create `Plumb/PlumbTests/SessionStoreAndComparisonTests.swift`.

**Interfaces:** Each `WorkoutSessionSummary` has a stable ID and one or more `SetSummary` values; comparison becomes available after the second set. `SetComparison.compare(_:_:)` compares only like exercise/rubric/angle records and returns `nil` when evidence is incompatible. The store saves derived summaries and user cue responses, never raw frames or movie paths in this milestone.

- [ ] Write failing tests `summaryRoundTrip`, `secondSetSameSession`, `incompatibleComparison`, `deleteSession`, and `corruptStoreRecovery`. Assert `#expect(loaded.first?.sets.count == 2)`, `#expect(SetComparison.compare(first, wrongAngle) == nil)`, and that the serialized record has no frame bytes or clip URL.
- [ ] Run unit tests and confirm failure.
- [ ] Implement atomic Application Support storage and a clear delete action. Show the first and second set side by side using their measured range/tempo and a cautious “changed / no clear change” statement; do not equate metric change with safer movement.
- [ ] Rerun tests and manually complete two sets on a physical iPhone. Commit this task.

## Task 6: Validation and demo gate

**Files:** Create `docs/validation/squat-v1-protocol.md` and `docs/validation/squat-v1-results.md`; update `README.md` and `planning.md` with measured status only.

**Interfaces:** A frozen `SquatRubric.v1` plus annotated set fixtures yields a reproducible report: setup success, exact-match rep count, emitted-cue coverage and expert agreement, post-set latency, device/lighting breakdown, and failure examples.

- [ ] Write the annotation sheet/protocol before tuning: consent, device/iOS, angle, distance/height, lighting, body visibility, human rep boundaries, and expert cue judgment. Separate tuning participants from the holdout participants.
- [ ] Capture at least 30 consenting squat sets, including difficult views, and have a qualified trainer or movement specialist review every emitted cue category. Mark any recording used for the demo as recorded.
- [ ] Run the full `PlumbTests` and `PlumbUITests` suites, then measure the spec's proposed gates on physical devices: setup 80% within two attempts, rep count 90% exact-match, emitted-cue agreement 80%, and result within 5 seconds. Record coverage alongside cue agreement.
- [ ] If a gate fails, suppress the affected claim or use the clearly labeled self-review fallback. Publish the measured result and remaining limits in `squat-v1-results.md`; update project status, then commit.

## Subsequent plans, after the iPhone gate

Tasks 1 and 3 can advance in parallel; Task 2 needs Task 1's models; Task 4 joins Tasks 1–3; Task 5 follows Task 4. Start Task 6's consent and annotation protocol immediately, then collect sets as soon as capture runs. For the 16 October challenge, prioritize a truthful physical-device camera-to-result path over optional integrations. The validation report decides which claims are safe to show in the demo; it is not an App Store release gate by itself.

| Order | Independent plan | Entry condition |
| --- | --- | --- |
| 1 | Spoken post-set cue through system audio, including paired AirPods | Core cue wording approved; audio remains optional |
| 2 | Apple Watch workout context and user-controlled HealthKit save | iPhone loop stable; watchOS target and paired-device testing available |
| 3 | Foundation Models phrasing of structured, validated observations | Runtime availability/fallback tested; output constrained to existing facts |
| 4 | Push-up rubric and then carefully gated live cues | Separate labeled data, expert review, latency and distraction tests |
| 5 | Saved clips, sharing, subscriptions | Explicit retention/deletion design and user value validated |

## Platform references

- [Apple camera authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [Apple video output frame delivery and dropping](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/setsamplebufferdelegate%28_%3Aqueue%3A%29)
- [Apple Vision 2D body pose](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest)
- [Apple Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
