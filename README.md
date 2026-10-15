# Plumb

> **TL;DR · 15 October 2026**
>
> - **Source of truth.** Keep it accurate.
> - **Idea:** iPhone + Apple Watch fitness coach that checks every rep and gives actionable posture/execution advice. Track progress and workouts.
> - **Today (iPhone only):** 6 exercises (4 side-view: squat, push-up, lunge, stiff-leg deadlift; pull-ups & muscle-ups any view) with live rep counting + limited evidence-linked posture/range advice after sets. Hands-free sets with live count on screen and audio (AirPods/speaker). Most frequent pattern shown before each set. Optional Apple Health workout saving (written, unit-tested, unbuilt/untested on iPhone). Optional Personalize with Health: reads HR, recovery, sleep, activity, age, weight, height to suggest lighter days, adapt rest, show set HR from Watch; each tip names its data.
> - **In build, not on watch:** Watch companion mirrors iPhone count, taps wrist per rep (target `PlumbWatch`, embedded since 13 Oct).
> - **In build, not on iPhone yet (15 Oct):** home screen widget with the last measured set and a tap that opens the camera; Live Activity counting the set on the Lock Screen and in the Dynamic Island (target `PlumbWidgets`).
> - **Home (15 Oct):** photographic dashboard and glass tab bar; Workout keeps the existing set flow, Coach opens the saved-set conversation.
> - **Not built:** Watch wrist-motion, Apple TV, AirPods head tracking.

## Rules for AI agents & contributors

1. **Start here.** If a file disagrees, follow README and flag the conflict. Don't "correct" README to match older docs.
2. **Built means built.** Never describe a feature as working unless [Current state](#current-state) says so. Everything else is planned.
3. **Keep this file true.** When built state or product direction changes, update README in the same commit: TL;DR, Current state, and date.

## Plumb idea

Fitness coach on iPhone + Apple Watch. Prop phone once per exercise: camera checks posture/execution every rep; Watch tracks reps, tempo, effort, taps wrist on validated issues, shows real-time advice. Goal: exercise-specific posture advice—identify movement, explain observation plainly, suggest one action for next rep/set. Deliver advice as early as evidence allows; keep workout data for progress tracking.

Apple Foundation Models may phrase validated observations on eligible devices; coaching facts come from camera pose analysis + exercise-specific rules, with non-generative fallback. Says when view is too weak for a cue.

Use Apple ecosystem fully, each device doing what it's best at:

- **AirPods:** deliver corrections to ears. Motion-capable models may provide head-motion data for future compensatory-movement checks (needs validation). Countdown, reps, live observations, post-set observation already use current audio output including AirPods. Requires availability check + motion permission.
- **iPhone Duo:** could stand alone for camera placement; needs testing.
- **Apple TV:** living room workouts. iPhone analyzes live camera; feedback on TV.

Long term: same approach for gym, home workouts, treadmill running.

**Plumb is a fitness aid. Not medical advice. Does not guarantee safe technique.**

## Build goals

- **Great product:** solves real problem, integrated across iPhone, Watch, iPhone Duo, Apple TV + widgets/Live Activities, value visible in first second.
- **Monetization & acquisition** designed from day one.
- **Astonishing UX/UI:** Liquid Glass (restrained), smooth, fast.
- **Smart technology underneath.**

## Current state

_Updated 15 October 2026._

**In one sentence:** iPhone-only app analyzing one selected exercise at a time from the side, counting reps live with audio, giving ≤1 supported posture/range observation after set. **Not tested on real iPhone with real people.**

### What the app does

- **6 exercises:** 4 side-view (bodyweight squat, push-up, static lunge, stiff-leg deadlift). Pull-ups & bar muscle-ups from side/front/back: rep counts when shoulders rise >½ arm length (above hands for muscle-up); result shows chin vs hands, straight arms at hang, body swing. Synthetic tests + 1 real 2-rep clip only.
- **Home dashboard (new 15 Oct):** photographic Home screen with glass cards and Home, Posture, Coach, Workout tabs. Last workout and Sessions open saved history; Account settings links to Options, History and Privacy. Workout retains the animated exercise setup, exercise chips and **Start a set** flow. Coach opens the saved-set conversation; Posture, Weights, Awards and Plumb+ show “Not made yet.”
- **Hands-free sets (new 13 Oct, on by default, toggle in Options):** phone stands a few steps away. Countdown starts when you hold still in position (plank for push-ups); set ends when you walk back or stop moving after reps. Only set measured, not walk to/from spot. Start/Stop still work. Screen stays on while camera open; auto-closes after 3 min no set, or 1 min no person in view; announces when nobody seen.
- **Before set:** live camera + tracked skeleton, unclear joint ("Ankle not clear"), framing tips (spoken hands-free).
- **During set:** rep count large on screen + spoken via AirPods/headphones/speaker; exercise named ("5 push-ups"); choice persists across launches. One alert for rep clearly faster/shorter than first reps. If set refused for chosen exercise's joints but clearly shows another exercise's reps, result says so ("Plumb counted 5 push-ups, but Squat was chosen").
- **After set:** rep count + ≤1 observation with suggested action when evidence supports. Beyond range consistency: flags torso tilt change (squat/lunge), hip alignment (push-up), knee bend (stiff-leg deadlift) vs first reps. Observations of change, not verdict on ideal/safe posture. Otherwise: no clear pattern or retake reason with matched advice. Deepest/shallowest reps drawn from pose points. If joints clear only 65–80% of set (80% needed for advice): keeps reps seen, names unclear joint, no posture advice/comparison; saved as partial.
- **Most frequent pattern (new 13 Oct):** each saved set lists patterns (shallow reps, too fast/slow, unfinished last rep, shorter range, posture change at end, faster reps, angled view). Recurring pattern in recent sets shown before next one; result notes when it returns.
- **Comparison & history:** compares set with latest compatible earlier set of same exercise; keeps local history; shares result as text.
- **Apple Fitness (new 13 Oct, off by default, toggle in Options):** on Done after set or Finish session (shown when Cancel/leaving app ended set without Done, also after iOS closed Plumb since open session kept in saved history), saves session to Apple Health as one functional strength training workout → appears in Fitness app history + Health (unseen on device). Workout: first measured rep to end of last set (breaks >5 min paused); carries set count, measured reps, exercise names; never calories/HR (Plumb doesn't measure). Asks Health only for workout write permission when enabled; reads nothing. Set >30 min after previous starts new session; earlier saved then. Each session saved once; failed save retryable from first screen/History (marks saved sessions). Deleting in Plumb leaves Health workout; delete dialogs say so. Demo/recorded input never saved.
- **Personalize with Health (new 13 Oct, off by default):** offered once after first measured set ("Make Plumb more personal?" Yes/Later); switchable in Options listing each Health type + use. When on: iOS asks to read HR, resting HR, HRV, VO2 max, workouts, active energy, steps, sleep, DOB, weight, height. First screen suggests lighter session after short night, heavy day, or resting HR above weekly average; result adds set HR (Watch), rest suggestion (longer when less recovered or HR to wait for), rep load from body weight, squat depth in cm from height. Each line names its data. Coaching only, never diagnosis; nothing stored/sent. Watch runs workout session only while iPhone camera open for HR, discards it so Fitness doesn't double-count. Rules in `HealthPersonalization.swift`, reading in `HealthKitReader.swift`, watch side in `Plumb/PlumbWatch/HeartRateSession.swift`. **Not tried on device.**
- **Reads observation aloud on tap** via iPhone speaker or AirPods.
- **Optional Apple Intelligence** rewords comparison; pre-written fallback if unavailable/fails.
- **Video analyzed on iPhone, never saved.** Privacy manifest: no tracking, no collected data.

### How it avoids wrong answers

- Checks side-on filming (Vision 3D). Slight angle → placement tip; facing camera several seconds → refuses set.
- Checks every detected joint lies on person's silhouette (no invented hidden joints). Since 13 Oct: search proportional to body, ignores empty mask; v1 also rejected visible ankles/wrists.
- Follows one athlete, ignores others. Only someone standing in front excuses gap ≤3 s; lone athlete lost momentarily (getting into push-up) picked up again. While framing: someone else takes over only when in full view + clearly more prominent for 1 s (passerby or partner with legs out of picture doesn't); still stranger in full view staying much more prominent can.
- **Optional:** auto-recognizes exercise; keeps user's choice when unsure. When sure it's another exercise, next sets use that (result says so).
- Coaching cues require sufficiently side-on view when 3D angle available. Diagonal view: retains rep count + camera-turn tip, withholds posture/range cues that might distort. Posture advice also needs clear supporting joints + comparable rep range.

### Not proven yet

- Tested only in simulator, generated videos, public videos (earlier versions), synthetic walk-in/walk-out/occlusion/wobble traces in Linux build of same Swift files. **No run on physical iPhone** across lighting, clothing, camera angles: hands-free start/stop, spoken reps, landscape display, heat handling untested.
- 13 Oct afternoon changes (branch `claude/adoring-wozniak-u81oz1`: hands-free, set window, silhouette search, frequent pattern, privacy manifest) build in Xcode iOS CI including Apple Fitness; 16 video replays give expected results. Second run: contrast failure on result screen (deepest/shallowest rep cards, failed in PR 10) + 3 session tests over 5s wait on slow simulator; both addressed, await next run.
- 13 Oct evening reliability fixes (hands-free start/stop, spoken counts, framing timeout, tracker, open session kept across relaunch, recognized exercise carried over, Back buttons, history saving) pass Linux logic build + tests only. SwiftUI lines (Back on camera errors/result, 2-min note, camera-closed line, hands-free hint) + person-mask change in `PoseFrameAnalyzer` **not built in Xcode or tried on iPhone**.
- Apple Fitness written against HealthKit docs; logic unit-tested with fake Health store in Linux build. **HealthKit code, capability, new screens not run on iPhone.** Unchecked: permission sheet, workout appearing in Fitness/Health, signing with HealthKit entitlement, Activity ring credit for iPhone workout duration.
- 16 generated test videos: clear squat, no movement, hidden legs/feet, 12 variants of light, size, framing, resolution, blur, apparent phone movement, tempo, facing direction. Pre-silhouette-search code: blur, phone shake, very small subject, mirrored clip asked for retake. New code (local macOS replay, 13 Oct): mirrored clip measures 6 reps; very small subject measures since reliability pass; strong blur, phone shake, no movement, hidden legs/feet still ask for retake. All variants reuse one source person/motion; **don't establish accuracy across real people**.
- No qualified trainer has reviewed coaching observations.
- Posture-change thresholds: only simulator + synthetic-pose coverage; usefulness/false-cue rate need physical iPhone + trainer review.
- Spot check of capture path on 11 public gym clips (several people, side/diagonal/front views). 4/9 squat clips + both push-up clips measured; 3 front-view squat clips refused. **No independent human count/cue review; selected sample can't establish accuracy.** [Replay details](docs/validation/exercise-rules-v1.md#current-capture-path-spot-check--13-october-2026).

### In build, not on physical watch

Apple Watch companion (`Plumb/PlumbWatch`, `Accessories.swift`, `WatchBridge.swift`): shows exercise, stage, live rep count, observations; taps wrist per rep; starts/stops set from wrist. Target `PlumbWatch` (watchOS 10+, bundle `com.james8464.Plumb.watchkitapp`) embedded in iPhone app → installing Plumb from Xcode on paired iPhone installs on watch. Messages + set mirroring unit-tested; both targets compile for simulators. See `docs/design/apple-watch-and-airpods.md`.

### In build, not on a physical iPhone: widgets and Live Activity (15 October)

Target `PlumbWidgets` (`com.finlearn.plumb.widgets`), embedded in the iPhone app. Home screen widget (small, medium): last measured set, exercise, reps, when, "partly visible" when it was; tap or **Start a set** opens Plumb on that exercise via `plumb://start-set`. No saved set: says so. Reads one JSON value in App Group `group.com.finlearn.plumb`, written only when a session is saved to local history (`Widgets/WidgetSharingSessionStore.swift`), never from demo/recorded input; no video, pose points or Health data leave the app. Live Activity (`Widgets/SetLiveActivity.swift`): starts with the set, counts reps + elapsed time on Lock Screen and Dynamic Island, ends with the set, locally (no push). Demo input labeled DEMO. Views in `Plumb/Widgets/WidgetViews.swift`, strings EN/FR in `PlumbWidgets/Localizable.xcstrings`. Sharing, deep link and activity rules unit-tested; simulator build embeds the extension. Unchecked: widget and activity on a real iPhone, App Group under the FinLearn team's provisioning.

### Not built

Watch wrist-motion measurement, Apple TV, AirPods head tracking, accounts, subscriptions, running analysis (see `docs/product/running-stride.md`).

### Challenge goal

Reliable iPhone loop + build submitted through App Store Connect. Public release depends on validation + distribution access.

### For developers

Each exercise in `ExerciseDefinition.swift` (rule versions `squat-side-v7`, `*-side-v6`, `pull-up-v1`, `muscle-up-v1` combining main's posture readings with set window + capture fixes); set window `SetWindow.swift`; hands-free/live reps `LiveSet.swift`; frequent pattern `MistakeProfile.swift`; headphones/Watch `Accessories.swift`; Apple Health workout `FitnessWorkout.swift` (logic) + `HealthKitWorkoutExporter.swift` (HealthKit calls; entitlements in `Plumb/Plumb.entitlements`). Generated test videos in `tools/replay`.

Project for October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F.

## Rules that always apply

- **No medical claims.** Never claim injury prevention, diagnosis, or guaranteed safe technique.
- **AI phrases, never decides.** Language models only reword measured facts.
- **Permissions in context.** Camera at camera setup; Health data only when Health feature used.
- **Privacy.** Video stays on device, not saved. Changing that needs explicit user choice + updated privacy policy.
- **Honest demos.** Label synthetic/recorded input. Never present as live tracking.

## Documents

- `Design/README.md`: brand theme, colors, typography, icon, live Figma guide
- `docs/design/iphone-experience-review.md`: iPhone interface decisions tied to Apple guidance + Design Award examples
- `docs/design/apple-watch-and-airpods.md`: Watch/AirPods per exercise, iPhone-Watch messages, device testing, not-done
- `docs/design/apple-hig-agent-reference.md`: local, searchable Apple HIG page index and design checks for agents
- `planning.md`: experience, scoped MVP, technical approach, privacy, validation, timeline
- `docs/superpowers/plans/2026-10-11-plumb-iphone-squat-mvp.md`: task-by-task plan for first real iPhone squat session
- `docs/validation/squat-v1-protocol.md`: consent, physical-device test, annotation, claim gates
- `docs/validation/physical-iphone-run.md`: step-by-step device smoke run incl. hands-free sets
- `docs/product/running-stride.md`: Watch metrics, treadmill camera for running, order
- `docs/validation/squat-v1-results.md`: actual results status; no real sets collected yet
- `docs/validation/exercise-rules-v1.md`: push-up/lunge/deadlift rules, set window, hands-free timings, frequent-pattern rule, 3D camera-angle check, per-exercise physical iPhone needs
- `tools/replay/README.md`: generated simulator sets for all exercises, missing-joint refusal, Mac replay of saved video through Vision + production analyzer
- `tools/exercise-classifier/README.md`: clip format, labeling, Create ML training, classifier install
- `docs/release/app-store-submission.md`: release checks + App Store Connect status
- [Public support](https://james8464.github.io/hackathon-project/support.html) & [privacy policy](https://james8464.github.io/hackathon-project/privacy.html): live pages for current iPhone candidate
- `docs/release/app-privacy-answers.md`: source-backed draft App Store privacy answers
- `docs/product/brief.md`: feature order + result-language boundaries; README owns product direction + current-state summary
- `docs/README.md`: document map by purpose
- `docs/product/rationale.md`: why focused camera technique companion worth testing
- `docs/product/market-research.md`: primary-source alternatives + customer research plan
- `docs/product/user-needs.md`: what people need from Plumb, ranked with sources (13 Oct research), outcomes
- `docs/product/pitch.md`: 3-min story, demo path, claim boundaries
- `Plumb/GIT guide.md`: team's `main` branch workflow

## Team

- James
- Klaus
- Theophile
- Guilhem

## Open the iPhone project

1. Clone repo, switch to `main`.
2. Open `Plumb/Plumb.xcodeproj` in Xcode.
3. Choose iPhone simulator or connected iPhone, build `Plumb` scheme.

Layered Icon Composer source: `Plumb/Plumb/AppIcon.icon`. Flat marks + preview in `Plumb/BrandArtwork`.

Capture screen shows live rep count + elapsed clock during active set. Debug build has generated 6-rep fixtures for all 4 exercises + missing-wrist case for repeatable dev testing (tests app behavior, not pose detection/coaching accuracy on real people). See replay guide for simulator commands + saved-video analysis on Mac.