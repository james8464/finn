# Plumb

**Plumb** is a planned iPhone-first strength-training companion. Put the phone where its camera can see a supported exercise, do a set, and review one specific observation linked to the movement it saw. Try another set and compare. The product is designed to say when the view is too weak to support a cue.

The iPhone is the core experience. Apple Watch workout data and spoken feedback through AirPods are optional additions. Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. Plumb is a fitness aid, not medical advice or a guarantee of safe technique.

**Current state (11 October 2026):** this repository contains the renamed Xcode starter app, the Plumb icon, brand assets, the product plan, and a detailed first-build implementation plan. The visible app screen introduces the concept. Camera analysis, Watch integration, coaching, subscriptions, and workout history are not implemented. The challenge goal is a tested iPhone camera-to-cue experience for a side-view bodyweight squat, a credible product pitch, and an App Store Connect build submission; public availability depends on further review and validation.

Project for the October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F.

## Documents

- [`Design/README.md`](Design/README.md): Plumb brand theme, colors, typography, icon, and live Figma guide
- [`planning.md`](planning.md): experience, scoped MVP, technical approach, privacy, validation, and timeline
- [`docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`](docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md): task-by-task plan for the first real iPhone squat session
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
