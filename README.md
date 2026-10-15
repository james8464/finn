# Plumb

Plumb reviews strength sets through your iPhone camera. It counts reps and, when the evidence supports it, gives one specific observation to try on the next set. Video is processed on the phone and is not saved. The longer-term product pairs iPhone with Apple Watch for timely feedback.

**Status — 15 October 2026**  
The iPhone flow has simulator and replay coverage. A development-signed build launched on an iPhone 16 Pro Max and opened the live camera after permission; no real-person set or independent expert review has established coaching accuracy. Treat Plumb as a fitness aid — not a medical or injury-prevention tool.

---

## Current Build

### Workout
Choose one of six exercises:
- **Side-view rules** — Squat, push-up, static lunge, stiff-leg deadlift
- **Shoulder-movement rules** — Pull-ups, bar muscle-ups

The camera shows framing and a pose overlay, counts reps live, and supports manual or hands-free sets. Counts and selected observations can be spoken through the system audio route.

### Results
Each set shows a measured count and at most one supported range or posture observation. Weak evidence produces a retake reason or "no supported pattern." Partial sets can retain a count without posture advice.

A squat whose knee and ankle Vision cannot read often enough (phone on the floor, feet at the picture's edge, person turning or stepping out of view and back) is counted from the hips going down and up, without posture advice; a front view is counted the same way, with a tip to turn (15 October).

Side-view form checks (push-up hips and depth, squat depth and chest, lunge torso and front knee, deadlift knees and hinge) produce an observation when a fault appears on at least two reps. A few words of the same advice appear large on the camera screen during the set. A check that cannot see its joints says so.

History stores local summaries, compares compatible sets, identifies a recurring pattern, and shares text through the system sheet.

### Home and Coach
The Home dashboard links to recent sessions and the Workout flow. Coach uses Apple Intelligence, when available, to select up to two relevant saved sets; Plumb writes the displayed response from their recorded counts and observations. Invalid model output and unavailable models use fixed text. (A Claude demo is Debug-only.) Posture, Weights, Awards, and Plumb+ destinations are placeholders.

### Apple Watch
An embedded companion mirrors the exercise, stage, count, and observation. It supports wrist taps and start/stop messages. It compiles for simulators but has not been checked on a physical watch.

### Apple Health
Optional workout saving and optional personalization are implemented in code. Personalization may read heart rate, activity, sleep, and body measurements after permission. HealthKit permission, workout appearance in Fitness, and personalized advice still need physical-device checks. Camera use does not require Health access.

### Siri and Shortcuts
App Intents can start a selected set, report the last saved set, or open History. Unit and simulator checks exist; spoken use on a device remains unverified.

### Widgets and Live Activities
The embedded extension shows the last measured set and can open the camera on its exercise. A local Live Activity shows count and elapsed time during a set. Shared data contains a saved-set summary — not video or Health data. Unit tests and a simulator build exist; App Group provisioning and the experience on a physical iPhone remain unchecked.

### MWM Setup
The app uses the team-08 bundle ID and bundled Spark Flash SDK. Debug builds use MWM's sandbox key; Release builds use its production key. Spark records app opens and StoreKit transaction updates. Xcode's shared `Plumb` scheme uses the supplied local StoreKit catalog with six subscription products. There is no paywall or direct purchase flow yet. The updated [privacy draft](docs/release/app-privacy-answers.md) lists Spark's data categories; publish the matching privacy page before App Store submission.

---

## Evidence and Limits

Automated checks cover Swift logic, simulator flows, and generated video replays; the [15 October automated report](docs/validation/automated-checks-2026-10-15.md) records current passes and failures. A small public-video spot check has no independent rep or cue annotation. No consenting, varied-person test set or qualified trainer review has established rep-count accuracy, cue quality, lighting tolerance, battery cost, or hands-free reliability on real devices. See the [validation protocol](docs/validation/squat-v1-protocol.md), [results](docs/validation/squat-v1-results.md), [exercise rules](docs/validation/exercise-rules-v1.md), and [form checks](docs/validation/form-checks-v1.md) — whose squat and push-up limits were checked against a labeled public set of good and bad side-view videos.

The app checks visibility, viewpoint, and which person it follows before giving advice. A live count can still precede a final retake when the end-of-set evidence gate rejects a set.

> **Do not** present synthetic or recorded input as a live camera result.  
> **Do not** claim that Plumb diagnoses injury risk, proves safe form, or replaces a trainer.

---

## Product Direction

The next gate is a dependable iPhone set-to-set loop on physical devices, with expert-reviewed cues. Apple Watch timing and haptics can then be tested against camera-only analysis. Widgets and Live Activities need device and provisioning checks. AirPods head motion, iPhone Duo placement, Apple TV, running analysis, accounts, subscriptions, and a paid model need separate evidence and design.

---

## For Contributors and Agents

- Keep this README's build status current when behavior changes. If an older plan conflicts with it, flag the discrepancy.
- Derive coaching facts from measured, versioned rules. The Coach model may select saved sets, but its prose is never shown. Models must not decide whether movement is safe.
- Ask for camera and Health permissions in context. Keep workout video local and unsaved. Changing data handling requires a deliberate product and privacy-policy update.
- Label demo data. Keep public copy aligned with the signed build and its validation.
- For Apple interface work, use the [local HIG reference](docs/design/apple-hig-agent-reference.md) and its official source links.

---

## Open the Project

Open [Plumb.xcodeproj](Plumb/Plumb.xcodeproj) in Xcode and run the `Plumb` scheme on a simulator or connected iPhone. Device signing requires access to the MWM Apple Developer team (`ZUQ3ZP29N4`) and provisioning for the app, Watch, widget, HealthKit, and App Group capabilities.

The [document map](docs/README.md) links design, validation, product, and release material; [planning.md](planning.md) records the earlier detailed plan. The [Git guide](Plumb/GIT%20guide.md) describes the team's `main` workflow.

---

Built for the October 2026 Build Challenge by James, Klaus, Theophile, and Guilhem.