# Plumb — three-minute pitch

**Working pitch, updated 11 October 2026.** The repository contains a simulator-tested iPhone squat flow and brand work. Real-camera pose quality and coaching claims remain unvalidated on a physical iPhone. Demonstrations must identify which steps are live and which are recorded or simulated.

## One line

Plumb turns an iPhone camera into a private technique mirror: after a strength set, it shows one specific, evidence-linked cue to try on the next set.

## The story

**The problem (0:00–0:35).** Most people train without anyone watching their form. A video tutorial can show an ideal movement, but it cannot tell you what changed in *your* last six reps. Recording yourself helps, yet reviewing every clip and knowing what to look for takes time and expertise.

**The product (0:35–1:25).** Put your iPhone where it can see your full body, choose a supported exercise, and do a set. Plumb tracks visible joint motion on device. It identifies the reps, shows the evidence, and offers one short cue. The next set becomes a small experiment: did that observable pattern change? It speaks in plain language and tells you when the camera view is too weak to judge.

**The Apple ecosystem (1:25–1:55).** The iPhone camera is the core sensor. An optional Apple Watch can add workout and effort context. AirPods can deliver a quiet spoken cue; compatible AirPods heart-rate data may add context in a later, permissioned workout flow. Apple Foundation Models can make a validated observation easier to understand on supported devices, with a deterministic fallback everywhere else. The model does not invent the movement measurement.

**Why Plumb (1:55–2:25).** Existing products offer classes, hardware-based form feedback, running analysis, or coach video review. Plumb's proposed wedge is a focused iPhone-only loop for self-directed strength training: evidence, one cue, another set, and visible progress. Privacy and uncertainty are part of that loop. We will test whether people find it useful enough to return and pay for a deeper history.

**The close (2:25–3:00).** Better form is not a single score. It is noticing one thing, changing it, and seeing the result. Plumb helps you find your line, one set at a time.

## Demo path

1. Show the branded setup guide and side-view bodyweight squat selection.
2. Frame the whole body and start a short set on a physical iPhone. If the venue makes live capture unreliable, introduce the fallback as a **recorded test set**.
3. Show detected reps, the selected observation, its timestamp/rep evidence, and a confidence label.
4. Show a second set with a change in the observed metric, or show the honest low-confidence retake path.
5. Mention Watch, AirPods, and Foundation Models only at the level actually implemented in the build.

## Judge questions

**Is this a medical or injury-prevention app?** No. Plumb observes limited camera-visible movement patterns and offers general training cues. It does not diagnose pain, certify safety, prescribe weight, or replace a qualified professional.

**Does the AI watch raw video and decide what good form is?** The proposed pipeline uses Vision pose points and exercise-specific rules for factual observations. Foundation Models may phrase a validated observation; if unavailable, reviewed templates work offline.

**Can it coach live?** Post-set feedback is the first target. Live prompts are a later feature gated by tracking confidence, latency, and user testing so cues do not distract or mislead.

**Do I need a Watch or AirPods?** No. The iPhone is enough for the core experience. Accessories add context or audio delivery, not the underlying pose measurement.

**Why is a single-camera result trustworthy?** It is trustworthy only within a tested exercise and camera angle. Plumb links each cue to evidence and suppresses feedback when important joints are obscured. The team will measure agreement with annotated sets and expert review before broader claims.

**What is the business?** A proposed freemium allowance for analyzed sets and a paid tier for more analysis and comparison history. Pricing is a hypothesis, not a current subscription.

**What can you ship for the challenge?** The target is one real iPhone camera-to-cue loop for a side-view bodyweight squat and a build uploaded through App Store Connect. A grounded Foundation Models comparison recap is an addition if the core loop is reliable; Watch and live audio remain later work. Uploading a build is distinct from App Review approval or public release.

## Claims to avoid until proven

- “Prevents injuries” or “guarantees correct form”
- “Works for every exercise and angle”
- “Apple Watch or AirPods can see your form”
- “AI personal trainer” without explaining the limited, evidence-based scope
- “Private” if raw footage is uploaded or retained without explicit consent
- Any success, accuracy, latency, or retention figure that has not been measured

## Source notes

- [Apple Vision body pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Apple Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple HealthKit multi-device workout sample](https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app)
- [Apple AirPods Pro 3 workout heart rate](https://support.apple.com/en-lamr/guide/airpods/dev1b40fb47d/web)
- Competitor evidence and open questions: [market research](market%20research.md)
