# Finn — three-minute pitch

**Working pitch, updated 13 October 2026.** The repository contains a simulator-tested iPhone workout flow, generated-video replay checks, and brand work. Real-camera pose quality and coaching claims remain unvalidated on a physical iPhone. Demonstrations must identify which steps are live and which are recorded or simulated.

## One line

Finn turns an iPhone camera into a private technique mirror: after a supported set, it shows one evidence-linked cue when the view can support it.

## The story

**The problem (0:00–0:35).** Most people train without anyone watching their form. A video tutorial can show an ideal movement, but it cannot tell you what changed in *your* last six reps. Recording yourself helps, yet reviewing every clip and knowing what to look for takes time and expertise.

**The product (0:35–1:25).** Put your iPhone where it can see your full body from the side and do a bodyweight squat set. Finn tracks visible joint motion on device. It identifies the reps, shows the evidence, and offers one short range or posture-change cue when the view supports it. The next set becomes a small experiment: did that observable pattern change? It uses plain language and tells you when the camera view is too weak to judge.

**The Apple ecosystem (1:25–1:55).** The iPhone camera is the core sensor. Vision estimates pose and corroborates sampled joints against a person mask on device. On eligible iPhones, Foundation Models can reword a measured set-to-set comparison, with a deterministic fallback; the model does not invent the measurement. The current app can speak a post-set observation through the system audio route, including paired AirPods. The intended product pairs iPhone with Apple Watch for rep timing, effort, and discreet, timely cues; that Watch technology is not in this build. iPhone Duo placement and Apple TV display are proposed extensions, not demo features.

**Why Finn (1:55–2:25).** Existing products offer classes, hardware-based form feedback, running analysis, or coach video review. Finn's proposed wedge is a focused iPhone loop for self-directed strength training: evidence, one cue, another set, and visible progress. Privacy and uncertainty are part of that loop. Test return visits and willingness to pay after a person sees the current result; no paid model has been chosen. Treadmill running is a possible next use case, requiring separate camera setup, measurement, and expert validation; it is not in this demo.

**The close (2:25–3:00).** Better form is not a single score. It is noticing one thing, changing it, and seeing the result. Finn helps you find your line, one set at a time.

## Demo path

1. Show the branded setup guide for the supported side-view bodyweight squat.
2. Frame the whole body and start a short set on a physical iPhone. If live capture is unreliable, introduce a consented **recorded test set** or clearly label the Debug-only scripted feed as a **synthetic UI demonstration**.
3. Show measured reps, the observation and its referenced rep numbers, plus the relative range and rep-time evidence. Explain that the app abstains when the view is too weak.
4. Show a second set with a measured range change, or show the honest retake path. A synthetic comparison demonstrates the interface, not coaching accuracy.
5. Describe the available spoken output, the Watch prototype plan, and the optional Foundation Models rewording accurately. Show a measured comparison before discussing paid features or further devices.

## Judge questions

**Is this a medical or injury-prevention app?** No. Finn observes limited camera-visible movement patterns and offers general training cues. It does not diagnose pain, certify safety, prescribe weight, or replace a qualified professional.

**Does the AI watch raw video and decide what good form is?** No. Vision extracts pose points and a deterministic squat rule produces the measurement. Foundation Models may reword a measured comparison; if unavailable, reviewed templates work offline.

**Can it coach live?** The full product aims to correct a validated issue as early as possible. The current build gives post-set feedback. In-set prompts and Watch haptics are future features gated by tracking confidence, latency, and user testing so cues do not distract or mislead.

**Do I need a Watch or AirPods?** No for the current iPhone build. Apple Watch is central to the intended paired experience; AirPods are an optional audio route today. Neither currently contributes a form measurement to Finn.

**Why is a single-camera result trustworthy?** Its accuracy has not yet been established on a physical iPhone. Finn links each provisional cue to named reps and withholds feedback when important joints are obscured. The team must measure agreement with annotated sets and expert review before broader claims.

**What is the business?** Monetization and acquisition are part of the product work, but the README has not selected a paid feature, price, or subscription. The first test is whether people value the iPhone set-to-set loop enough to return.

**What can you ship for the challenge?** The target is one real iPhone camera-to-cue loop for a side-view bodyweight squat and a build uploaded through App Store Connect. A grounded Foundation Models comparison recap and existing tap-to-speak output can support the demo if verified on a device; Watch integration remains a later prototype. Uploading a build is distinct from App Review approval or public release.

## Claims to avoid until proven

- “Prevents injuries” or “guarantees correct form”
- “Works for any exercise,” “running now,” or “any angle”: the app has four side-view rubrics (squat, push-up, static lunge, stiff-leg deadlift), none measured on real sets yet, and automatic exercise recognition needs a model the team has not trained
- “Apple Watch or AirPods can see your form”
- “AI personal trainer” without explaining the limited, evidence-based scope
- “Private” if raw footage is uploaded or retained without explicit consent
- Any success, accuracy, latency, or retention figure that has not been measured

## Source notes

- [Apple Vision body pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Apple Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple HealthKit multi-device workout sample](https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app)
- [Apple AirPods Pro 3 workout heart rate](https://support.apple.com/en-lamr/guide/airpods/dev1b40fb47d/web)
- Competitor evidence and open questions: [market research](market-research.md)
