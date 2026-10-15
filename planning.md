# Plumb — product and build plan

**Historical plan, 13 October 2026.** This records the challenge-era design, technical choices, validation gates, and decisions. The [README](README.md) owns current feature status; some implementation statements below are superseded. The [product brief](docs/product/brief.md) holds current result boundaries and sequence.

## 1. Product thesis

**One line:** Plumb uses an iPhone camera to observe movement and return one clear, evidence-linked observation the person can try in the next set or session.

**Promise:** Better form, one set at a time. The goal is useful feedback during solo training without a specialist camera or a constant human coach. Plumb does not promise perfect technique, injury prevention, medical assessment, or a replacement for a qualified trainer.

**First audience:** self-directed people doing basic strength exercises at home or in a gym. They know the exercise they intend to do but cannot easily see their own movement. Beginners need simple setup and respectful language; more experienced users want objective comparisons over time. Treadmill runners are a prospective adjacent audience after a running-specific observation has been validated.

**Validation partners:** qualified trainers can review the accuracy and usefulness of Plumb's cues. The README does not scope a trainer product or account.

**Core insight:** a generic exercise video tells a person what form should look like; Plumb shows what their own last set looked like and suggests a single next action. The value is the loop: **capture → observe → understand → try again → compare**.

### Design principles

1. **Evidence before interpretation.** A cue must link to a visible rep or measurement. If tracking is weak, say so and ask for a better camera angle.
2. **One useful cue.** Prioritize one actionable change per set, not a stream of criticism.
3. **Personal progression.** Compare repeatable movement patterns with the person's own earlier sets; avoid a universal “perfect form” score.
4. **Private by default.** Analyze video on device and do not save raw footage in the current product.
5. **Start on iPhone; build the paired experience.** The current camera and on-device rules work without accessories. Apple Watch is core to the intended full product; AirPods, Apple TV, iPhone Duo placement, and Foundation Models have specific optional roles.
6. **Respect physical limits.** Do not diagnose pain or prescribe load. Encourage stopping if an exercise causes pain and seeking qualified advice when appropriate.
7. **Quiet, native presentation.** One primary action per stage, plain evidence, system typography and controls, and no decorative AI interface. See the [iPhone experience review](docs/design/iphone-experience-review.md) for Apple HIG and award-winning app references.

## 2. The experience

### Primary journey

1. Choose an exercise and read a short setup card: phone on a stable surface, side view, entire body and equipment in frame, enough light, clear floor.
2. Grant camera access when starting capture. Plumb shows whether the joints required for the chosen exercise stay visible. Its 3D viewpoint check can suggest turning; a clearly frontal view is counted without posture advice. Actual camera suitability still needs physical-device validation. It never starts analysis silently.
3. Tap or use a short countdown to start. The current build analyses a live frame stream on the iPhone without saving a video.
4. After the set, Plumb displays measured rep count and at most one supported observation, or explains that no clear pattern was found or why to retake. Supporting rep details remain available. This is not a judgment of perfect overall form.
5. The person chooses **Try this next set**, **Not relevant**, or **Retake**. A follow-up set can show whether the same observed pattern changed; the current camera view does not display an in-set coaching reminder.
6. In the intended paired experience, Apple Watch contributes rep timing, effort context, controls, and discreet haptics; live cues need validation before release. The current iPhone build can speak post-set observations through the system audio output, including paired AirPods.

### Example: bodyweight squat

A side-view capture detects six reps. The last two have a shorter camera-observed range than the first two. Plumb says: “Your range became shorter in the last two reps.” Its next action is “Choose a range you can repeat on each rep.” The result identifies reps 5–6 and can show the measured range. It does **not** claim the user's squat is unsafe, diagnose mobility, or issue a universal depth target. If the feet or hips are obscured, it asks for a better view and a retake.

### What each device contributes

| Device | Intended role | Dependency |
| --- | --- | --- |
| iPhone | Camera capture, pose estimation, set review, history | Required |
| Apple Watch | Core future companion for workout context, rep timing, tempo, effort, and discreet cue haptics | Separate watchOS target, HealthKit permission, paired-device testing; absent from current build |
| AirPods | Current optional spoken result through normal audio routing; proposed future head-motion signal | Motion-capable device, availability and permission checks, paired tests for any head-motion feature |
| iPhone Duo | Proposed self-standing camera placement | Test framing and stability on the device; no special support in current build |
| Apple TV | Proposed living-room display for iPhone-observed workouts | Separate display and privacy design; no current app |
| Apple Intelligence-capable device | Optional Foundation Models wording of structured observations | Availability check and deterministic text fallback |

The Watch's heart rate describes effort context; it cannot prove whether a rep has good form. A watchOS prototype can use timestamped accelerometer motion to test whether rep boundaries and tempo improve when camera evidence is weak. That requires synchronization, paired-device tests, and a measured advantage over iPhone-only analysis before it becomes a product claim. AirPods currently carry a cue; a future head-motion check must prove that it detects a useful exercise-specific pattern before Plumb interprets it as compensatory movement. This distinction must remain clear in product copy.

## 3. Scope and priorities

### Build order for the challenge

1. **Make value clear immediately on iPhone.** The first screen shows the chosen exercise as the camera will see it, lets someone switch exercise with one tap, and puts **Start a set** one tap away. Capture should lead to one measured observation or a plain retake reason within the latency gate, without a decorative score or mandatory sign-in.
2. **Validate the iPhone loop before adding a second sensor.** Run the camera, occlusion, camera-angle, performance, and expert-cue protocol on a physical iPhone. The person-mask check must be tested for both missed occlusions and false refusals on real clothing and backgrounds.
3. **Prototype Apple Watch as the next core device.** Start with a watchOS workout session, elapsed time, and discreet start/stop or haptic feedback, while the iPhone remains the form sensor and source of truth. Add accelerometer fusion only after synchronized sets show a measurable improvement in rep boundaries or tempo over camera-only analysis. Keep the current iPhone-only prototype usable while building the paired experience.
4. **Explore treadmill running as a separate movement mode.** A treadmill session is continuous rather than a series of strength reps. First identify a safe, stable phone position and a useful camera view; then define a small set of observable gait signals with an expert. Test treadmill motion, camera vibration, partial visibility, pace changes, and bystanders. Keep the first candidate result post-run, evidence-linked, and able to abstain. Do not extend squat thresholds or promise injury prevention.
5. **Add the other proposed surfaces only when their roles work.** A widget or Live Activity could show an active session and return to the iPhone workout. Test iPhone Duo as a self-standing camera placement and Apple TV as a living-room display. Each needs a clear benefit, privacy review, and device testing; none is part of the current submission claim.

The movement-analysis interface may later be replaced or augmented by a team-provided engine. Keep the contract explicit: timestamped poses or movement events, per-joint confidence, recognized exercise, and a versioned evidence result. Benchmark the proposed engine against the same replay fixtures and consented holdout before displaying its coaching claims. No SDK, repository, or sample output has been provided yet, so the current on-device analyzer remains the working implementation.

The repository and its support/privacy pages are public, but the root [LICENSE](LICENSE) reserves rights to the named project members and grants others viewing only. Confirm that any team-provided engine, third-party code, or training material may be included under these terms before adding it. Repository visibility is a team decision because changing it can affect collaboration and the published pages.

**Business test:** The README calls for a monetization and acquisition plan, but names no paid feature or price. Let someone complete a useful first set before testing willingness to pay. Track activation as the share of new users who reach a measured result within two setup attempts, then measure second-set return and willingness to pay with consented research rather than inventing traction.

### Prototype: one complete evidence loop

- Branded iPhone app with camera permission, setup guidance, framing feedback, and a real capture session.
- **Bodyweight squat, side view** as the first calibrated exercise. Count reps and calculate a limited set of observable, testable signals: camera-relative hip-range consistency, rep duration, and tracking confidence. A required setup instruction is not proof of the actual viewpoint; validation must count false measured outcomes from unsuitable front and three-quarter views.
- A post-set summary with one evidence-linked cue, uncertainty language, and a second-set comparison.
- On-device storage of exercise name, date, rep count, derived metrics, selected cue, and user response. Raw video is discarded by default. Saved summaries and recovered-history backups request [iOS complete file protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files), so the app accesses them while the device is unlocked; locked-device behavior still needs a physical-iPhone check.
- Optional, user-initiated sharing of a measured set's text summary through the iOS Share Sheet. When two compatible sets have been measured, the text also states the camera-measured range change or that no clear change was found. It excludes dismissed observations and never includes video or camera frames.
- A deterministic coaching template that works without Foundation Models or network access.
- Clear demo labels if using a seeded sample; a recorded example must never be presented as live tracking.

### Next if the prototype is reliable

- Validate the four existing side-view exercise rubrics on real people before broad claims.
- Verify the existing tap-to-speak post-set cue on physical devices and paired AirPods. It is never automatic and does not request microphone access.
- Apple Watch companion, beginning with a real HealthKit workout session and user-controlled saving.
- Verify the existing Foundation Models comparison wording on an eligible device. The model cannot invent a new biomechanical finding or make a medical claim.

### Later product

- More movements and camera angles only after expert review and device testing.
- Carefully gated live cues, central to the full product vision, when pose confidence, latency, and cue usefulness meet thresholds. One short cue at most per relevant event, with a quiet mode and discreet Watch or AirPods delivery where supported.
- Progress through local workout history and comparisons rather than a universal form score.
- Evaluate the README's proposed iPhone Duo placement, Apple TV display, widgets, and Live Activities after the core iPhone + Watch experience works.

### Explicit exclusions for the first build

No automatic exercise recognition across the whole gym, load prescription, injury prediction, medical advice, remote video upload, multi-person analysis, social feed, exercise leaderboard, or promise that every phone/angle can judge every movement.

### Cut order when time is short

Cut Watch integration, then speech, then a second exercise. Keep real iPhone capture, a confidence-aware observation, and an honest post-set result. A small Foundation Models comparison recap is an optional challenge enhancement only after the core loop is stable; it must have an on-device availability check and reviewed fallback. If pose analysis itself fails, show an honest retake path in the app and use a clearly labeled recorded test set in the presentation rather than fabricated AI feedback.

## 4. Technical plan

### Stack and boundaries

- **SwiftUI** for the iPhone experience; system text styles, Dynamic Type, VoiceOver labels, Dark Mode, and large workout controls.
- **AVFoundation** for camera frames through `AVCaptureVideoDataOutput`. Discard late frames rather than building an unbounded processing queue.
- **Vision** body-pose observations from a live frame stream, not isolated still photos. Every third analyzed frame also uses a fast person mask to check that inferred joints have image evidence. Vision 3D body pose estimates the camera view on supported hardware; neither pose nor segmentation alone establishes coaching accuracy. Avoid universal joint-angle cutoffs because a 2D projection changes with viewpoint.
- A **deterministic exercise engine** converts a time series of pose points into rep phases and observed metrics. It owns every factual coaching claim.
- **Foundation Models**, if available, only summarizes a small structured observation and chooses wording from allowed cue categories. Check model availability at runtime; fallback to reviewed templates. Do not send raw video to a language model for the MVP.
- **SwiftData or a small local store** for derived workout summaries and preferences. The app does not save workout video.
- **HealthKit/watchOS**, later, for authorized workout and heart-rate context. Watch workout mirroring requires a separate watch app and physical-device testing.
- **AVSpeechSynthesizer** for optional spoken output. Use the system audio route; respect silent/voice preferences and avoid competing with a person's music.

### Analysis pipeline

```text
Camera frame
  → Vision pose points + confidence
  → sampled person-mask corroboration
  → orientation/framing/occlusion gate
  → smoothed joint trajectories
  → exercise-specific rep state machine
  → derived metrics + evidence timestamps
  → ranked, validated observation
  → template or Foundation Models wording
  → post-set cue + user response
```

The fuller observation contract should include exercise, assessed viewpoint, involved joints, confidence, metric, threshold version, and rep/time range. The current prototype stores a smaller derived summary and estimates camera angle when Vision 3D is available; that estimate still needs physical-device validation. Thresholds are product hypotheses awaiting trainer review, not medical constants. The app should suppress a cue if the required joints are missing, a rep is incomplete, the camera moves, another person dominates the frame, or evidence conflicts.

**Viewpoint remains an unvalidated measurement gate.** The side-view rubric uses relative 2D movement and joint visibility; the validation sheet therefore separates actual camera viewpoint from a specialist's suitability judgment and counts measured results on unsuitable views. The [Vision 3D](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images) check, on by default, suggests turning when the median is over 30° from profile. A sustained frontal view at 75° or more was refused until 15 October; it is now counted without posture advice. Those cutoffs were examined on public videos, but need physical iPhone confirmation and expert suitability labels. Labeled front, side, and three-quarter sets must reveal both false refusals and false acceptance.

**Research sequence after the first build:** benchmark the existing 3D camera-view check on real devices, then compare synchronized Watch accelerometer data with camera-only rep boundaries and tempo. These tests support the README's planned iPhone + Watch experience; neither establishes coaching accuracy without labeled sets and expert review.

### Initial exercise rubric to validate

| Exercise | Observable signal | What Plumb may say | What it must not infer |
| --- | --- | --- | --- |
| Side-view squat | Rep count, range consistency, and torso tilt at the bottom | “Your torso tilted farther from upright in the last two reps.” | Joint health, strength, safe load, universal depth standard |
| Side-view push-up | Rep count, elbow-bend consistency, and hip alignment relative to the body line | “Your hips sat lower relative to your shoulder-to-ankle line in the last two reps.” | Cause of pain, exact muscle activation, proof of a straight body line |
| Side-view static lunge | Rep count, knee-bend consistency, and torso tilt at the bottom | “Your torso tilted farther from upright in the last two reps.” | Knee health, which leg is weaker |
| Side-view stiff-leg deadlift | Rep count, hip-hinge consistency, and knee bend at the bottom | “Your knees bent more during the last two hinges.” | Back safety, hamstring flexibility, safe load |

A coach/physio review of cue wording and a labeled test set are required before shipping automated technique claims. User-reported relevance helps prioritize cues but does not replace accuracy testing.

### Foundation Models guardrails

The model receives a constrained observation such as `exercise=squat`, `reps=6`, `pattern=range_decreased`, `evidence=[5,6]`, `confidence=high`, plus approved wording rules. It returns a short explanation and one next-set suggestion through structured output. The app validates that the returned cue references only supplied evidence, fits permitted categories, and includes no diagnosis or load prescription. If generation is unavailable, slow, or invalid, show the reviewed template. Real-time generation is not a dependency for live feedback.

### Permissions and privacy

- Request camera access only when starting a set. Explain the required camera view before the system prompt.
- Do not request microphone access unless a future voice-input feature actually needs it; AirPods output does not require microphone capture.
- Request HealthKit types only when the person chooses Watch/Health features. Explain what will be read or written and allow the camera experience without permission.
- Analyze camera frames locally. Do not save or upload workout video. Provide deletion controls for derived summaries.
- Keep HealthKit data out of advertising, sale, and unrelated analytics. Publish a privacy policy before any public HealthKit release.
- Clearly label AI-generated wording and let the person inspect the underlying observed signal and dismiss a cue.

### Device and failure states

Test on physical iPhones with different cameras and performance levels, varied lighting, clothing, backgrounds, body types, and phone heights. The simulator can exercise the interface but is not proof of camera/pose quality. Provide a “camera not available” state, permission recovery instructions, a low-confidence retake path, and a no-model fallback. Set a processing budget and measure latency and battery use on the oldest supported device.

### Session states and data contract

Keep the first implementation small enough to inspect: `ready → framing → countdown → capturing → analyzing → result`, with explicit `permission denied`, `interrupted`, and `insufficient evidence` exits. Analysis should finish or cancel cleanly when the app backgrounds, the camera is interrupted, or the person stops early. Never leave the interface claiming to record after capture has ended. A second set belongs to the same exercise session so comparison is possible without guessing which attempts are related.

A saved **set summary** needs a stable session and set ID, exercise/rubric version, camera orientation, start/end time, rep boundaries, aggregate metrics, evidence for any selected cue, analysis confidence, and the person's response. Raw video is not saved; keep pose traces only as long as analysis needs them and let the person delete the entire session. HealthKit identifiers, if added for the Watch, belong in a separate optional record so a camera-only user never needs Health authorization.

The interface should distinguish four outcomes: **observation available**, **no supported pattern**, **insufficient view**, and **analysis failed**. “No supported pattern” should not become an invented correction or a perfect-form claim. If rep count is uncertain, show a range or abstain rather than an exact but brittle number. A cue card should contain the observed pattern, the reps or time that support it, one voluntary next action, and a way to dismiss it.

### Accessibility and workout context

The person may be several steps from the phone, moving, or unable to touch the screen immediately. Setup and stop controls need large targets and clear state changes. Countdowns and spoken results must also have visual equivalents; audio is opt-in and must not be required to understand a cue. Respect Reduce Motion and avoid flashing pose overlays. VoiceOver should announce recording state, rep count, and the cue in a sensible order. Dynamic Type must not hide the stop control or evidence. The camera framing guide should explain placement with text and a simple diagram, not colour alone.

Filming in a shared gym is a social constraint as well as a technical one. The camera should not analyze bystanders as the subject; if another person becomes prominent, pause or abstain. Make capture status obvious on screen, process footage locally without saving it, and ask the person to follow venue rules.

## 5. Business model hypothesis

The README calls for monetization and customer acquisition to be designed into the product, but does not select a paid plan, price, or paywall. Test willingness to pay only after the iPhone set-to-set loop is useful and validated. No subscription or payment flow is implemented.

The first acquisition hypothesis is a useful shareable *result*, not a social feed: a person can share a text summary of what changed between two sets. This does not require a trainer workflow or uploaded footage.

**Differentiation to test:** iPhone-only entry, evidence-linked cues, personal set-to-set comparisons, local processing, and an eventual iPhone + Watch loop with timely corrections. AirPods audio is an optional delivery route. Competitors already offer form feedback or video review; the claim is a focused combination and user experience, not that Plumb invented camera coaching.

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
5. Explain the intended Watch role, current optional AirPods speech, and Foundation Models wording as implemented or planned, accurately labeled.

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
| Video and Health data are sensitive | Local analysis without saved video, contextual permissions, clear summary deletion |
| Watch integration consumes the challenge schedule | Independent iPhone loop; Watch is additive |
| Demo pose tracking fails in venue lighting | Test venue setup, explicit low-confidence state, labeled recording fallback |
| Paid model is premature | Validate willingness to pay before implementing IAP |

## 9. Decision log

- **10 October 2026:** The team selected Plumb's workout-technique concept. The iPhone camera is the required sensor; Watch and AirPods were scoped as optional for the first prototype. Post-set feedback is the first dependable product experience, with live coaching reserved for validation.
- **11 October 2026:** The monochrome icon adopted a custom rounded P within open camera corners. The mark suggests alignment and camera feedback without prescribing a particular exercise pose.
- **11 October 2026:** For the first camera-to-cue build, keep the Xcode project's iOS 27.0 deployment target and support iPhone first. An iPad experience requires its own design and validation before the target includes iPad.
- **13 October 2026:** Team feedback makes the first useful iPhone result and a quiet native interface the immediate priority. Apple Watch is the next device prototype; Apple TV, a second iPhone, widgets, and Live Activities need a demonstrated benefit before implementation. Treadmill running joins the intended product scope but requires a separate, expert-reviewed gait rubric. Keep the working name until the team agrees on another. Favor Apple's on-device pose capabilities and replayable validation over training a new model without a labeled dataset. An external movement engine can be evaluated when an actual interface and sample output arrive.
- **13 October 2026, README refinement:** The full product vision makes iPhone and Apple Watch the core pair and timely validated correction the intended experience. iPhone Duo placement, AirPods audio and possible head motion, and Apple TV display have distinct proposed roles. None of these new device features is in the current iPhone build; validate the existing camera loop first.

## 10. Primary platform references

- [Apple Vision: 2D body pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images) and [3D body pose](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images)
- [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput)
- [Foundation Models availability and fallback](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [HealthKit workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions) and [multi-device workout sample](https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app)
- [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- [Apple HIG: Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts), [HealthKit](https://developer.apple.com/design/human-interface-guidelines/healthkit), and [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
