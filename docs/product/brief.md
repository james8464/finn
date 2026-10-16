# Finn product brief

Finn helps people training alone see how a camera-visible movement changed during a set. The first audience is a self-directed iPhone user doing basic strength exercises at home or in a gym. The current loop is **choose an exercise → frame the body → count a set → review one supported observation or a retake reason → try again**. No account or accessory is required. [README](../../README.md) owns the current build status.

## Result boundaries

| Outcome | Meaning |
| --- | --- |
| Measured observation | An exercise-specific rule found a range or posture change in sufficiently clear, comparable reps. Show the supporting reps and one next-set action. |
| No supported pattern | The set was measurable, but no rule supports a specific correction. Do not imply perfect form. |
| Partial set | Keep the visible count, name the unclear joint, and withhold posture advice or comparison. |
| Retake | The view or movement could not support a measured result. Explain what to change. |
| Analysis failure | A capture or processing problem occurred. Offer retry without interpreting the movement. |

A single camera cannot assess force, pain, load, or every joint. Finn must not certify safe technique or diagnose a condition. New technique cues need labeled sets and qualified review before release.

## Sequence

1. **Validate the iPhone loop.** Test setup, count, cue support, latency, accessibility, and trust across consenting people, devices, views, and lighting. Report abstention alongside accuracy. The [protocol](../validation/squat-v1-protocol.md) defines the initial gates.
2. **Test the paired experience.** The Watch companion exists, but physical-device tests must establish whether its timing and haptics improve on camera-only feedback. AirPods are an audio route; head-motion analysis is a separate unvalidated idea.
3. **Expand by evidence.** Treadmill running needs a distinct gait rubric. iPhone Duo placement, Apple TV display, widgets, Live Activities, and monetization each need a demonstrated user benefit and release checks. Scaffolded code is not proof of a finished feature.

Use native Apple controls and accessible text. Camera and Health permissions belong at the moment of use. Video remains local and unsaved. Generative language can explain measured facts with a deterministic fallback; it cannot invent coaching evidence.

For positioning and research, see the [rationale](rationale.md), [market research](market-research.md), and [running note](running-stride.md). The [earlier build plan](../../planning.md) records technical choices; release copy must describe the signed, validated build.
