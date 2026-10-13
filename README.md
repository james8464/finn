# Plumb

> **TL;DR · 13 October 2026**
>
> - **This file is the source of truth. Keep it true.**
> - **Idea:** a fitness coach on iPhone + Apple Watch that aims to check every rep and give appropriate, actionable advice on posture and execution. Track your progress and your workouts.
> - **Today we have:** iPhone only, four side-view exercises with rep counting and limited, evidence-linked posture or range advice after a set; hands-free sets with the live rep count on screen and in your ears (AirPods or speaker); your most frequent pattern before each set.
> - **Written, not yet in the build:** an Apple Watch companion that mirrors the iPhone's count (its Xcode target and icon are still to add).
> - **Not built yet:** Apple Watch measurement (wrist motion, heart rate, workout session), Apple TV, AirPods head tracking, widgets, Live Activities.

## Rules for AI agents and contributors

1. **Start here.** If a file disagrees with this README, follow the README and point out the conflict. Do not "correct" the README to match an older document.
2. **Built means built.** Never describe a feature as working unless [Current state](#current-state) says so. Everything else in the vision is planned.
3. **Keep this file true.** When you change what is built or the product direction, update this README in the same commit: the TL;DR, "Current state", and the date at the top.

## Plumb idea

The intended Plumb experience is a fitness coach on iPhone and Apple Watch. Prop your phone up once per exercise: the camera checks your posture and execution on every rep, while the Watch tracks reps, tempo, and effort, can tap your wrist when a validated issue appears, and can display real-time advice. iPhone and Apple Watch are the core of this vision. The goal is to give appropriate, exercise-specific posture advice: identify the movement seen, explain the observation in plain language, and suggest one action the person can try on the next rep or set. Deliver that advice as early as the evidence allows, then keep the workout's data in the app so the person can track progress. A first Watch companion that mirrors the iPhone's count is written but not yet in the build (see [Current state](#current-state)); Watch tracking of reps, tempo, and effort is planned.

Apple Foundation Models may help phrase validated observations on eligible devices; the coaching facts come from camera pose analysis and exercise-specific rules, with a non-generative fallback. The product is designed to say when the view is too weak to support a cue.

We want Plumb to use as much of Apple's ecosystem as it can, with each device doing the job it is best at.

- **AirPods** can deliver corrections directly to your ears. Motion-capable models may also provide head-motion data for a future, exercise-specific compensatory-movement check; whether that signal is useful and reliable needs device and coach validation. The countdown, each rep, live observations and the post-set observation already use the current audio output, including paired AirPods. [Apple's headphone motion API](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager) requires an availability check and motion permission.
- **iPhone Duo** could stand on its own for camera placement; that setup still needs testing. [Apple describes its hands-free standing design](https://www.apple.com/iphone-duo/).
- **Apple TV:** working out in the living room. The iPhone analyzes its live camera feed, and the feedback could appear on the TV.

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

**In one sentence:** an iPhone-only app that analyzes one selected exercise at a time from the side, counts reps live and says them, and gives at most one supported posture or range observation after the set. It has not yet been tested on a real iPhone with real people.

**What the app does**

- Four exercises, filmed from the side: bodyweight squat, push-up, static lunge, stiff-leg deadlift.
- Hands-free sets (new on 13 October, on by default, switch in Options): the phone stands a few steps away. The countdown starts once you hold still in position (a plank for push-ups); the set ends when you walk back to the phone or stop moving after your reps. Only the set is measured, not the walk to your spot and back. Start set and Stop set still work. The screen stays on while the camera is open.
- Before the set: live camera view with the tracked skeleton, the joint Plumb cannot see clearly ("Ankle not clear"), and framing tips, said aloud hands-free.
- During the set: the reps counted so far, large on screen and said aloud through AirPods or other headphones when connected, otherwise the speaker; a rep clearly faster or shorter than your first reps of the set is pointed out once.
- After the set: a rep count and at most one observation with a suggested next action when the evidence supports it. Alongside range consistency, it can flag a change in torso tilt (squat or lunge), hip alignment (push-up), or knee bend (stiff-leg deadlift) relative to the person's first reps. These are observations of change, not a verdict on ideal posture or safe technique. Otherwise, it says there is no clear pattern or explains why to retake, with advice matched to the reason. The deepest and shallowest reps are drawn from their pose points.
- Your most frequent pattern (new on 13 October): each saved set lists what it showed (movements too shallow to count, too fast or slow, an unfinished last rep, a shorter range or a posture change at the end, reps faster than the first ones, an angled view). The pattern that comes back in your recent sets of an exercise is shown before the next one, and the result says when it returns.
- Compares a set with the latest compatible earlier set of the same exercise, keeps a local history, and shares a result as text.
- Reads the observation aloud on tap, through the iPhone speaker or AirPods.
- Optional: Apple Intelligence can reword the comparison. If it is unavailable or fails, a pre-written sentence is shown.
- Video is analyzed on the iPhone and never saved. The app ships a privacy manifest (no tracking, no collected data).

**How it avoids wrong answers**

- Checks that the person is filmed from the side (Vision 3D). A slight angle gives a placement tip; facing the camera for several seconds refuses the set.
- Checks that every detected joint lies on the person's silhouette, so a hidden ankle is not invented. Since 13 October the check searches in proportion to the body and ignores an empty mask; the first version also rejected visible ankles and wrists.
- Follows one athlete and ignores other people in view. Only someone standing in front of the athlete excuses a gap of up to 3 s; a lone athlete lost for a moment (getting into a push-up) is picked up again.
- Optional: recognizes the exercise automatically and keeps the user's choice when unsure.
- Posture advice requires clear supporting joints, a sufficiently side-on view when 3D angle is available, and comparable rep range; it abstains when those conditions are not met.

**Not proven yet**

- Tested only in the simulator, on generated videos, on public videos (earlier versions), and, for the analysis logic, on synthetic walk-in, walk-out, occlusion and wobble traces in a Linux build of the same Swift files. No run yet on a physical iPhone across lighting, clothing, and camera angles: hands-free start and stop, spoken reps, landscape display and heat handling are untested on a device.
- The changes of 13 October afternoon on branch `claude/adoring-wozniak-u81oz1` (hands-free, set window, silhouette search, frequent pattern, privacy manifest) have not yet been built in Xcode: the GitHub push from the cloud session was refused, so the iOS CI has not run them.
- Four baseline generated test videos cover six clear squats, no movement, hidden legs, and covered feet. Five variants probe light, distance, tempo, and facing direction; the mirrored clip asked for a retake before the silhouette change. The recorded pose fixtures predate it. These tests are reproducible but do not establish accuracy on real people.
- No qualified trainer has reviewed the coaching observations.
- Posture-change thresholds have only simulator and synthetic-pose coverage; their usefulness and false-cue rate need physical-iPhone and trainer review.
- The silhouette check has not yet been measured on the public videos.

**Written, not in the build yet:** an Apple Watch companion (`Plumb/PlumbWatch`, `Accessories.swift`, `WatchBridge.swift`). It would show the exercise, stage, live rep count and observations, tap the wrist on each rep, and start or stop the set from the wrist. Its messages and set mirroring are unit-tested. The Xcode target is a separate commit (`adcbd89`, branch `worktree-agent-a5251f6fe2375b37d`) because it needs the watchOS 27 platform and a watch app icon; until it is added, the iPhone app does not talk to a watch. See `docs/design/apple-watch-and-airpods.md`.

**Not built:** Apple Watch measurement (wrist motion, heart rate, HealthKit workout session), Apple TV, AirPods head tracking, widgets, Live Activities, accounts, subscriptions, running analysis (see `docs/product/running-stride.md`).

**Challenge goal:** a reliable iPhone loop and a build submitted through App Store Connect. Public release depends on validation and distribution access.

_For developers:_ each exercise is defined in `ExerciseDefinition.swift` (rule versions `squat-side-v7` and `*-side-v6`, which combine main's posture readings with the set window and capture fixes); the set window is `SetWindow.swift`, hands-free and live reps `LiveSet.swift`, the frequent pattern `MistakeProfile.swift`, and what headphones and the Apple Watch add `Accessories.swift`. Generated test videos are in `tools/replay`.

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
- `docs/design/apple-watch-and-airpods.md`: what the Apple Watch and AirPods add per exercise, the iPhone-watch messages, how to test on devices, and what is not done
- `planning.md`: experience, scoped MVP, technical approach, privacy, validation, and timeline
- `docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`: task-by-task plan for the first real iPhone squat session
- `docs/validation/squat-v1-protocol.md`: consent, physical-device test, annotation, and claim gates
- `docs/validation/physical-iphone-run.md`: step-by-step device smoke run when the iPhone is available, including hands-free sets
- `docs/product/running-stride.md`: what Plumb could measure for running (Watch metrics, treadmill camera) and in what order
- `docs/validation/squat-v1-results.md`: actual results status; no real sets collected yet
- `docs/validation/exercise-rules-v1.md`: push-up, lunge, and deadlift rules, the set window, hands-free timings, the frequent-pattern rule, the 3D camera-angle check, and what each still needs on a physical iPhone
- `tools/replay/README.md`: generated simulator sets for every exercise, missing-joint refusal, and Mac replay of a saved video through Vision and the production analyzer
- `tools/exercise-classifier/README.md`: clip format, labeling, Create ML training, and installing the exercise classifier
- `docs/release/app-store-submission.md`: release checks and App Store Connect status
- [Public support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html): live pages for the current iPhone candidate
- `docs/release/app-privacy-answers.md`: source-backed draft of App Store privacy answers for the current iPhone build
- `docs/product/brief.md`: supporting feature order and result-language boundaries; this README owns the product direction and current-state summary
- `docs/README.md`: document map by purpose
- `docs/product/rationale.md`: why a focused camera technique companion is worth testing
- `docs/product/market-research.md`: primary-source alternatives and customer research plan
- `docs/product/pitch.md`: three-minute story, demo path, and claim boundaries
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

The capture screen shows the live rep count and an elapsed clock while a set is active. For repeatable development testing, the Debug build has generated six-rep fixtures for all four exercises and a missing-wrist case. The fixtures test app behavior without doing a workout; they do not validate pose detection or coaching accuracy on real people. See the replay guide for simulator commands and saved-video analysis on a Mac.
