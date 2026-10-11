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

`set_id, participant_id, split, consent_version, device_model, ios_build, app_commit, rubric_version, side, distance_m, camera_height_cm, lighting, body_visible, bystander, setup_attempts, reference_method, human_reps_a, human_reps_b, adjudicated_reps, app_outcome, app_reps, cue_kind, cue_rep_numbers, expert_supported, expert_show, result_latency_ms, capture_duration_s, failure_reason, notes`.

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

For a zero-cue holdout, agreement is **not measurable**, not 100%. Report misses and false confidence separately. If a gate fails, narrow or suppress the affected claim and retain the retake path. Do not tune to the holdout result and still call it holdout performance.

## Device run and release decision

Before the 16 October demo, complete first launch permission, denial/recovery, preview orientation, six reps, short/partial set, interruption, repeat set, comparison, history deletion, reduced-motion/large-text/VoiceOver, low-light, heat, and offline checks on a physical iOS 27 iPhone. Record the device, build, date, result, and open defects in [`squat-v1-results.md`](squat-v1-results.md). A simulator run verifies logic and UI automation only.

If the physical run or specialist review is incomplete, the presentation must identify the simulator feed or recorded test set. The app must not claim validated technique coaching or show a confident cue when evidence is weak.
