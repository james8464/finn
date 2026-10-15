# Backend reliability and Coach crash investigation

16 October 2026. Branch: `finn/backend-reliability`, based on `3c8af26`.

## What changed

- **Input integrity:** reject non-finite or out-of-frame landmarks, invalid image geometry,
  malformed classifier features, hidden athletes and broken capture clocks. Decoded replay data
  goes through the same checks as camera data. Invalid points are no longer clamped to image edges.
- **Counting:** a time-bounded three-point median rejects isolated pose spikes. Tracking gaps
  abandon an unfinished movement; the shoulder fallback no longer invents a downward movement
  behind an occlusion. The deepest-frame selector uses the same filter as the counter.
- **Technique:** hip sag/pike, chest drop, torso lean and knee bend are checked throughout a rep.
  A fault requires at least three supporting readings over 0.2 seconds, with adequate observed
  duration. Depth checks use a 0.3-second window around the measured bottom. A single noisy frame
  cannot establish a fault. Reps filmed at an unsuitable observed angle are excluded individually.
  Counting from hips or shoulders alone does not produce side-view technique advice.
- **Reusability and work per update:** timestamp binary searches locate rep windows instead of
  filtering the whole capture for every rep. Checks share those windows and angle assessments.
  Live catch-up cues reuse one form review while restricting each cue to evidence from that rep
  or earlier. This removes repeated geometric analysis; the main counter still analyses its
  bounded capture buffer, so this is not a fully incremental constant-time counter.
- **Saved results:** validate session/set identities, chronology, finite measurements and cue
  references before writing or using decoded history. Invalid writes leave the good file intact;
  damaged existing history uses the existing explicit backup/recovery flow.
- **Code consistency:** British spelling for app-owned identifiers, clearer comments about
  assumptions, and shared model-request lifetime handling. Persisted keys, Apple API spellings,
  app identity and all `ai.mwm.build.challenge.team.08` bundle identifiers remain compatible.

Changed counting semantics have new rubric versions. Historical results are not silently relabelled
as new measurements. Four-language observation text describes the actual measurement window.

## Coach crash

The previous standard selector instantiated Apple's Private Cloud Compute model on iOS 27 even
though this app's entitlements do not include `com.apple.developer.private-cloud-compute`.
Device-level model availability does not authorise the app. Apple's [integration guidance][pcc]
and [managed entitlement documentation][entitlement] require that entitlement. A framework trap
cannot be handled with ordinary Swift `catch`; the normal selector now avoids this path entirely.

Coach uses the available on-device model, then recorded facts on failure. Its prompt, response and
conversation sizes are bounded. Empty history avoids inference. Leaving the screen cancels the
request, and changing/deleting its history prevents a stale reply being appended. Coach and the
comparison narrator share a generation gate: a timed-out or cancelled request continues to occupy
its slot until the underlying operation really ends. Repeated taps cannot accumulate overlapping
requests to that engine. Errors are logged without prompts or workout facts.

The Send button also has an explicit 44-point tap area, verified with the keyboard open.

The PCC path is a plausible cause of the reported phone crash, not a confirmed crash-log diagnosis. No
matching Finn report was returned from the connected phone's crash-log listing; a later request
lost its device connection. Live Apple Intelligence inference on that physical iPhone remains
unverified. Simulator checks use deterministic fallbacks or injected engines. The explicit
Debug-only Claude option remains separate; it is not enabled or used by these checks.

## Research and design decisions

1. Apple [Vision 2D guidance][vision2d] emphasises visible landmarks, adequate image size and
   confidence. Missing landmarks are missing evidence, rather than movement to interpolate.
2. Apple [Vision 3D guidance][vision3d] describes estimated joints and the most prominent person;
   it is not a calibrated motion-capture ground truth. The existing athlete correspondence and
   angle checks remain important. This update does not infer spinal curvature or frontal faults
   from side-view observations.
3. [Fitness-AQA][aqa] studies exercise-specific temporal representations and expert-labelled form
   assessment. Its findings motivate whole-rep temporal evidence and exercise-specific checks.
   No new learned model was trained or validated here.
4. Apple's [guided generation][guided] supports structured output. Coach's model selects known
   saved-set references; Finn renders recorded facts and validates selections. A language model
   is not used to invent counts or certify unseen technique. Apple's current framework supports
   more than text, but that alone is not evidence of reliable exercise assessment.

## Verification

- iPhone simulator: **531 tests in 63 suites passed**. The app and embedded Watch target
  compile successfully.
- **Three targeted UI flows passed:** Coach sends replies and survives tab changes; the recorded
  squat displays six reps; covered-feet footage produces a measured result. The first Coach UI
  run exposed an unregistered Send tap; an explicit rectangular hit area and plain button style
  fixed it. The recorded-set assertion now reads the combined accessible number and label. One
  intervening simulator runner aborted before starting tests; the isolated rerun passed.
- Camera/Vision replay: **15 strict fixture checks passed**, plus the mirrored diagnostic
  (six measured reps) and covered-feet framing assertion. Clear, dim, distant-but-readable,
  slower, bright, warm, low-resolution, off-centre and tilted fixtures each measured six reps.
  Standing still, hidden lower body, too-small footage, strong blur and camera movement returned
  a retake. The feet-hidden fixture counted six without side-view form measurements.
- Important limit: blur and camera movement each produced one provisional live count before the
  final refusal. The tests do not establish zero live false positives.
- The suite includes 600 seeded varied squat traces, all supported exercise paths, sustained
  faults outside the bottom, isolated glitches, high-frame-rate noise, insufficient coverage,
  wrong-angle reps, malformed history, cancellation, timeouts and unsupported model output.
- `tools/test_backend.sh`: **237 tests in 19 suites passed** on macOS 27, using shared
  production analysis/Coach sources without a simulator.
  `tools/replay/test_generated_videos.sh` exercises the real Vision path;
  replay JSON now includes form measurements and supported findings as well as rep counts.

## Accuracy claims still require real-person validation

Synthetic geometry and rendered-video regressions demonstrate specific behaviours, not human
technique accuracy. The earlier labelled-video results in [form-checks-v1.md](form-checks-v1.md)
were used to choose thresholds and are not a held-out evaluation of this update. Their original
external clips were unavailable for this run. The new time/coverage thresholds also remain
product hypotheses.

Before an accuracy release claim, evaluate participant-disjoint, independently annotated videos
covering every exercise, intended fault, camera angle, body proportion, clothing, lighting,
occlusion and pace. Report exact-count accuracy, count error, per-fault precision/recall, false
alarms on clean reps, measurement coverage/refusals and live latency separately. Retain unknown
checks as unknown, including in improvement trends. Missing a flag cannot certify good form.
Physical-device model inference, camera performance and Watch wrist-down behaviour remain
separate checks. This work does not claim perfect accuracy or complete freedom from crashes.

[vision2d]: https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images
[vision3d]: https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images
[aqa]: https://arxiv.org/abs/2202.14019
[guided]: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
[pcc]: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
[entitlement]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute
