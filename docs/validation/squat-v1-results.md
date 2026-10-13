# Squat v1 validation results

**Status: participant validation not started. Updated 13 October 2026.** No consenting participant sets or qualified specialist reviews have been recorded. Simulator tests and sixteen synthetic video clips verify implementation behavior, not real-camera accuracy. The seven new clips vary exposure, color, resolution, framing, tilt, blur, and phone movement, but reuse the same source person and motion. With `squat-side-v7` the blurred clip measures its six reps; the moving-phone clip still requests a retake because required joints are not clear often enough. The covered-feet replay is refused after sampled person-mask corroboration; its false-refusal rate on real sets is unknown. The mirrored clip refused the set up to `squat-side-v6` (required-joint coverage about 71% versus the 80% gate) and measures six reps with v7. Whether facing direction matters on a real camera must be checked on physical iPhones. The 0.75-second tracking retake gate and bystander behavior also need measurement.

## Simulator UI check · 11 October 2026

Built and launched commit `8c2959e` on the iPhone 18 Pro Max simulator (iOS 27.0). The normal launch showed setup, Privacy, and empty History. A separate run with the explicitly labeled `DEMO INPUT` synthetic feed completed two six-rep sets. I inspected the first result and late-set range cue, the second result and set comparison, the optional comparison explanation, expanded rep details, and the saved two-set History summary. Text and controls were readable and the long result scrolled to **Done**. The comparison explanation returned the reviewed wording on this simulator. This was a visual/manual app-flow check; no real camera frames, pose accuracy, real Foundation Models output, or human coaching quality were tested. The synthetic demo must not be presented as a physical workout or used for App Store result screenshots.

| Evidence | Current state |
| --- | --- |
| Frozen app commit / rubric | Commit to be frozen before holdout / `squat-side-v7` |
| Historical app capture path on public gym videos (v4, before person mask) | 44 of 50 measured with athlete tracking (5 without); 43 of 44 within one rep of an independent dip counter. The v5 person-mask, v6 posture cue and v7 set window have not been replayed on this set. See "Other people in view" in [`exercise-rules-v1.md`](exercise-rules-v1.md) |
| Generated video regressions (v6, before the v7 silhouette search and set window) | Original and clear exposure, color, resolution, position, tilt, distance, and tempo variants measured six reps; standing still, hidden legs, covered feet, too-small subject, blur, and phone movement refused. The mirrored clip is a diagnostic retake. v7 replay in CI: the same results, except the blurred and mirrored clips, which now measure six reps. All sixteen clips reuse synthetic imagery and are not participant validation. [Replay details](../../tools/replay/README.md) |
| Replay on public videos (not participants) | 42 of 50 Mendeley side-view squat videos measured by `squat-side-v3` (0 of 50 by `squat-side-v2`); counts within one rep of an independent dip counter on all 42; no human count. See [`exercise-rules-v1.md`](exercise-rules-v1.md) |
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
