# Plumb squat v1 validation protocol

**Frozen draft: 11 October 2026. Status: no participant sets collected yet.** The team must record the device, app commit, and rubric version before collecting the holdout. Do not use this document to imply that the coaching cue is validated.

## Question and claims

For a bodyweight squat filmed from one side, can a new user set up the phone, obtain the same rep count as a human annotator, and receive at most one relevant, camera-supported observation within five seconds of stopping? The app measures a within-person 2D pattern. It does not grade overall form, diagnose an injury, or determine that a rep is safe.

The frozen implementation is `SquatRubric.version = squat-side-v1`. Keep the gate thresholds and cue wording fixed for the holdout. Any change starts a new rubric version and a new holdout.

## Participants and consent

- Recruit at least 30 consenting **sets**, from multiple people and iPhone models where possible. Keep participants in only one split: approximately 12 tuning sets and at least 18 untouched holdout sets. Record unique participant IDs rather than names in the analysis sheet.
- Explain the camera-only purpose, that the app does not save video, and that the team may separately record a reference clip only with explicit, separate consent. Do not capture bystanders. State who can see a reference clip, where it is stored, and its deletion date on the consent form before recording.
- Use unloaded bodyweight squats only. A participant can stop at any time. Do not ask someone to continue through pain or use the app as medical advice.
- Obtain a qualified trainer or movement specialist's review of every emitted cue in both splits. Keep the reviewer blinded to the app's preferred answer when practical.

## Capture matrix

For each set, record: participant ID; consent version; tuning/holdout split; date; iPhone model and iOS build; Plumb commit/build; camera front/rear; distance and height; left or right side; portrait orientation; lighting (bright/even, dim, backlit); clothing contrast; full-body visibility; whether another person entered; setup attempts; set length; app outcome; and any interruption or thermal issue. Include deliberately difficult but safe views, and record why each was rejected.

The facilitator gives the same setup instruction shown in the app, then lets the participant try without extra coaching. A setup attempt ends when they press Start or decide to reposition. A successful setup reaches a usable result within two attempts. Log all attempts, including failures, rather than only successful sets.

## Independent annotation

1. A human annotator marks the start and end of each full rep, incomplete final reps, and sets where the body is not observable. If a separate reference video exists, use that for the reference; otherwise observe live and mark immediately. Record the reference method.
2. A second annotator resolves uncertain counts without seeing Plumb's count. Keep both original labels and the adjudicated value.
3. For each emitted cue, the specialist answers: Is this specific observation visible in the set? Are the named reps correct? Would you show the wording to this person? Record yes/no, a one-sentence reason, and a suggested replacement if no. Review abstentions separately so an app can pass agreement merely by almost never speaking only if coverage is also reported.
4. Do not edit holdout labels after seeing Plumb's result except to correct a documented annotation error; retain the pre-correction record.

## Sheet columns

Use [`squat-v1-template.csv`](squat-v1-template.csv). It includes the capture matrix above, the two original human counts, the adjudicated count, and the specialist's cue and view-rejection judgments. Keep one row per attempted set, including unusable and interrupted sets. Use `tuning` or `holdout` for `split`; `measured`, `insufficient_view`, `failed`, or `interrupted` for `app_outcome`; and `yes` or `no` for judgment fields. For an emitted cue, use `rangeDecreased` for `cue_kind` and semicolon-separated one-based app rep numbers (for example `5;6`) for `cue_rep_numbers`. Leave `adjudicated_reps` blank only when the reference is genuinely uncountable. Leave `app_reps` blank unless the outcome is `measured`. Use milliseconds from Stop to the final result for `result_latency_ms`. The app commit and `squat-side-v1` rubric must stay fixed throughout the holdout.

Do not put names, email addresses, raw frames, clip URLs, or reference video in this sheet. Keep a separate consent ledger under team control.

## Metrics and gates

Compute each metric on the holdout, plus a breakdown by device, lighting, side, and failure type. Show both numerator and denominator; do not report a percentage without them.

| Measure | Calculation | Proposed gate |
| --- | --- | --- |
| Setup success | People with usable result within two attempts / people who attempted setup | ≥80% |
| Exact rep count | Holdout sets whose app count equals adjudicated human count / countable holdout sets | ≥90% |
| Cue agreement | Emitted cues the specialist would show / emitted cues reviewed | ≥80% |
| Cue coverage | Sets with an emitted cue / usable sets | Report; no target yet |
| Result latency | Stop tap to final result, measured on physical iPhone | ≤5 seconds for the proposed demo gate |
| Abstention accuracy | Rejected difficult views that the reviewer agrees are unassessable / rejected views | Report |

At least 18 **countable holdout sets** are needed before the exact-count gate can pass; the 18-set holdout minimum alone can include uncountable views. A cue agrees only when the specialist marks both the observation supported and the wording worth showing. The cue-agreement gate needs at least five emitted, reviewed holdout cues; every emitted cue needs both judgments. This minimum is a practical evidence floor, not a statistical confidence claim. A measured result needs a latency value before the five-second gate can pass. Missing evidence is unverified, never a pass.

Run the standard-library scorer against a copy of the template containing consented rows:

```sh
python3 docs/validation/score_squat_v1.py path/to/consented-sets.csv --output path/to/holdout-report.md
```

The scorer refuses to overwrite an existing report, rejects mixed app commits or participants in both splits, and prints holdout metrics and device/lighting/side breakdowns. Keep consented participant data outside the public repository unless the team has explicit permission to publish it. Copy verified summary counts into [`squat-v1-results.md`](squat-v1-results.md) after specialist review.

For a zero-cue holdout, agreement is **not measurable**, not 100%. Report misses and false confidence separately. If a gate fails, narrow or suppress the affected claim and retain the retake path. Do not tune to the holdout result and still call it holdout performance.

## Device run and release decision

Before the 16 October demo, complete first launch permission, denial/recovery, preview orientation, six reps, short/partial set, interruption, repeat set, comparison, history deletion, reduced-motion/large-text/VoiceOver, low-light, heat, and offline checks on a physical iOS 27 iPhone. Record the device, build, date, result, and open defects in [`squat-v1-results.md`](squat-v1-results.md). A simulator run verifies logic and UI automation only.

If the physical run or specialist review is incomplete, the presentation must identify the simulator feed or recorded test set. The app must not claim validated technique coaching or show a confident cue when evidence is weak.
