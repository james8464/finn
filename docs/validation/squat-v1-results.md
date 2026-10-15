# Squat v1 validation results

**Status: participant validation not started. Updated 15 October 2026.** No consenting participant sets or qualified specialist reviews have been recorded. Simulator tests and sixteen synthetic video clips verify implementation behavior, not real-camera accuracy. The seven new clips vary exposure, color, resolution, framing, tilt, blur, and phone movement, but reuse the same source person and motion. The blurred clip (nine blended frames and a strong spatial blur) and the moving-phone clip request a retake after the hip-count fallback checks torso visibility and camera stability. The covered-feet replay counts six reps from the hips without posture advice; its performance on real sets is unknown. The mirrored clip refused the set up to `squat-side-v6` (required-joint coverage about 71% versus the 80% gate) and measures six reps with v7. Whether facing direction matters on a real camera must be checked on physical iPhones. The 0.75-second tracking retake gate and bystander behavior also need measurement.

## Simulator UI check · 11 October 2026

Built and launched commit `8c2959e` on the iPhone 18 Pro Max simulator (iOS 27.0). The normal launch showed setup, Privacy, and empty History. A separate run with the explicitly labeled `DEMO INPUT` synthetic feed completed two six-rep sets. I inspected the first result and late-set range cue, the second result and set comparison, the optional comparison explanation, expanded rep details, and the saved two-set History summary. Text and controls were readable and the long result scrolled to **Done**. The comparison explanation returned the reviewed wording on this simulator. This was a visual/manual app-flow check; no real camera frames, pose accuracy, real Foundation Models output, or human coaching quality were tested. The synthetic demo must not be presented as a physical workout or used for App Store result screenshots.

| Evidence | Current state |
| --- | --- |
| Frozen app commit / rubric | Commit to be frozen before holdout / `squat-side-v7` |
| Historical app capture path on public gym videos (v4, before person mask) | 44 of 50 measured with athlete tracking (5 without); 43 of 44 within one rep of an independent dip counter. The v5 person-mask, v6 posture cue and v7 set window have not been replayed on this set. See "Other people in view" in [`exercise-rules-v1.md`](exercise-rules-v1.md) |
| Generated video regressions | On the current macOS Vision path, original, clear exposure, color, resolution, position, tilt, moderate distance, tempo, and covered-feet variants measure six reps; standing still, hidden legs, too-small subject, blur, and phone movement request a retake. The mirrored clip measures six reps but remains diagnostic. All sixteen clips reuse synthetic imagery and are not participant validation. [Replay details](../../tools/replay/README.md) |
| Replay on public videos (not participants) | 42 of 50 Mendeley side-view squat videos measured by `squat-side-v3` (0 of 50 by `squat-side-v2`); counts within one rep of an independent dip counter on all 42; no human count. See [`exercise-rules-v1.md`](exercise-rules-v1.md) |
| Tuning sets | 0 |
| Holdout sets | 0 |
| Physical iPhone camera pass | Partial smoke pass on 15 October: iPhone 16 Pro Max, iOS 27.0.1, built from `d8f1503` with temporary personal-team signing. The app launched; UI automation allowed Camera and opened the live preview with the correct missing-joint framing instruction. The phone faced a ceiling, so no person or rep was analyzed. The full [physical run sheet](physical-iphone-run.md) remains open for the final FinLearn build |
| Specialist cue reviews | 0 |
| Setup success | Not measured |
| Exact rep count | Not measured |
| Cue agreement and coverage | Not measured |
| Measured results on unsuitable camera views | Not measured; front and three-quarter holdout views now required in the collection protocol |
| Result latency | Not measured |
| Foundation Models real-output review | Not measured on an eligible device |

Follow [`squat-v1-protocol.md`](squat-v1-protocol.md) before entering results. Record numerator/denominator and device/viewpoint breakdown for every metric. Keep failures in the report, including unsuitable views the app mistakenly measures, view rejection, bystanders, dropped frames, and any misleading cue. Do not replace missing results with simulator or scripted trace numbers.

The [blank collection template](squat-v1-template.csv) and [scorer](score_squat_v1.py) are ready. No participant sheet has been scored; all gates remain unverified.
