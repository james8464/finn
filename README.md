# Plumb

**Plumb** is a planned iPhone-first strength-training companion. Put the phone where its camera can see a supported exercise, do a set, and review one specific observation linked to the movement it saw. Try another set and compare. The product is designed to say when the view is too weak to support a cue.

The iPhone is the core experience. An optional post-set spoken observation uses the current audio output, including paired AirPods. Apple Watch workout data remains a possible later addition. Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. Plumb is a fitness aid, not medical advice or a guarantee of safe technique.

**Current state (13 October 2026):** Plumb has an iPhone camera-to-result flow for four side-view exercises: bodyweight squat, push-up, static lunge, and stiff-leg deadlift. Each exercise defines its joints, movement signal, rep thresholds, and wording in [`ExerciseDefinition.swift`](Plumb/Plumb/Workout/ExerciseDefinition.swift). The current capture rubrics are `squat-side-v5` and `*-side-v4`. The latest revision compares sampled Vision joints with a person mask, so an ankle inferred behind a covered foot no longer makes a synthetic set appear measurable. Four generated videos now test six clear squats, no movement, hidden legs, and covered feet through the production Vision path. The simulator replays the corresponding poses through the visible workout flow. These fixtures do not establish real-person accuracy.

The app shows live framing and a skeleton, counts reps, gives one provisional observation when evidence supports it, and explains retakes. It can compare two measured sets, save derived summaries locally, reopen history, and share a text-only result through the iOS Share Sheet. Optional tap-to-speak feedback uses the current audio route, including paired AirPods. An optional on-device Foundation Models action may reword a validated comparison; invalid or unavailable output falls back to reviewed copy. Video is analyzed on the iPhone and is not saved. History recovery and deletion have explicit failure handling.

On supported hardware, Vision 3D pose estimates whether the person is side-on. A moderately angled view prompts a suggestion; a sustained clearly frontal view can be refused. Exercise recognition from joint-angle rules is optional and retains the chosen exercise when uncertain. Historical replays on public gym videos helped tune earlier rubrics, but the new person-mask revision has not been benchmarked on those videos. Physical iPhone runs across lighting, clothing, occlusions, camera views, and devices, plus qualified review of every coaching cue, are still required. Apple Watch integration, accounts, and subscriptions are not implemented. The challenge target is an honest, reliable iPhone loop and a submitted App Store Connect build; public release depends on validation and distribution access.

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
