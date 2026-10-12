# Plumb

**Plumb** is a planned iPhone-first strength-training companion. Put the phone where its camera can see a supported exercise, do a set, and review one specific observation linked to the movement it saw. Try another set and compare. The product is designed to say when the view is too weak to support a cue.

The iPhone is the core experience. An optional post-set spoken observation uses the current audio output, including paired AirPods. Apple Watch workout data remains a possible later addition. Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. Plumb is a fitness aid, not medical advice or a guarantee of safe technique.

**Current state (12 October 2026):** the iPhone app checks four exercises filmed from the side: bodyweight squat, push-up, static lunge, and stiff-leg deadlift. Each exercise is a data description in [`ExerciseDefinition.swift`](Plumb/Plumb/Workout/ExerciseDefinition.swift) (tracked joints, movement signal, top and bottom phase thresholds, expected view, wording), and one rep analyzer runs all four. The squat rubric is `squat-side-v3`: version 2 counted no rep on real video because its 0.6 joint-confidence floor was above what Vision reports for real hips, and version 3 measured 42 of 50 public side-view squat videos (details in [`docs/validation/exercise-rules-v1.md`](docs/validation/exercise-rules-v1.md)). The push-up, lunge, and deadlift rubrics (`*-side-v2`) share its rep logic and have no expert review; only push-ups were replayed on real video. When a set counts nothing, or drops a movement, the result says why with numbers. Each flow has camera setup that shows the frames being analyzed with the tracked skeleton and the measured angle at the key joint, live visibility feedback for the chosen exercise's joints, countdown, capture, and a measured or abstaining result with rep evidence. A provisional cue can describe a late-set range change. Its existing observation and next action can be spoken on demand through the system audio route; speech stops when the result is left or dismissed, and no audio is recorded. Two measured sets in one session can be compared and their derived summaries are saved locally. History opens each session to review measured sets and rep details, and offers deletion. Temporary history access failures offer retry and keep an unsaved derived summary in memory until storage returns. Failed deletion remains pending for retry instead of being reported as complete; backup files are deleted before the main history file. In-memory pending work cannot survive app termination; corrupt history requires an explicit backup-and-recover action. A measured result can be shared deliberately as text through the iOS Share Sheet; when the sets are compatible, that text includes the camera-measured change. No video is included. An optional **Reword comparison** action, for every exercise, can replace the displayed sentence with approved Apple Intelligence wording when the on-device model is available; invalid or timed-out output falls back to reviewed copy. AVFoundation and Vision analyze a live frame stream on-device and retain only pose records; no movie is saved. Simulator tests exercise the analysis and a clearly labeled synthetic six-rep UI path. On supported iPhones, Vision 3D body pose also estimates the camera angle about four times per second. An angled view only adds a tip to turn a little, and the set is still counted; a set is refused only when the person clearly faces the camera (75° or more) for several seconds. Measured on 150 public gym videos, 75° separates front views from side and diagonal ones. A bug fixed on 12 October made every earlier build read every view as frontal and refuse it. Options can switch the check off. Without 3D estimates (simulator, request failure), the visibility indicator remains the only view check, and it is not a validated camera-angle check; the test protocol measures false confidence from front and three-quarter views. After a set, Plumb also recognizes the exercise from Vision joint angles with hand-written rules (Options → Recognize the exercise automatically, on by default); when they are not sure, it keeps the exercise chosen on setup. A trained Core ML model is an optional experiment, off by default and offered only when a build includes one. On held-out participants of a public side-view video set, the rules and a trained angle model both named 12 of 12 squat sets and gave no set a wrong exercise; push-ups and lunges or deadlifts are weaker or unmeasured on real video ([`angle-model/README.md`](tools/exercise-classifier/angle-model/README.md)). No trained model is in the repository. [`tools/exercise-classifier`](tools/exercise-classifier/README.md) covers filming, training, and adding a model. Plumb follows one athlete: other people in view are drawn grey and ignored, and a set is refused only when the athlete is hidden for more than 3 s, or lost for 0.75 s with nobody else in view. On 50 public gym videos run through the app's capture path, tracking took the measured sets from 5 to 44. Live camera orientation, pose quality, generated wording, audio routing, and coaching claims still require a physical iPhone and expert validation. Watch integration, accounts, and subscriptions are not implemented. The challenge goal is a tested iPhone camera-to-cue experience, a credible product pitch, and an App Store Connect build submission; public availability depends on further review and validation.

Project for the October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F.

## Documents

- [`Design/README.md`](Design/README.md): Plumb brand theme, colors, typography, icon, and live Figma guide
- [`docs/design/iphone-experience-review.md`](docs/design/iphone-experience-review.md): iPhone interface decisions tied to Apple guidance and Design Award examples
- [`planning.md`](planning.md): experience, scoped MVP, technical approach, privacy, validation, and timeline
- [`docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`](docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md): task-by-task plan for the first real iPhone squat session
- [`docs/validation/squat-v1-protocol.md`](docs/validation/squat-v1-protocol.md): consent, physical-device test, annotation, and claim gates
- [`docs/validation/physical-iphone-run.md`](docs/validation/physical-iphone-run.md): step-by-step device smoke run when the iPhone is available
- [`docs/validation/squat-v1-results.md`](docs/validation/squat-v1-results.md): actual results status; no real sets collected yet
- [`docs/validation/exercise-rules-v1.md`](docs/validation/exercise-rules-v1.md): push-up, lunge, and deadlift rules, the 3D camera-angle check, and what each still needs on a physical iPhone
- [`tools/replay/README.md`](tools/replay/README.md): generated simulator sets for every exercise, missing-joint refusal, and Mac replay of a saved video through Vision and the production analyzer
- [`tools/exercise-classifier/README.md`](tools/exercise-classifier/README.md): clip format, labeling, Create ML training, and installing the exercise classifier
- [`docs/release/app-store-submission.md`](docs/release/app-store-submission.md): release checks and App Store Connect status
- [Public support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html): live pages for the current iPhone candidate
- [`docs/release/app-privacy-answers.md`](docs/release/app-privacy-answers.md): source-backed draft of App Store privacy answers for the current iPhone build
- [`justification.md`](justification.md): why a focused camera technique companion is worth testing
- [`market research.md`](market%20research.md): primary-source alternatives and customer research plan
- [`pitch.md`](pitch.md): three-minute story, demo path, and claim boundaries
- [`Plumb/GIT guide.md`](Plumb/GIT%20guide.md): the team's current `main` branch workflow

## Team

- James
- Klaus
- Theophile
- Guilhem

## Open the iPhone project

1. Clone the repository and switch to `main`.
2. Open [`Plumb/Plumb.xcodeproj`](Plumb/Plumb.xcodeproj) in Xcode.
3. Choose an iPhone simulator or connected iPhone and build the `Plumb` scheme.

The layered Icon Composer source is [`Plumb/Plumb/AppIcon.icon`](Plumb/Plumb/AppIcon.icon). Flat marks and a preview are in [`Plumb/BrandArtwork`](Plumb/BrandArtwork).

The capture screen shows an elapsed clock while a set is active. For repeatable development testing, the Debug build has generated six-rep fixtures for all four exercises and a missing-wrist case. The fixtures test app behavior without doing a workout; they do not validate pose detection or coaching accuracy on real people. See the [replay guide](tools/replay/README.md) for simulator commands and saved-video analysis on a Mac.
