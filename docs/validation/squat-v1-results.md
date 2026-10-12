# Squat v1 validation results

**Status: not started. Updated 12 October 2026.** No consenting participant sets or qualified specialist reviews have been recorded. A local 86-test iOS 27 simulator pass and a [successful hosted simulator workflow](https://github.com/james8464/hackathon-project/actions/runs/38194946081) verify implementation behavior, not real-camera accuracy. They include stalled-frame capture-limit and long tracking-loss regressions. The 0.75-second retake gate still needs measurement on real sets.

## Simulator UI check · 11 October 2026

Built and launched commit `8c2959e` on the iPhone 18 Pro Max simulator (iOS 27.0). The normal launch showed setup, Privacy, and empty History. A separate run with the explicitly labeled `DEMO INPUT` synthetic feed completed two six-rep sets. I inspected the first result and late-set range cue, the second result and set comparison, the optional comparison explanation, expanded rep details, and the saved two-set History summary. Text and controls were readable and the long result scrolled to **Done**. The comparison explanation returned the reviewed wording on this simulator. This was a visual/manual app-flow check; no real camera frames, pose accuracy, real Foundation Models output, or human coaching quality were tested. The synthetic demo must not be presented as a physical workout or used for App Store result screenshots.

| Evidence | Current state |
| --- | --- |
| Frozen app commit / rubric | Commit to be frozen before holdout / `squat-side-v2` |
| Tuning sets | 0 |
| Holdout sets | 0 |
| Physical iPhone camera pass | Pending; iPhone 16 Pro Max was unavailable to Xcode on 11 October. Use the [physical run sheet](physical-iphone-run.md) once available |
| Specialist cue reviews | 0 |
| Setup success | Not measured |
| Exact rep count | Not measured |
| Cue agreement and coverage | Not measured |
| Measured results on unsuitable camera views | Not measured; front and three-quarter holdout views now required in the collection protocol |
| Result latency | Not measured |
| Foundation Models real-output review | Not measured on an eligible device |

Follow [`squat-v1-protocol.md`](squat-v1-protocol.md) before entering results. Record numerator/denominator and device/viewpoint breakdown for every metric. Keep failures in the report, including unsuitable views the app mistakenly measures, view rejection, bystanders, dropped frames, and any misleading cue. Do not replace missing results with simulator or scripted trace numbers.

The [blank collection template](squat-v1-template.csv) and [scorer](score_squat_v1.py) are ready. No participant sheet has been scored; all gates remain unverified.
