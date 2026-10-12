# Plumb

**Plumb** is a planned iPhone-first strength-training companion. Put the phone where its camera can see a supported exercise, do a set, and review one specific observation linked to the movement it saw. Try another set and compare. The product is designed to say when the view is too weak to support a cue.

The iPhone is the core experience. An optional post-set spoken observation uses the current audio output, including paired AirPods. Apple Watch workout data remains a possible later addition. Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. Plumb is a fitness aid, not medical advice or a guarantee of safe technique.

**Current state (12 October 2026):** the iPhone app has a bodyweight-squat flow: camera setup with live hip/knee/ankle visibility feedback, countdown, capture, and a measured or abstaining result with rep evidence. A provisional cue can describe a late-set range change. Its existing observation and next action can be spoken on demand through the system audio route; speech stops when the result is left or dismissed, and no audio is recorded. Two measured sets in one session can be compared and their derived summaries are saved locally. History opens each session to review measured sets and rep details, and offers deletion. Temporary history access failures offer retry and keep an unsaved derived summary in memory until storage returns. Failed deletion remains pending for retry instead of being reported as complete; backup files are deleted before the main history file. In-memory pending work cannot survive app termination; corrupt history requires an explicit backup-and-recover action. A measured result can be shared deliberately as text through the iOS Share Sheet; when the sets are compatible, that text includes the camera-measured change. No video is included. An optional **Reword comparison** action can replace the displayed sentence with approved Apple Intelligence wording when the on-device model is available; invalid or timed-out output falls back to reviewed copy. AVFoundation and Vision analyze a live frame stream on-device and retain only pose records; no movie is saved. Simulator tests exercise the analysis and a clearly labeled synthetic six-rep UI path. The app asks for a side view, but the visibility indicator is not a validated camera-angle check; the test protocol measures false confidence from front and three-quarter views. Synthetic evidence tests also request a retake for sustained bystander detection and long tracking loss; those thresholds still need real-gym validation. Live camera orientation, pose quality, generated wording, audio routing, and coaching claims still require a physical iPhone and expert validation. Watch integration, accounts, and subscriptions are not implemented. The challenge goal is a tested iPhone camera-to-cue experience, a credible product pitch, and an App Store Connect build submission; public availability depends on further review and validation.

Project for the October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F.

## Documents

- [`Design/README.md`](Design/README.md): Plumb brand theme, colors, typography, icon, and live Figma guide
- [`docs/design/iphone-experience-review.md`](docs/design/iphone-experience-review.md): iPhone interface decisions tied to Apple guidance and Design Award examples
- [`planning.md`](planning.md): experience, scoped MVP, technical approach, privacy, validation, and timeline
- [`docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`](docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md): task-by-task plan for the first real iPhone squat session
- [`docs/validation/squat-v1-protocol.md`](docs/validation/squat-v1-protocol.md): consent, physical-device test, annotation, and claim gates
- [`docs/validation/physical-iphone-run.md`](docs/validation/physical-iphone-run.md): step-by-step device smoke run when the iPhone is available
- [`docs/validation/squat-v1-results.md`](docs/validation/squat-v1-results.md): actual results status; no real sets collected yet
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
