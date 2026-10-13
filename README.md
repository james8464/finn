# Plumb

Plumb is an iPhone workout companion that helps you see how your movement changes, one set at a time. Set the phone where its camera can see you, complete a supported exercise, and review one observation tied to visible movement. Then try another set and compare. When the view is too weak, Plumb asks for a retake instead of guessing.

## What Plumb is

- **The first experience:** short strength sets viewed from the side. The iPhone analyzes a live camera stream on device; it does not save video. Rep counts and technique observations come from exercise-specific pose rules, with no universal “perfect form” score.
- **The intended product:** more movements, including **treadmill running**. Running needs its own camera placement, gait signals, continuous-session summary, and validation. A strength-rep rubric cannot simply be reused for it.
- **The Apple ecosystem:** iPhone remains sufficient by itself. A Watch companion is the next device milestone for workout timing, discreet controls, and optional heart-rate context. Spoken results can already use the current audio route, including paired AirPods. Foundation Models may phrase a measured comparison on eligible devices; reviewed wording remains the fallback. Neither Watch nor AirPods establishes technique quality on its own.
- **The boundary:** Plumb is a fitness aid, not medical advice, an injury-prevention guarantee, or a replacement for a qualified coach.

## What we need to build

1. **Prove the iPhone loop on real people.** Test camera placement, rep counts, occlusion, lighting, different bodies and clothing, processing time, and every coaching cue on physical iPhones. Get consent before filming and specialist review before broader technique claims.
2. **Finish the first release path.** Verify accessibility, privacy copy, audio behavior, signing, and a real App Store Connect upload. The current simulator and generated-video results do not establish real-person accuracy.
3. **Prototype iPhone + Apple Watch.** Add a watchOS workout session and simple, discreet controls only after the iPhone result is dependable. Evaluate synchronized motion data against camera-only analysis before claiming sensor fusion improves it.
4. **Design and validate treadmill running separately.** Define where the phone can safely sit, which side/rear view reveals a useful signal, how to handle occlusion and moving treadmill backgrounds, what a runner can act on, and what the app must withhold. Start with an expert-reviewed, post-run observation; do not promise live gait correction yet.

Apple TV, a second iPhone camera, widgets, Live Activities, accounts, and subscriptions are later experiments. A team movement-analysis engine can be assessed when its interface and sample output are available. See [planning.md](planning.md) for priorities, technical boundaries, and release gates.

## Current state · 13 October 2026

**Working in the iPhone app:** side-view bodyweight squat, push-up, static lunge, and stiff-leg deadlift flows; live framing and skeleton; rep analysis and a provisional observation when evidence permits; a short reminder of the previous relevant cue during the next set; a qualified positive note when measured rep range is consistent; retake guidance; local set history, comparison, text-only sharing, and optional spoken output. Foundation Models can reword a validated comparison when available, with a deterministic fallback. Video is analyzed locally and is not saved. There is no treadmill mode, Watch app, account, or subscription. A consistent measured range does not certify perfect form.

**Verified so far:** simulator UI tests and generated pose/video fixtures exercise the app, including hidden or covered body parts. These are repeatable engineering checks, not validation of coaching accuracy. Physical iPhone tests and qualified cue review remain open; [the results ledger](docs/validation/squat-v1-results.md) tracks that distinction. A debug demo must be identified as synthetic.

**Open the project:** clone the repository, open [Plumb.xcodeproj](Plumb/Plumb.xcodeproj) in Xcode, and run the `Plumb` scheme on an iPhone simulator or connected iPhone (iOS 27 target). [The replay guide](tools/replay/README.md) explains the generated fixtures.

## Project guides

| Need | Start here |
| --- | --- |
| Product scope and build order | [Planning](planning.md) |
| Consolidated product decisions and feature status | [Product brief](docs/product/brief.md) · [Document index](docs/README.md) |
| Brand, typography, color, and icon | [Design guide](Design/README.md) |
| Physical-device validation and results | [Validation protocol](docs/validation/squat-v1-protocol.md) · [Results](docs/validation/squat-v1-results.md) |
| Release and public claims | [Submission checklist](docs/release/app-store-submission.md) · [Privacy](docs/release/privacy-policy.md) |
| Team collaboration | [Git guide](Plumb/GIT%20guide.md) |

The layered Icon Composer source is [AppIcon.icon](Plumb/Plumb/AppIcon.icon). Brand artwork is in [Plumb/BrandArtwork](Plumb/BrandArtwork). The project is for the October 2026 Build Challenge: Unaite, MWM, Apple & ⌘+F. Team: James, Klaus, Théophile, and Guilhem.
