# Form analysis and model grounding — 15 October 2026

## What the app measures

Vision supplies 2D body joints and confidence scores. The existing exercise analyzer counts complete movements from those time series; `FormChecks` measures only checks whose required joints are clear. Its side-view checks cover squats, push-ups, lunges, and stiff-leg deadlifts. Pull-ups and muscle-ups retain their existing movement observations. The 3D Vision request checks camera angle when available.

Each new saved set now keeps the number of readable reps, the number that triggered each supported form check, and the median reading. It does not persist video or joint coordinates for this purpose. A form trend is reported only when both sets have at least four readable reps, the same exercise, body side, view and rubric, sufficient pose confidence, and at least a 30 percentage point change in flagged-rep share. Unclear or partly visible sets cannot create an improvement claim.

The result screen compares each form check with its own most recent compatible reading, even when another check was last readable in a different set. The Coach can select those recorded facts across sessions. Foundation Models use guided generation to choose up to two saved set numbers; the app validates those numbers and renders the recorded facts itself. The model does not count reps, estimate joint angles, or invent a technique diagnosis. User questions and saved observations are prompt data, not model instructions.

## Performance

Form review previously searched the full capture and reran the evidence gate for every rep. It now assesses the view once and uses binary search to find each rep's time window, then inspects only that window. For a chronological capture of N frames and R non-overlapping reps, this part changes from roughly O(R × N) to O(R × log N + N). The overall review still includes percentile sorting, which is O(N log N). Cross-session Coach trends index the most recent valid set per check while scanning history, instead of repeatedly searching all earlier sets. Tests compare selected deepest frames with the earlier implementation on generated squat and push-up traces, including a flat bottom.

## Verification and limits

The simulator unit suite passed with 480 test definitions and 485 parameterized runs, including form detection, trend gating, frame selection, and Coach grounding. This confirms software behaviour on synthetic and stored fixtures. It does not establish real-world detection accuracy for every body, camera placement, clothing choice, lighting condition, or supported exercise. A labelled physical-video evaluation and live iPhone capture remain necessary before claiming a measured improvement in accuracy. The MWM iPhone build is still waiting for device registration and provisioning.

Apple references: [Vision 2D pose and confidence](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images), [Vision 3D pose](https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images), [Foundation Models guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation), and [model availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).
