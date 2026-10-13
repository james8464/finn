# Plumb

> **TL;DR · 13 October 2026**
> 
> - **This file is the source of truth. Keep it true.**
> - **Idea:** a fitness coach on iPhone + Apple Watch that checks every rep and corrects you the moment it goes wrong. Track your progress and your workouts.
> - **Today we have:** iPhone only, four side-view exercises.
> - **Not built yet:** the full iPhone technology, the full app, the Apple Watch technology (and Apple TV, AirPods head tracking, widgets, Live Activities).

## Rules for AI agents and contributors

1. **Start here.** If a file disagrees with this README, follow the README and point out the conflict. Do not "correct" the README to match an older document.
2. **Built means built.** Never describe a feature as working unless [Current state](#current-state) says so. Everything else in the vision is planned.
3. **Keep this file true.** When you change what is built or the product direction, update this README in the same commit: the TL;DR, "Current state", and the date at the top.

## Plumb idea

Plumb is a fitness coach that lives on your iPhone and Apple Watch, and it watches every set. Prop your phone up once per exercise: the camera checks your posture and execution on every rep, while your Apple Watch counts reps, tracks your tempo and effort, can tap your wrist the moment a rep goes wrong, and can display real-time advice. iPhone and Apple Watch are the core experience. You get the correction as early as possible. Afterwards, the workout's data is available in the app so you can track your progress.

Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. The product is designed to say when the view is too weak to support a cue.

We want Plumb to use as much of Apple's ecosystem as it can, with each device doing the job it is best at.

- **AirPods** can give corrections directly in your ears. They can also detect compensatory movements when the head is supposed to stay still: if the head starts swaying, the person is using momentum to cheat. AirPods can detect this easily (25 Hz). An optional post-set spoken observation already uses the current audio output, including paired AirPods.
- **iPhone Duo** is much better suited to being placed on the ground.
- **Apple TV:** working out in the living room. The iPhone films, and the feedback shows on the TV.

Long term, the same approach can correct movement in many disciplines (gym, home workouts, treadmill running).

Plumb is a fitness aid. It is not medical advice and does not guarantee safe technique.

## Build

We are building the Plumb idea. Keep in mind:

- **A really great product:** it solves a real problem in the best way, it is integrated across four Apple devices (iPhone, Apple Watch, iPhone Duo, Apple TV) plus widgets and Live Activities, and its value shows in the first second.
- **Monetization and customer acquisition** designed into the product from day one.
- **A really astonishing UX/UI:** Liquid Glass (not too much), smooth, fast.
- **Smart technology underneath.**

## Current state

_Updated 13 October 2026._

**In one sentence:** an iPhone-only app that analyzes one exercise from the side, counts reps, and gives one observation after the set. It has not yet been tested on a real iPhone with real people.

**What the app does**

- Four exercises, filmed from the side: bodyweight squat, push-up, static lunge, stiff-leg deadlift.
- Before the set: live camera view with the tracked skeleton and framing tips.
- After the set: a rep count and at most one observation, only when the evidence supports it. Otherwise, it explains why the set should be redone.
- Compares two sets, keeps a local history, and shares a result as text.
- Reads the observation aloud on tap, through the iPhone speaker or AirPods.
- Optional: Apple Intelligence can reword the comparison. If it is unavailable or fails, a pre-written sentence is shown.
- Video is analyzed on the iPhone and never saved.

**How it avoids wrong answers**

- Checks that the person is filmed from the side (Vision 3D). A slight angle gives a placement tip; facing the camera for several seconds refuses the set.
- Checks that every detected joint lies on the person's silhouette, so a hidden ankle is not invented (new on 13 October).
- Follows one athlete and ignores other people in view.
- Optional: recognizes the exercise automatically and keeps the user's choice when unsure.

**Not proven yet**

- Tested only in the simulator, on generated videos, and on public videos. No run yet on a physical iPhone across lighting, clothing, and camera angles.
- Four generated test videos cover six clear squats, no movement, hidden legs, and covered feet. These tests are reproducible but do not establish accuracy on real people.
- No qualified trainer has reviewed the coaching observations.
- The silhouette check has not yet been measured on the public videos.

**Not built:** Apple Watch, Apple TV, AirPods head tracking, widgets, Live Activities, accounts, subscriptions.

**Challenge goal:** a reliable iPhone loop and a build submitted through App Store Connect. Public release depends on validation and distribution access.

_For developers:_ each exercise is defined in `ExerciseDefinition.swift` (rule versions `squat-side-v5` and `*-side-v4`). Generated test videos are in `tools/replay`.

Project for the October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F.

## Rules that always apply

- **No medical claims.** Never claim injury prevention, diagnosis, or guaranteed safe technique.
- **AI phrases, it never decides.** Language models may only reword facts measured by the analysis.
- **Permissions in context.** Ask for camera access at camera setup, and for Health data only when a Health feature is used.
- **Privacy.** Video stays on the device and is not saved. Changing that needs an explicit user choice and an updated privacy policy.
- **Honest demos.** Label synthetic or recorded input. Never present it as live tracking.

## Documents

- `Design/README.md`: Plumb brand theme, colors, typography, icon, and live Figma guide
- `docs/design/iphone-experience-review.md`: iPhone interface decisions tied to Apple guidance and Design Award examples
- `planning.md`: experience, scoped MVP, technical approach, privacy, validation, and timeline
- `docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`: task-by-task plan for the first real iPhone squat session
- `docs/validation/squat-v1-protocol.md`: consent, physical-device test, annotation, and claim gates
- `docs/validation/physical-iphone-run.md`: step-by-step device smoke run when the iPhone is available
- `docs/validation/squat-v1-results.md`: actual results status; no real sets collected yet
- `docs/validation/exercise-rules-v1.md`: push-up, lunge, and deadlift rules, the 3D camera-angle check, and what each still needs on a physical iPhone
- `tools/replay/README.md`: generated simulator sets for every exercise, missing-joint refusal, and Mac replay of a saved video through Vision and the production analyzer
- `tools/exercise-classifier/README.md`: clip format, labeling, Create ML training, and installing the exercise classifier
- `docs/release/app-store-submission.md`: release checks and App Store Connect status
- [Public support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html): live pages for the current iPhone candidate
- `docs/release/app-privacy-answers.md`: source-backed draft of App Store privacy answers for the current iPhone build
- `justification.md`: why a focused camera technique companion is worth testing
- `market research.md`: primary-source alternatives and customer research plan
- `pitch.md`: three-minute story, demo path, and claim boundaries
- `Plumb/GIT guide.md`: the team's current `main` branch workflow

## Team

- James
- Klaus
- Theophile
- Guilhem

## Open the iPhone project

1. Clone the repository and switch to `main`.
2. Open `Plumb/Plumb.xcodeproj` in Xcode.
3. Choose an iPhone simulator or connected iPhone and build the `Plumb` scheme.

The layered Icon Composer source is `Plumb/Plumb/AppIcon.icon`. Flat marks and a preview are in `Plumb/BrandArtwork`.

The capture screen shows an elapsed clock while a set is active. For repeatable development testing, the Debug build has generated six-rep fixtures for all four exercises and a missing-wrist case. The fixtures test app behavior without doing a workout; they do not validate pose detection or coaching accuracy on real people. See the replay guide for simulator commands and saved-video analysis on a Mac.
