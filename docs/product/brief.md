# Plumb · product brief

**Working product definition · 13 October 2026.** This page is the source of truth for what Plumb is, what each result can claim, and the order of product work. [planning.md](../../planning.md) owns technical and validation detail; [the README](../../README.md) is the quick project entry point. Revise this brief when the product promise changes, then align release copy with the *shipped* build.

## Purpose and audience

People training alone often cannot see how their own movement changes through a set. Reviewing a video takes time and still leaves the interpretation to them. Plumb turns a short, camera-visible movement into one bounded observation they can check in the next set.

The first audience is a self-directed iPhone user doing basic strength work at home or in a gym. The intended expansion includes treadmill runners, whose continuous movement needs a different session and analysis design. A trainer may later review a person's shared result or opted-in clip, but trainer accounts are not needed for the first experience.

**Product loop:** choose an exercise → place the iPhone → analyze live without saving video → review one supported finding or a retake reason → try another set with a short reminder → compare the same measured signal. No account or accessory is required for this loop.

## What a result means

| Outcome | What Plumb says | Evidence needed |
| --- | --- | --- |
| Shorter observed range | The later reps had a smaller measured range; one next-set action appears. | At least four measured reps, a sufficient view, and the exercise's versioned range rule. |
| Consistent observed range | The measured range stayed similar across this set. | At least four measured reps, clear pose evidence, and every rep within the stated consistency rule. |
| No supported pattern | Plumb has no specific range finding for this set. | A measurable set with no rule supported. |
| Retake | The view or movement cannot support a measured result. | Missing/weak joints, wrong view, interruption, or incomplete movement. |
| Analysis failed | Plumb could not complete the set analysis and offers a retry. | A capture or processing error; do not present this as a movement finding. |

A consistent range is **one positive measurement**, not proof of “perfect form.” A single side camera cannot check every joint, force, load, pain, or personal constraint. The UI must never certify perfect or safe technique. Positive copy should name the measured property and retain the one-view limitation. A qualified coach and real-person holdout must review any new technique claim before release.

## Features and sequence

| Priority | Feature | Current state / next decision |
| --- | --- | --- |
| Now | iPhone side-view squat, push-up, static lunge, and stiff-leg deadlift; rep analysis, evidence gate, one observation, history, comparison, text sharing | Implemented with simulator and synthetic video checks; real-person accuracy remains unvalidated. |
| Now | One-sentence next-set reminder | Show the last relevant cue during framing and capture for the same exercise; clear it after a new result, dismissal, exercise change, or session end. |
| Now | Restrained positive feedback | Report consistent *measured range* only when evidence and rep-to-rep agreement support it. Never label form perfect. |
| Before release | Physical iPhone validation, cue review, accessibility, privacy and signing checks | Test consented sets across people, views, clothing, light, and occlusion. Suppress claims that miss the [validation gates](../../planning.md#6-validation-and-success-measures). |
| Next device | Apple Watch workout session, elapsed time, and discreet controls | Prototype after the iPhone loop is dependable. Compare any accelerometer-assisted rep timing with camera-only analysis before claiming an improvement. |
| Next movement | Treadmill running | Research safe camera placement and a running-specific, expert-reviewed gait signal. Begin with post-run feedback; do not reuse strength rep thresholds. |
| Later | Live cues, trainer workflow, saved clips, CloudKit or Sign in with Apple, paid tier | Each needs a clear user benefit, privacy choice, and validation. Apple TV, a second iPhone, widgets, and Live Activities are experiments, not submission claims. |

## Apple platform choices

- **Vision + AVFoundation:** on-device pose from a live frame sequence; confidence, occlusion, viewpoint, and the full movement matter more than a single image. [Vision reports joint positions and confidence](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images), rather than an overall technique verdict.
- **Foundation Models:** optional language for a structured, already validated comparison, with reviewed deterministic wording whenever generation is unavailable or invalid. It never decides whether a rep is safe.
- **AirPods:** optional audio output for a user-requested observation. They are not a required form sensor.
- **Apple Watch:** future workout context and controls; any camera/watch sensor fusion needs synchronized, paired-device tests.
- **Native UI:** system typography, controls, accessibility, and quiet black/white branding from the [brand guide](../../Design/README.md). The measured fact and next action should remain the focus. Apple's [feedback guidance](https://developer.apple.com/design/human-interface-guidelines/feedback) favors passive status for information a person can glance at, and its [workout guidance](https://developer.apple.com/design/human-interface-guidelines/workouts) cautions against distracting information during activity; the next-set reminder is one short line, not a live stream of corrections.

## How we decide whether it works

The first success event is a user reaching a trustworthy measured result, understanding why it appeared, and choosing a feasible next-set action. Track setup success within two tries, rep-count agreement with annotated sets, expert agreement on emitted cues, result latency, second-set completion, and user trust. Report how often the app abstains alongside cue agreement; silence alone is not a useful product. Targets and the collection protocol live in [planning.md](../../planning.md) and [validation](../validation/squat-v1-protocol.md). No real-person accuracy or retention result is claimed today.

## Supporting documents

- [Product rationale](rationale.md): why the problem and approach matter.
- [Market research](market-research.md): alternatives, positioning questions, and research plan.
- [Pitch](pitch.md): a three-minute story constrained to the implemented build.
- [Release documents](../release/): public copy and submission gates; they must describe the final signed build rather than this roadmap.
