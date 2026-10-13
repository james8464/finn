# Plumb — market and competitor research

**Research snapshot: 10 October 2026; product scope updated 13 October.** This is a source-backed map of alternatives and a validation plan, not a proven market-size estimate. Product claims below are based on official product or support pages as viewed for this reset; features and prices can change. The new Plumb concept has not yet been tested with customers.

## 1. The job to be done

> When I train alone, I want to know one thing I can change in my next set, so I can make my movement more consistent without hiring a trainer for every workout.

This is narrower than “AI personal trainer.” The first target is a self-directed person practicing foundational strength movements. They already have a smartphone and may use a Watch or AirPods, but should not need to buy equipment. They may be training at home or in a gym. The key behavior is not merely recording a set; it is **acting on feedback and trying again**.

### Segments to test

| Segment | Current workaround | Likely friction | What to learn |
| --- | --- | --- | --- |
| Beginner doing home strength | Tutorial and mirror | Unsure what to notice; awkward camera setup | Whether one cue is understandable and nonjudgmental |
| Self-directed gym regular | Phone video or training log | Time spent replaying clips; social discomfort filming | Whether an evidence-linked result is worth setup time |
| Remote client of a trainer | Send clips in chat | Slow feedback; unclear clip organization | Whether human annotation plus Plumb's measurements saves time |
| Trainer | In-person observation or video review app | Review effort and client follow-through | Which automated observations are useful vs distracting |

Start with the first two. A coach product is a later opportunity and should not dictate the initial interface.

## 2. Alternatives people already use

### A. Do nothing, mirror, or record a phone video

This is the true baseline. It is free and flexible, and a phone video preserves the original movement. It asks the person to know what to look for, find time to review, and remember the last set. Plumb must beat this on setup plus interpretation, not just produce a colorful score.

**Validation task:** time a person from deciding to film to choosing a concrete next-set adjustment, with and without Plumb. Ask whether the cue matched what they could see themselves.

### B. In-person trainer or trusted training partner

Human coaching can consider pain, goals, equipment, fatigue, prior history, and a full 3D view. Plumb cannot claim equivalent judgment from a single camera. The opportunity is a useful, affordable observation between human sessions, and later a clearer clip for a trainer to review.

**Validation task:** have qualified trainers independently review the same sets and rate the visibility, correctness, and usefulness of Plumb's proposed cues. Record disagreements and the context the camera missed.

## 3. Product comparison from primary sources

| Alternative | What its own materials describe | Implication for Plumb | Source |
| --- | --- | --- | --- |
| **Tempo** | 3D motion tracking, rep counting, range-of-motion and on-screen form cues within its class experience. Tempo says cues are selective, not shown for every mistake. | Form feedback is an existing category. Plumb should test an iPhone-only, short-set workflow without a dedicated class or hardware setup. | [Tempo support](https://support.tempo.fit/support/solutions/articles/151000154714-3d-tempo-vision-form-feedback) |
| **Ochy** | A short side/back phone video produces running gait analysis and progress comparisons. | Camera-based technique analysis already exists in running. Plumb's first focus is foundational strength sets and an immediate second-set loop. | [Ochy for runners](https://www.ochy.io/runners) |
| **OnForm** | Coaches capture, mark up, voice-over, and share athlete videos for remote review. | Human review and video annotation are strong substitutes. A future trainer feature should complement this rather than pretend to replace it. | [OnForm knowledge base](https://support.onform.com/article/94-what-is-onform) |
| **Peloton Guide** | Its Movement Tracker detects participation in movements during classes; Peloton support states it does not count reps or provide form correction. | Do not conflate movement recognition with technique advice. Plumb's narrow claim requires direct evidence for each cue. | [Peloton support](https://support.onepeloton.com/s/article/Peloton-Hardware-Movement-Tracker?language=en_CA) |
| **Apple Fitness+** | Guided strength and other classes, personalized plans, and real-time metrics from Watch or compatible heart-rate devices. | Plumb is about a person's own movement in an unscripted set, not competing on class production or workout catalog. | [Apple Fitness+](https://www.apple.com/apple-fitness-plus/) |

**Important qualification:** these are descriptions of specific products and pages, not a complete feature audit or independent accuracy test. Some products may add features or offer versions with different capabilities. Recheck before public comparative marketing.

## 4. Positioning hypothesis

**Category:** movement-feedback companion, starting with independent strength training.

**For:** first, people who practice strength exercises alone and want a useful observation from their own set. Treadmill runners are a separate prospective segment to research, with a continuous-session job rather than a rep-by-rep set.

**Plumb provides:** a camera-based, evidence-linked cue and a way to compare the next set.

**Unlike:** a tutorial library, a raw video recorder, or a generic AI chat response, Plumb begins with measured motion from the user's actual set and can decline to comment when the camera cannot support a claim.

This is a proposed wedge, not a statement that competitors lack evidence, privacy, or technique features. The best position may change after interviewing users and trainers.

**Running expansion test:** Interview treadmill runners about phone placement, filming comfort, and what they already get from a watch or gait app. Observe whether a side or rear phone view is safe and consistent in real gyms. Compare any proposed observation with a qualified coach's judgment and the actual camera evidence before describing Plumb as a running coach. Ochy remains a relevant alternative; Plumb has no running analysis today.

### Reasons someone might choose Plumb

1. They can start with their existing iPhone.
2. One cue is less cognitively demanding than reviewing an entire video.
3. The evidence points to a specific rep, which makes a suggestion checkable.
4. A second set shows a visible change rather than an abstract score.
5. Local processing and opt-in clip saving address a sensitive filming context.
6. The current iPhone loop needs no accessory; a later iPhone + Watch experience could make timely, discreet feedback more useful if paired-device tests support it. AirPods are an optional audio route.

### Reasons someone may reject it

- They do not want to film in a gym or cannot find a safe phone position.
- They already work with a trainer or prefer to self-review video.
- Their exercise, camera angle, clothing, or environment produces weak pose tracking.
- They distrust automated coaching or find a cue obvious, wrong, or distracting.
- The app's supported exercise list is too small.

These objections should be tested before expanding the product.

### The choice Plumb has to win

The first competitor is the user's existing phone camera. Plumb adds setup guidance, automatic review, and a next-set prompt, but also asks for framing time, permission, battery, and trust. A convincing test should compare the **whole task**—from placing the phone to deciding what to change—rather than comparing the quality of a finished cue with an unreviewed clip. If setup takes longer than the saved review time, the product may be most useful to a narrower group of deliberate trainees.

An in-person trainer remains the benchmark for contextual judgment. The more credible position is a record that helps the person notice a limited visible pattern between coached sessions. For a trainer, the camera result could reduce sorting and timestamping work, but the coach must be able to disagree and add context. Plumb should never imply that an automated rule outranks the person who knows the athlete's constraints.

## 5. Technology opportunity and constraint

Apple's Vision framework can detect 2D body joint points with confidence values and has a 3D body-pose request. It does not provide a universal “good form” judgment. 3D pose can benefit from depth where available, but single-camera estimation and occlusion still demand careful exercise-specific validation. [Apple 2D pose guidance](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images), [Apple 3D pose guidance](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images).

Foundation Models can generate language or structured output, but on-device availability depends on device and region, and generation may take seconds. Apple's guidance calls for an availability check and fallback. It should phrase a validated observation, not calculate joint angles or decide whether movement is safe. [Apple Foundation Models guidance](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).

Watch sessions and HealthKit can provide workout metrics with permission; AirPods Pro 3 can also supply heart rate to supported third-party workout apps with Health permissions. These data do not establish technique quality. [Apple workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), [Apple AirPods Pro 3 support](https://support.apple.com/en-lamr/guide/airpods/dev1b40fb47d/web).

## 6. Commercial hypotheses

### Who pays and why

The likely payer is the person training independently. A few free analyses should demonstrate the whole loop. A Plumb Plus plan might unlock frequent analyses, longer history, and set comparisons. The draft price is €7.99/month or €49.99/year, **not a validated price**. A trainer plan could become relevant only after observing repeat coach/client use.

### What to measure before pricing

- Can a person get a useful result on the first session?
- What proportion tries a second set after a cue?
- Does the cue agree with qualified human review?
- How often does Plumb abstain because visibility is poor, and is the retake guidance helpful?
- How many people return in a week without reminders?
- Would they pay for more analyses, saved comparisons, or trainer review? Which feature creates the willingness to pay?

### Market-sizing method, once evidence exists

No defensible revenue forecast follows from app-store download totals or the number of gym members alone. Define an initial geography and a reachable population of iPhone owners who practice supported strength movements independently. Then measure four separate rates: willingness to film, ability to obtain a valid camera view, repeat use after a first cue, and conversion to the paid benefit. An annual subscription scenario would be `reachable people × valid-first-session rate × retained active rate × paid conversion × net annual revenue per payer`. Each input should have an observed source and a low/base/high range; the result should be labeled a scenario, not total market size.

There is also a practical capacity question: how many sets can an on-device app analyze before heat, battery, storage, or a person's patience limits use? The answer affects packaging. A free allowance should let a user complete at least one full compare-two-sets loop. Charging before the second set would block the very behavior that demonstrates value. A paid tier needs a recurring reason to exist—progress history, repeatable comparisons, or coach review—not merely the same cue without a limit.

### Pricing experiment

Start with interviews about the cost of the current workaround: time reviewing clips, occasional trainer sessions, and abandoned recordings. Then show the **same working result** to respondents and test whether they would use it again at a stated price. Separate intent from payment behavior. If a subscription is tested, measure conversion after a complete free loop, renewal, cancellation reasons, and whether the limits discourage healthy use. The draft €7.99/month and €49.99/year are hypotheses for testing, not evidence that the market will pay.

Avoid a market-size claim until the team defines geography, target exercise population, conversion assumptions, and a source for each input. Download volumes of fitness apps do not automatically translate to demand for a camera form coach.

### Distribution experiments

1. Small in-person tests with strength-training clubs or student gyms, with explicit filming consent and no footage posted.
2. Trainer-led demonstrations of a before/after set, showing the evidence and limits.
3. A privacy-safe share card that describes a user's *own observed change* without exposing a video or sensitive health metrics by default.
4. App Store listing focused on supported exercises and device requirements, without unproven injury or accuracy claims.

The team should not acquire users with a promise of universal AI coaching before the first exercise works reliably.

## 7. Research plan

### Qualitative interviews

Interview at least 6 self-directed exercisers and 3 trainers. Ask about their last attempt to improve technique, what they filmed, how they judged a clip, what made a cue credible, and how they would feel about a phone camera in their usual training space. Show a low-confidence example as well as an ideal result. Do not lead with “Would you use an AI coach?”

### Prototype study

Collect at least 30 consented sets across different people, iPhones, lighting, camera positions, and clothing. Obtain a human rep-count annotation and expert review of every candidate cue. Include partial-body and occluded footage on purpose. Report coverage and errors by condition; a high aggregate score can hide a bad experience for certain users or environments.

### Interview prompts and signals

Ask participants to recall the last exercise they wanted to improve, whether they recorded it, where they placed the phone, what they looked for, and what they changed afterward. Watch them set up a real supported exercise without coaching from the researcher. After the result, ask them to point to the evidence for the cue, describe it in their own words, and say whether they would try it. Observe the second set. Their behavior is stronger evidence than agreement with a concept description.

For trainers, ask which camera-visible signals are helpful, which cannot be judged from one view, and when a cue could create a harmful misunderstanding. Show low-confidence and false-positive examples as well as successful ones. Record how they would phrase a correction and whether the result would save review time. Do not treat a trainer's approval of one sample as validation for all bodies, exercises, and camera angles.

### Evidence ledger for a launch decision

Maintain a small table for each hypothesis: source, date, sample, observed result, limitation, and next decision. Keep three decisions separate: **Can it observe?** (coverage and measurement agreement), **Does it help?** (comprehension and next-set behavior), and **Will people return/pay?** (retention and purchase evidence). A visually polished demo can answer none of these on its own. Conversely, a narrow but reliable squat loop is enough to justify expanding the exercise library experimentally.

### Decision thresholds

The first release decision needs both **accuracy and usefulness**. The [product plan](../../planning.md) proposes initial internal gates for framing success, rep count, cue support, and post-set latency. If a category fails, either improve it or suppress it; do not compensate with more persuasive AI wording.

## 8. Open questions and evidence gaps

- Which single exercise is most valuable and most camera-observable for the first audience?
- Does the camera setup feel acceptable in gyms, or is the true first market at-home training?
- Are users more motivated by a technique cue, rep history, or a human coach's review?
- What is the acceptable abstention rate before the product feels broken?
- Can the same cue language work across body types and mobility differences without implying a universal standard?
- Does optional live speech help, or interrupt concentration and music?
- Does Watch effort context improve decisions, or add interface noise?
- Which paid feature drives real repeat use rather than a one-off curiosity?
- What retention and deletion controls make people comfortable saving a clip?

## 9. Claims discipline

| Claim | Current status | Evidence needed |
| --- | --- | --- |
| “Plumb counts squat reps accurately.” | Unproven | Labeled, diverse physical-device test sets |
| “Plumb helps improve technique.” | Hypothesis | User behavior and expert-reviewed before/after observations |
| “Plumb prevents injury.” | Do not claim | Outside the intended scope; medical-level evidence would be required |
| “Works live.” | Future possibility | Latency, reliability, and distraction tests |
| “Private by default.” | Design requirement | Verified local data flow and retention implementation |
| “Works across the Apple ecosystem.” | Roadmap | Real Watch/HealthKit and audio integration tested on devices |

## 10. Source register

Official product and platform sources used above:

- [Tempo: 3D vision and form feedback](https://support.tempo.fit/support/solutions/articles/151000154714-3d-tempo-vision-form-feedback)
- [Ochy: runner analysis](https://www.ochy.io/runners)
- [OnForm: video analysis and coaching](https://support.onform.com/article/94-what-is-onform)
- [Peloton Guide: Movement Tracker](https://support.onepeloton.com/s/article/Peloton-Hardware-Movement-Tracker?language=en_CA)
- [Apple Fitness+](https://www.apple.com/apple-fitness-plus/)
- [Apple Vision: 2D pose](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Apple Vision: 3D pose](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images)
- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
