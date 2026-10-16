# Finn

Finn reviews strength sets through your iPhone camera. It counts reps and, when the evidence supports it, gives one specific observation to try on the next set. Video is processed on the phone and is not saved. The longer-term product pairs iPhone with Apple Watch for timely feedback.

| Status | Details |
|--------|---------|
| **Date** | 15 October 2026 |
| **Coverage** | Simulator + replay |
| **Device testing** | Development-signed build launched on iPhone 16 Pro Max; live camera opened after permission |
| **Gaps** | No real-person set or independent expert review of coaching accuracy |
| **Classification** | Fitness aid — **not** a medical or injury-prevention tool |

---

## Current Build

### Workout

Choose one of six exercises:

| Rule set | Exercises |
|----------|-----------|
| **Side-view** | Squat, push-up, static lunge, stiff-leg deadlift |
| **Shoulder-movement** | Pull-ups, bar muscle-ups |

The camera shows framing and a pose overlay, counts reps live, and supports manual or hands-free sets. Counts and selected observations can be spoken through the system audio route.

### Results

Each set shows a measured count and **at most one** supported range or posture observation. Weak evidence produces a retake reason or "no supported pattern." Partial sets can retain a count without posture advice.

> **Note:** A squat whose knee and ankle Vision cannot read often enough (phone on the floor, feet at the picture's edge, person turning or stepping out of view and back) is counted from the hips going down and up, without posture advice; a front view is counted the same way, with a tip to turn (15 October).

Side-view form checks produce an observation when a fault appears on **at least two reps**:

| Exercise | Form checks |
|----------|-------------|
| Push-up | Hips and depth |
| Squat | Depth and chest |
| Lunge | Torso and front knee |
| Deadlift | Knees and hinge |

A few words of the same advice appear large on the camera screen during the set. A check that cannot see its joints says so.

History stores local summaries, compares compatible sets, identifies a recurring pattern, and shares text through the system sheet.

### Interface and Coach

The Home, Posture, Coach and Workout tabs keep their navigation state. Home shows recent sessions, measured progress and awards. Posture shows looping illustrated exercise movements, short cues and comparisons with eligible saved measurements. The illustrations are guidance, not validated video of a person. System text and adaptive layouts support larger text. See the [design research](docs/architecture/specs/2026-10-15-native-ui-design.md) and [HIG review](docs/design/hig-ui-coverage.md).

First launch asks for a goal, experience level, favourite exercises, and spoken feedback preference; these choices stay on the iPhone. Awards mark measured milestones, including a set with no pattern flagged by Finn's current checks; they do not certify perfect form.

Coach uses Apple Intelligence, when available, to select up to two relevant saved sets. The selected goal and level can guide that selection; Finn writes the displayed response from recorded counts and observations. Invalid model output and unavailable models use fixed text. A Claude demo is Debug-only. Source information is available beside the composer. Finn+ stays hidden until its subscription exists.

### Apple Watch

An embedded companion mirrors the exercise, stage, count, and observation. It supports wrist taps and start/stop messages. It compiles for simulators but **has not been checked on a physical watch**.

### Apple Health

Optional workout saving and optional personalization are implemented in code. Personalization may read heart rate, activity, sleep, and body measurements after permission. HealthKit permission, workout appearance in Fitness, and personalized advice still need physical-device checks. Camera use does not require Health access.

### Siri and Shortcuts

App Intents can start a selected set, report the last saved set, or open History. Unit and simulator checks exist; spoken use on a device remains unverified.

### Widgets and Live Activities

The embedded extension shows the last measured set and can open the camera on its exercise. A local Live Activity shows count and elapsed time during a set. Shared data contains a saved-set summary — not video or Health data. Unit tests and a simulator build exist; App Group provisioning and the experience on a physical iPhone remain unchecked.

### Distribution setup

| Item | Detail |
|------|--------|
| Bundle ID | `ai.mwm.build.challenge.team.08` |
| Apple Developer team in the project | `2FN6Y5NHS5` |
| Analytics SDK | None in the checked-in project |
| StoreKit catalog and paywall | Not implemented |
| Privacy draft | [docs/release/app-privacy-answers.md](docs/release/app-privacy-answers.md) — review against the final signed archive before publication |

If the team adopts MWM signing or an SDK, update the code and privacy documents before submission.

---

## Evidence and Limits

Automated checks cover Swift logic, simulator flows, and generated video replays; the [15 October automated report](docs/validation/automated-checks-2026-10-15.md) records current passes and failures. A small public-video spot check has no independent rep or cue annotation. No consenting, varied-person test set or qualified trainer review has established:

- Rep-count accuracy
- Cue quality
- Lighting tolerance
- Battery cost
- Hands-free reliability on real devices

See the [validation protocol](docs/validation/squat-v1-protocol.md), [results](docs/validation/squat-v1-results.md), [exercise rules](docs/validation/exercise-rules-v1.md), and [form checks](docs/validation/form-checks-v1.md) — whose squat and push-up limits were checked against a labeled public set of good and bad side-view videos.

The app checks visibility, viewpoint, and which person it follows before giving advice. A live count can still precede a final retake when the end-of-set evidence gate rejects a set.

> **Important**
>
> - **Do not** present synthetic or recorded input as a live camera result.
> - **Do not** claim that Finn diagnoses injury risk, proves safe form, or replaces a trainer.

---

## Product Direction

The next gate is a dependable iPhone set-to-set loop on physical devices, with expert-reviewed cues. Apple Watch timing and haptics can then be tested against camera-only analysis. Widgets and Live Activities need device and provisioning checks. AirPods head motion, iPhone Duo placement, Apple TV, running analysis, accounts, subscriptions, and a paid model need separate evidence and design.

---

## For Contributors and Agents

| Rule | Description |
|------|-------------|
| **Keep status current** | Update this README's build status when behavior changes. Flag discrepancies with older plans. |
| **Facts from rules** | Derive coaching facts from measured, versioned rules. The Coach model may select saved sets, but its prose is never shown. Models must not decide whether movement is safe. |
| **Permissions in context** | Ask for camera and Health permissions in context. Keep workout video local and unsaved. Changing data handling requires a deliberate product and privacy-policy update. |
| **Label demo data** | Keep public copy aligned with the signed build and its validation. |
| **Apple interface work** | Use the [local HIG reference](docs/design/apple-hig-agent-reference.md) and its official source links. |

---

## Open the Project

```bash
# 1. Open the project
open Finn/Finn.xcodeproj

# 2. Select the scheme and destination
# Scheme: Finn
# Destination: Simulator or connected iPhone

# 3. Build and run (⌘R)
```

The checked-in project signs with team `2FN6Y5NHS5`; device builds require that team's provisioning for the app, Watch, widget, HealthKit, and App Group capabilities. A separate development-signed build under James's team has been installed and launched on an iPhone 16 Pro Max.

| Resource | Link |
|----------|------|
| Document map | [docs/README.md](docs/README.md) |
| Detailed plan | [planning.md](planning.md) |
| Git workflow | [Finn/GIT guide.md](Finn/GIT%20guide.md) |

---

Built for the October 2026 Build Challenge by James, Klaus, Theophile, and Guilhem.
