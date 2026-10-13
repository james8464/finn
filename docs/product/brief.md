# Plumb · product brief

**Supporting product brief · 13 October 2026.** [The README](../../README.md) is the source of truth for the product direction and current state. This page expands its result boundaries and feature order; [planning.md](../../planning.md) owns technical and validation detail. Align public release copy with the *shipped* build.

## Purpose and audience

People training alone often cannot see how their own movement changes through a set. Reviewing a video takes time and still leaves the interpretation to them. Plumb turns a short, camera-visible movement into one bounded observation they can check in the next set.

The first audience is a self-directed iPhone user doing basic strength work at home or in a gym. The intended full experience pairs iPhone camera analysis with Apple Watch rep timing, effort context, discreet haptics, and timely, validated advice. The expansion includes treadmill runners, whose continuous movement needs a different session and analysis design. Qualified trainers help validate coaching cues; a trainer account is not part of the README's product scope.

**Current product loop:** choose an exercise → place the iPhone → analyze live without saving video → review at most one supported finding, no clear pattern, or a retake reason → try another set → compare the same measured signal. No account or accessory is required for this iPhone build.

## What a result means

| Outcome | What Plumb says | Evidence needed |
| --- | --- | --- |
| Shorter observed range | The later reps had a smaller measured range; one next-set action appears. | At least four measured reps, a sufficient view, and the exercise's versioned range rule. |
| No supported pattern | Plumb has no specific range finding for this set. | A measurable set with no rule supported. |
| Retake | The view or movement cannot support a measured result. | Missing/weak joints, wrong view, interruption, or incomplete movement. |
| Analysis failed | Plumb could not complete the set analysis and offers a retry. | A capture or processing error; do not present this as a movement finding. |

A single side camera cannot check every joint, force, load, pain, or personal constraint. The UI must not certify perfect or safe technique. A qualified coach and real-person holdout must review any new technique claim before release.

## Features and sequence

| Priority | Feature | Current state / next decision |
| --- | --- | --- |
| Now | iPhone side-view squat, push-up, static lunge, and stiff-leg deadlift; rep analysis, evidence gate, one observation, history, comparison, text sharing | Implemented with simulator and synthetic video checks; real-person accuracy remains unvalidated. |
| Before release | Physical iPhone validation, cue review, accessibility, privacy and signing checks | Test consented sets across people, views, clothing, light, and occlusion. Suppress claims that miss the [validation gates](../../planning.md#6-validation-and-success-measures). |
| Core product expansion | Apple Watch workout session, rep timing, tempo, effort context, and discreet haptics | Watch is central to the intended iPhone + Watch experience, but absent from this build. Prototype after the iPhone loop is dependable; compare sensor-assisted timing with camera-only analysis before claiming an improvement. |
| Next movement | Treadmill running | Research safe camera placement and a running-specific, expert-reviewed gait signal. Begin with post-run feedback; do not reuse strength rep thresholds. |
| Full product | Timely live cues, including Watch haptics and optional AirPods audio | Central to the vision; release only when tracking confidence, latency, coach review, and distraction testing support the particular cue. |
| Later surfaces and business | iPhone Duo placement, Apple TV display, widgets, Live Activities, and a tested monetization model | These are named in the README but are not current features or submission claims. |

## Apple platform choices

- **Vision + AVFoundation:** on-device pose from a live frame sequence; confidence, occlusion, viewpoint, and the full movement matter more than a single image. [Vision reports joint positions and confidence](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images), rather than an overall technique verdict.
- **Foundation Models:** optional language for a structured, already validated comparison, with reviewed deterministic wording whenever generation is unavailable or invalid. It never decides whether a rep is safe.
- **AirPods:** audio output for a user-requested observation works today through the system route. Head-motion-assisted movement checks are planned and need availability, permission, timing, and coaching validation; headphones do not currently measure form for Plumb.
- **Apple Watch:** core to the intended paired experience, currently unbuilt. Workout context, timing, and haptics come first; any camera/watch sensor fusion needs synchronized, paired-device tests.
- **iPhone Duo and Apple TV:** proposed placement and living-room display surfaces, respectively; neither is implemented or validated.
- **Native UI:** system typography, controls, accessibility, and quiet black/white branding from the [brand guide](../../Design/README.md). The measured fact and next action should remain the focus. Apple's [feedback guidance](https://developer.apple.com/design/human-interface-guidelines/feedback) favors passive status for information a person can glance at, and its [workout guidance](https://developer.apple.com/design/human-interface-guidelines/workouts) cautions against distracting information during activity. The current camera view shows framing and set controls, not coaching prompts.

## How we decide whether it works

The first success event is a user reaching a trustworthy measured result, understanding why it appeared, and choosing a feasible next-set action. Track setup success within two tries, rep-count agreement with annotated sets, expert agreement on emitted cues, result latency, second-set completion, and user trust. Report how often the app abstains alongside cue agreement; silence alone is not a useful product. Targets and the collection protocol live in [planning.md](../../planning.md) and [validation](../validation/squat-v1-protocol.md). No real-person accuracy or retention result is claimed today.

## Supporting documents

- [Product rationale](rationale.md): why the problem and approach matter.
- [Market research](market-research.md): alternatives, positioning questions, and research plan.
- [Pitch](pitch.md): a three-minute story constrained to the implemented build.
- [Release documents](../release/): public copy and submission gates; they must describe the final signed build rather than this roadmap.
