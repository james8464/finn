# Plumb — product and build plan

**Working plan, updated 12 October 2026.** Plumb is an iPhone-first strength-training companion in development. The app now includes a squat setup/capture/result flow, a tested rep analyzer and evidence gate, a provisional cue selector, local derived-summary history with second-set comparison, and an optional guarded Foundation Models wording layer. These pass simulator tests; real-camera orientation, generated wording, and coaching quality still require physical-device and expert validation. Watch integration and subscriptions have not been implemented. This document separates the intended product from the hackathon prototype and the longer-term product.

The first-build execution plan is [`docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`](docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md). It scopes the first complete iPhone squat loop and its validation gate; later integrations remain in this broader product plan.

## 1. Product thesis

**One line:** Plumb uses an iPhone camera to observe an exercise set and returns one clear, evidence-linked technique cue that the person can try on the next set.

**Promise:** Better form, one set at a time. The goal is useful feedback during solo training without a specialist camera or a constant human coach. Plumb does not promise perfect technique, injury prevention, medical assessment, or a replacement for a qualified trainer.

**First audience:** self-directed people doing basic strength exercises at home or in a gym. They know the exercise they intend to do but cannot easily see their own movement. Beginners need simple setup and respectful language; more experienced users want objective comparisons over time.

**Later audience:** trainers who want a client's annotated set and the ability to add human feedback. Trainer workflows, remote sharing, and team accounts are outside the first build.

**Core insight:** a generic exercise video tells a person what form should look like; Plumb shows what their own last set looked like and suggests a single next action. The value is the loop: **capture → observe → understand → try again → compare**.

### Design principles

1. **Evidence before interpretation.** A cue must link to a visible rep, measurement, or clip segment. If tracking is weak, say so and ask for a better camera angle.
2. **One useful cue.** Prioritize one actionable change per set, not a stream of criticism.
3. **Personal progression.** Compare repeatable movement patterns with the person's own earlier sets; avoid a universal “perfect form” score.
4. **Private by default.** Process video on device where practical; do not retain raw footage unless the person explicitly saves it.
5. **Works without accessories.** iPhone camera and an on-device rules fallback form the base experience. Watch, AirPods, and Foundation Models are optional enhancements.
6. **Respect physical limits.** Do not diagnose pain or prescribe load. Encourage stopping if an exercise causes pain and seeking qualified advice when appropriate.
7. **Quiet, native presentation.** One primary action per stage, plain evidence, system typography and controls, and no decorative AI interface. See the [iPhone experience review](docs/design/iphone-experience-review.md) for Apple HIG and award-winning app references.

## 2. The experience

### Primary journey

1. Choose an exercise and read a short setup card: phone on a stable surface, side view, entire body and equipment in frame, enough light, clear floor.
2. Grant camera access when starting capture. Plumb shows whether hip, knee, and ankle landmarks stay visible before the set; a side view is still guided by instructions rather than automatically verified. It never starts analysis silently.
3. Tap or use a short countdown to start. The first build analyses a live frame stream on the iPhone without saving a video. Optional clip saving is a later feature requiring a separate, explicit choice.
4. After the set, Plumb displays measured rep count, one prioritized observation, and supporting rep details. A richer timeline, opt-in clip, or temporary pose overlay may follow once its usefulness, privacy, and accuracy have been tested.
5. The person chooses **Try this next set**, **Not relevant**, or **Retake**. A follow-up set shows whether the observed pattern changed.
6. Optional Apple Watch records workout context such as elapsed time and heart rate. Optional spoken cues play through the current audio output, including paired AirPods.

### Example: bodyweight squat

A side-view capture detects six reps. The last two show a shorter observed depth range than the first four. Plumb says: “Your last two reps were shallower than your first four. Try a pace you can keep consistent.” The result identifies reps 5–6 and can show the measured range. It does **not** claim the user's squat is unsafe, diagnose mobility, or issue a universal depth target. If the feet or hips are obscured, it says “I couldn't assess depth reliably; move the phone farther back.”

### What each device contributes

| Device | Intended role | Dependency |
| --- | --- | --- |
| iPhone | Camera capture, pose estimation, set review, history | Required |
| Apple Watch | Optional workout session, heart-rate/elapsed-time context, discreet start/stop or cue haptic | Separate watchOS target and HealthKit permission; not required for form analysis |
| AirPods | Optional spoken cue through normal system audio routing | No AirPods-only API or pairing requirement |
| Apple Intelligence-capable device | Optional Foundation Models wording of structured observations | Availability check and deterministic text fallback |

The Watch's heart rate describes effort context; it cannot prove whether a rep has good form. A later watchOS prototype could use timestamped accelerometer motion to test whether rep boundaries and tempo improve when camera evidence is weak. That requires synchronization, paired-device tests, and a measured advantage over iPhone-only analysis before it becomes a product claim. AirPods carry a cue; they do not measure pose. This distinction must remain clear in product copy.

## 3. Scope and priorities

### Prototype: one complete evidence loop

- Branded iPhone app with camera permission, setup guidance, framing feedback, and a real capture session.
- **Bodyweight squat, side view** as the first calibrated exercise. Count reps and calculate a limited set of observable, testable signals: camera-relative hip-range consistency, rep duration, and tracking confidence. A required setup instruction is not proof of the actual viewpoint; validation must count false measured outcomes from unsuitable front and three-quarter views.
- A post-set summary with one evidence-linked cue, uncertainty language, and a second-set comparison.
- On-device storage of exercise name, date, rep count, derived metrics, selected cue, and user response. Raw video is discarded by default. Saved summaries and recovered-history backups request [iOS complete file protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files), so the app accesses them while the device is unlocked; locked-device behavior still needs a physical-iPhone check.
- Optional, user-initiated sharing of a measured set's text summary through the iOS Share Sheet. It excludes dismissed observations and never includes video or camera frames.
- A deterministic coaching template that works without Foundation Models or network access.
- Clear demo labels if using a seeded sample; a recorded example must never be presented as live tracking.

### Next if the prototype is reliable

- Push-up from a side view, with a separately validated rubric such as body-line consistency and tempo.
- Spoken post-set cue and audio-control options; output may route to AirPods.
- Optional Apple Watch companion and a real HealthKit workout session with user-controlled saving.
- Foundation Models to turn **structured, validated** observations into concise, supportive language. The model cannot invent a new biomechanical finding or make a medical claim.
- Saved clips, explicit retention controls, and side-by-side comparison.

### Later product

- More movements and camera angles only after expert review and device testing.
- Carefully gated live cues when pose confidence, latency, and cue usefulness meet thresholds. One short cue at most per relevant event, with a quiet mode.
- Trainer review, optional shared clips, tailored programs, and a coach account.
- Progress trends built around consistency and user goals rather than a universal form score.
- Optional cross-device history or trainer sharing with a real account and clear deletion controls. Offer Sign in with Apple only when one of these benefits exists, after someone has tried a set; never require an account for local capture. Current local history has no account or sync service.

**Account decision:** If the next feature is private history across a person's own Apple devices, evaluate [CloudKit private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase) sync first; it uses the person's iCloud account without creating a separate Plumb login. If trainer sharing or web access needs a Plumb account, add [Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple/) through the system control after that workflow exists. Sync only derived summaries unless the person explicitly chooses to share a clip. Design conflict resolution, account deletion, and updated privacy disclosures before enabling either path. The current prototype keeps every set usable offline without sign-in.

### Explicit exclusions for the first build

No automatic exercise recognition across the whole gym, load prescription, injury prediction, medical advice, remote video upload, multi-person analysis, social feed, exercise leaderboard, or promise that every phone/angle can judge every movement.

### Cut order when time is short

Cut Watch integration, then speech, then a second exercise. Keep real iPhone capture, a confidence-aware observation, and an honest post-set result. A small Foundation Models comparison recap is an optional challenge enhancement only after the core loop is stable; it must have an on-device availability check and reviewed fallback. If pose analysis itself fails, show an honest retake path in the app and use a clearly labeled recorded test set in the presentation rather than fabricated AI feedback.

## 4. Technical plan

### Stack and boundaries

- **SwiftUI** for the iPhone experience; system text styles, Dynamic Type, VoiceOver labels, Dark Mode, and large workout controls.
- **AVFoundation** for camera frames through `AVCaptureVideoDataOutput`. Discard late frames rather than building an unbounded processing queue.
- **Vision** body-pose observations. Begin with timestamped 2D points and per-joint confidence from a live frame stream, not isolated still photos. Avoid universal joint-angle cutoffs: a 2D projection changes with camera viewpoint. [Apple's 3D body-pose API](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images) is a later comparison candidate; it can use depth metadata when available but returns the most prominent person and does not by itself establish accuracy or bystander safety.
- A **deterministic exercise engine** converts a time series of pose points into rep phases and observed metrics. It owns every factual coaching claim.
- **Foundation Models**, if available, only summarizes a small structured observation and chooses wording from allowed cue categories. Check model availability at runtime; fallback to reviewed templates. Do not send raw video to a language model for the MVP.
- **SwiftData or a small local store** for workout summaries and preferences. Raw clips are opt-in and deletable.
- **HealthKit/watchOS**, later, for authorized workout and heart-rate context. Watch workout mirroring requires a separate watch app and physical-device testing.
- **AVSpeechSynthesizer** for optional spoken output. Use the system audio route; respect silent/voice preferences and avoid competing with a person's music.

### Analysis pipeline

```text
Camera frame
  → Vision pose points + confidence
  → orientation/framing/occlusion gate
  → smoothed joint trajectories
  → exercise-specific rep state machine
  → derived metrics + evidence timestamps
  → ranked, validated observation
  → template or Foundation Models wording
  → post-set cue + user response
```

The fuller observation contract should include exercise, assessed viewpoint, involved joints, confidence, metric, threshold version, and rep/time range. The current prototype stores a smaller derived summary and does not claim to know its actual camera angle. Thresholds are product hypotheses reviewed with trainers, not medical constants. The app should suppress a cue if the required joints are missing, a rep is incomplete, the camera moves, another person dominates the frame, or evidence conflicts.

**Viewpoint is an unresolved measurement gate.** The current side-view rubric uses relative 2D movement and joint visibility; it has no validated automatic test that the actual view is side-on. The validation sheet therefore separates the observed camera viewpoint from a specialist's suitability judgment and counts measured results on unsuitable views. Only after labeled front, side, and three-quarter sets exist should the team test a geometric view classifier or a [Vision 3D](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images) variant against the frozen iPhone-only baseline. A poor view should produce a retake request, never a confident range or technique claim.

**Research sequence after the first build:** benchmark 3D pose and any camera-view classifier on real devices, then test personal calibration against expert-labeled sound reps, and finally compare synchronized Watch accelerometer plus camera data with camera-only rep boundaries and tempo. Personal calibration can detect within-person drift; it cannot establish that the baseline rep was technically sound. Temporary best/worst pose overlays could help explain a cue, but storing any frame, even briefly in memory, requires an explicit on-screen privacy description, bystander handling, and deletion at set end. These are experiments, not implemented features or a reason to broaden the first-build claim.

### Initial exercise rubric to validate

| Exercise | Observable signal | What Plumb may say | What it must not infer |
| --- | --- | --- | --- |
| Side-view squat | Rep count, range consistency, time per phase | “Your range became shorter in later reps.” | Joint health, strength, safe load, universal depth standard |
| Side-view push-up (later) | Rep count, body-line variation, tempo | “Your hip position changed in later reps.” | Cause of pain or exact muscle activation |

A coach/physio review of cue wording and a labeled test set are required before shipping automated technique claims. User-reported relevance helps prioritize cues but does not replace accuracy testing.

### Foundation Models guardrails

The model receives a constrained observation such as `exercise=squat`, `reps=6`, `pattern=range_decreased`, `evidence=[5,6]`, `confidence=high`, plus approved wording rules. It returns a short explanation and one next-set suggestion through structured output. The app validates that the returned cue references only supplied evidence, fits permitted categories, and includes no diagnosis or load prescription. If generation is unavailable, slow, or invalid, show the reviewed template. Real-time generation is not a dependency for live feedback.

### Permissions and privacy

- Request camera access only when starting a set. Explain the required camera view before the system prompt.
- Do not request microphone access unless a future voice-input feature actually needs it; AirPods output does not require microphone capture.
- Request HealthKit types only when the person chooses Watch/Health features. Explain what will be read or written and allow the camera experience without permission.
- Analyze locally by default. No raw video upload in the prototype. Saving and sharing clips require separate explicit actions; provide deletion and retention controls.
- Keep HealthKit data out of advertising, sale, and unrelated analytics. Publish a privacy policy before any public HealthKit release.
- Clearly label AI-generated wording and let the person inspect the underlying observed signal and dismiss a cue.

### Device and failure states

Test on physical iPhones with different cameras and performance levels, varied lighting, clothing, backgrounds, body types, and phone heights. The simulator can exercise the interface but is not proof of camera/pose quality. Provide a “camera not available” state, permission recovery instructions, a low-confidence retake path, and a no-model fallback. Set a processing budget and measure latency and battery use on the oldest supported device.

### Session states and data contract

Keep the first implementation small enough to inspect: `ready → framing → countdown → capturing → analyzing → result`, with explicit `permission denied`, `interrupted`, and `insufficient evidence` exits. Analysis should finish or cancel cleanly when the app backgrounds, the camera is interrupted, or the person stops early. Never leave the interface claiming to record after capture has ended. A second set belongs to the same exercise session so comparison is possible without guessing which attempts are related.

A saved **set summary** needs a stable session and set ID, exercise/rubric version, camera orientation, start/end time, rep boundaries, aggregate metrics, evidence for any selected cue, analysis confidence, and the person's response. Store a clip URL only after an explicit save. Keep pose traces only as long as required for the promised review and let the person delete the entire session. HealthKit identifiers, if added, belong in a separate optional record so a camera-only user never needs Health authorization.

The interface should distinguish four outcomes: **observation available**, **no meaningful change found**, **insufficient view**, and **analysis failed**. “No meaningful change found” is a useful result; it should not be turned into an invented correction. If rep count is uncertain, show a range or abstain rather than an exact but brittle number. A cue card should contain the observed pattern, the reps or time that support it, one voluntary next action, and a way to dismiss it.

### Accessibility and workout context

The person may be several steps from the phone, moving, or unable to touch the screen immediately. Setup and stop controls need large targets and clear state changes. Countdowns and spoken results must also have visual equivalents; audio is opt-in and must not be required to understand a cue. Respect Reduce Motion and avoid flashing pose overlays. VoiceOver should announce recording state, rep count, and the cue in a sensible order. Dynamic Type must not hide the stop control or evidence. The camera framing guide should explain placement with text and a simple diagram, not colour alone.

Filming in a shared gym is a social constraint as well as a technical one. The camera should not analyze bystanders as the subject; if another person becomes prominent, pause or abstain. Make capture status obvious on screen, keep raw footage local by default, and ask the person to follow venue rules. A discreet no-clip mode matters for users who want feedback without building a video library.

## 5. Business model hypothesis

**Free:** a small weekly allowance of analyzed sets, basic set summaries, and a short history. **Plumb Plus:** unlimited analyzed sets, longer trend history, saved comparisons, and optional voice coaching. A starting pricing hypothesis is €7.99/month or €49.99/year in the first market; validate willingness to pay and platform economics before putting prices in the app. No subscription or payment flow is implemented yet.

The first acquisition wedge is a useful shareable *result*, not a social feed: a person can share a privacy-safe summary of what changed between two sets. Trainers may later use Plumb to review client clips, with opt-in sharing and a separate plan. Do not build a coach marketplace for the challenge.

**Differentiation to test:** iPhone-only entry, evidence-linked cues, personal set-to-set comparisons, local processing, and optional Watch/AirPods continuity. Competitors already offer form feedback or video review; the claim is a focused combination and user experience, not that Plumb invented camera coaching.

## 6. Validation and success measures

### Research before broad release

- Interview at least 6 self-directed lifters and 3 qualified trainers about camera setup, cue usefulness, and willingness to retake a set.
- Record at least 30 consenting test sets across varied participants and settings for the first exercise; annotate rep boundaries and whether each proposed cue is visible. This is a minimum learning set, not a claim of statistical validation.
- Review every initial cue with a qualified trainer or movement specialist and document disagreements.
- Compare Plumb's rep count and cue labels against human annotations. Break results down by lighting, actual camera viewpoint, occlusion, body size, and device. Count every measured result on a specialist-labeled unsuitable view; reporting only rejected bad views would hide false confidence.
- Run a usability test: can a first-time user set up the phone, complete a set, understand the cue, and try it again without help?

### Internal gates

| Gate | Initial target | Failure response |
| --- | --- | --- |
| Setup | 80% of test users get a usable frame in two attempts | Improve guidance or narrow supported environments |
| Rep count | At least 90% exact-match on the labeled squat test set | Do not display a precise count; continue validation |
| Cue agreement | At least 80% of emitted cues judged supported by evidence by expert reviewers | Suppress or revise the cue category |
| Feedback latency | Post-set result within 5 seconds on test devices | Use simpler analysis and deterministic wording |
| Trust | Users can identify why a cue appeared and dismiss it | Rework evidence display and language |

These thresholds are proposed release gates, not measured performance. No cue is better than a confident but wrong cue.

### Test protocol and interpretation

Before analyzing performance, freeze the first squat rubric and annotate the same test sets independently. Record camera distance and height, orientation, device, lighting, clothing visibility, rep count, and why a candidate cue was accepted or rejected. Split the collection by participant so tuning on one person's motion does not inflate the apparent result on their other sets. Report **coverage** (how often Plumb emits a cue) next to **precision** (how often an emitted cue is supported); suppressing every cue can look precise while providing no value.

For the next-set loop, measure whether the user understands the evidence, whether the proposed action is feasible, and whether the named metric changes on the next attempt. A metric changing is not proof of safer movement. Ask users what they disagreed with and keep a path to mark a cue irrelevant. Review failure examples with a qualified movement specialist before adding new cue categories. Document every threshold change against the frozen test set; if the test set is used for tuning, collect a new holdout before claiming the gate was met.

## 7. Challenge timeline and release gate

**10–12 October:** finalize the Plumb concept and brand, stabilize the iPhone project, implement camera setup and one squat analysis loop, then test on a real phone. **13–14 October:** annotate test sets, tune confidence gates, rehearse the set-to-set demo, and add a grounded Foundation Models recap only if the core loop holds. **15–16 October:** present the working path at the Build Challenge, upload a release candidate through App Store Connect if signing and account access are ready, and complete truthful listing/privacy/review materials. The [challenge brief](https://luma.com/cmdf-bc2) asks for a working product, a monetization path, and a build submitted through App Store Connect. Upload, App Review approval, and public release are separate states; release claims require the safety, privacy, accessibility, and device checks appropriate to the shipped feature set.

### Demo script

1. Show the Plumb mark and the setup card: phone at side view, whole body visible.
2. Capture a short squat set on a physical iPhone, or clearly introduce a recorded fallback.
3. Show detected reps, evidence for one cue, and why it was chosen.
4. Repeat a set and show a change in the observed metric.
5. Explain optional Watch context, AirPods speech, and Foundation Models wording as implemented or planned, accurately labeled.

### Honest status rule

The repository now includes a simulator-tested camera-to-result flow, local set history, and brand assets. Do not claim validated coaching accuracy, Watch integration, live cues, subscriptions, or injury reduction in a pitch or screenshot until the behavior exists and has been tested on a physical device. A demo recording or synthetic input must be identified as such.

## 8. Risk register

| Risk | Mitigation |
| --- | --- |
| A single 2D camera angle hides important movement | Exercise- and angle-specific rubrics; show low confidence and retake guidance |
| Model wording sounds certain or invents a cause | Facts from deterministic engine; constrained output; template fallback |
| Training advice could be unsafe for a person | Avoid diagnosis and universal prescriptions; expert cue review; allow dismissal |
| Live feedback is late or distracting | Post-set first; only add live cues after latency and usability tests |
| Camera setup is awkward in a gym | Short setup, stable placement, countdown, no accessory requirement |
| Video and Health data are sensitive | Local processing, opt-in saves, granular permissions, clear deletion |
| Watch integration consumes the challenge schedule | Independent iPhone loop; Watch is additive |
| Demo pose tracking fails in venue lighting | Test venue setup, explicit low-confidence state, labeled recording fallback |
| Paid model is premature | Validate willingness to pay before implementing IAP |

## 9. Decision log

- **10 October 2026:** The team selected Plumb's workout-technique concept. The iPhone camera is the required sensor; Watch and AirPods are optional. Post-set feedback is the first dependable product experience, with live coaching reserved for validation.
- **11 October 2026:** The monochrome icon adopted a custom rounded P within open camera corners. The mark suggests alignment and camera feedback without prescribing a particular exercise pose.
- **11 October 2026:** For the first camera-to-cue build, keep the Xcode project's iOS 27.0 deployment target and support iPhone first. An iPad experience requires its own design and validation before the target includes iPad.

## 10. Primary platform references

- [Apple Vision: 2D body pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images) and [3D body pose](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images)
- [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput)
- [Foundation Models availability and fallback](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [HealthKit workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions) and [multi-device workout sample](https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app)
- [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- [Apple HIG: Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts), [HealthKit](https://developer.apple.com/design/human-interface-guidelines/healthkit), and [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
