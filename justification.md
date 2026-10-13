# Why Plumb

**Updated 13 October 2026 — product rationale, not a claim of proven demand.** Plumb is an iPhone-first movement-feedback companion. Four side-view strength flows and local comparison exist; treadmill running is an intended expansion. Real-camera and expert validation are still pending.

## 1. The problem worth solving

Independent strength training has a feedback gap. People can follow an exercise video, count their sets, and log weight, but they often cannot tell whether their own movement changed during the set. A phone recording contains the evidence, yet the person must frame it, replay it, interpret it, and decide what to try next. A human trainer can provide richer feedback but is not present at every session.

The narrow first job for Plumb is therefore **turn a live-analyzed set into one useful next-set experiment**. The app does not save that video. Its first value is clarity and continuity, not a claim to know the single correct technique for every body.

## 2. Why this approach

An iPhone camera can observe a person's visible movement without special gym hardware. Apple Vision provides body joint locations and confidence values; AVFoundation supplies frames. A constrained exercise engine can count reps and compare patterns within a set. This is more defensible than asking a language model to judge a raw video and invent coaching advice. The current app can ask Apple Foundation Models to reword a validated comparison on eligible devices, while a reviewed template works when the model is unavailable.

The product loop is designed for behavior change: **see a signal → receive one cue → try another set → compare**. A list of ten flaws is easy to ignore; one cue with linked evidence can be tested immediately. The user's ability to dismiss a cue also helps distinguish a relevant suggestion from a noisy model output.

## 3. Why the Apple ecosystem fits

- **iPhone** supplies the required camera and a private, portable analysis device.
- **Apple Watch** can add an optional workout session, heart-rate context, elapsed time, and discreet controls. These metrics describe effort, not technique.
- **AirPods** can make a cue audible when the screen is several metres away. Compatible AirPods Pro 3 can also provide heart-rate data in supported workout apps with Health permissions; this is optional context, not form detection.
- **HealthKit** gives the person control over permitted workout data. It should be requested only when a Health feature is used.
- **Foundation Models** offer optional on-device language generation on eligible devices. Model availability varies, so the core feature cannot depend on it.

This ecosystem story is credible only if the first iPhone-only loop works. Plumb must remain useful to someone with no Watch, no AirPods, and no Apple Intelligence support.

## 4. What makes Plumb distinct enough to test

The market already has strength classes, rep tracking, specialist camera feedback, running gait analysis, and coach video review. Plumb's first position to test is **personal, evidence-linked movement feedback for short strength sets, available from an iPhone without new hardware**. Treadmill running could extend that idea to a continuous session, but needs its own gait rubric, safe setup, and expert validation. Its restraint is part of the product: exercise-specific support, one cue, low-confidence abstention, and visible comparison with the next set.

This is a positioning hypothesis, not an uncontested category. Competitor features change; [market research](market%20research.md) records current primary-source comparisons and questions that need user interviews.

## 5. Trust is a product requirement

A camera can miss a foot, confuse a joint, or see only one plane of movement. A low-confidence or incomplete observation must not become a confident instruction. The first automated cues should be reviewed by qualified trainers or movement specialists and tested against labeled sets from varied people and settings. Plumb should not imply that a particular angle, depth, or tempo is medically safe for everyone.

The privacy model is equally central: video analysis on device where practical, raw clips off by default, explicit save/share controls, and contextual HealthKit permission. Health and fitness data must not be sold or used to target advertising. Product copy should explain what the camera can observe, what it cannot, and why a particular cue appeared.

## 6. Business hypothesis

A limited free allowance lets people experience a complete set-to-set loop. A proposed Plumb Plus subscription pays for frequent analysis, longer history, and richer comparisons. The initial price hypothesis is €7.99 per month or €49.99 per year in the first market, subject to interviews and willingness-to-pay testing. Coaches may later pay for a workflow that adds human comments to an athlete's shared clips. There is no live subscription, trainer marketplace, or paid claim today.

The business should be judged by whether people complete a second set after seeing a cue, return for another session, and trust the explanation enough to use it. Download counts alone would not prove the product works.

## 7. Why this is an appropriate challenge project

The first prototype can show the integration of iPhone camera capture, pose observations, deterministic movement logic, privacy-conscious data handling, and a native SwiftUI experience. Optional Watch and spoken output tell a broader Apple ecosystem story without being necessary for the demo. A single reliable squat loop is a stronger proof than a polished mockup claiming universal AI coaching.

The technical and product risks are visible: camera placement, pose occlusion, validating cues, on-device speed, and safety language. The [plan](planning.md) narrows the challenge build, defines test gates, and makes the unimplemented features explicit.

## Primary references

- [Apple Vision: detecting body poses](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Apple Foundation Models: availability and fallbacks](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple HealthKit: workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions)
- [Apple AirPods Pro 3 heart-rate support](https://support.apple.com/en-lamr/guide/airpods/dev1b40fb47d/web)
- [Apple HealthKit privacy requirements](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
