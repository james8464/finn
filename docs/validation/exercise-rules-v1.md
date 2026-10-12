# Exercise rules v1 and the 3D camera-angle check

**Status on 12 October 2026: implemented and tested on the iOS 27 simulator with synthetic pose traces only.** No real set, expert review, or physical-iPhone run exists yet for anything on this page. The squat keeps its own protocol in [`squat-v1-protocol.md`](squat-v1-protocol.md).

## How a rule is written

Each exercise is one entry in [`ExerciseDefinition.swift`](../../Plumb/Plumb/Workout/ExerciseDefinition.swift). It names the joints that must stay visible on the side facing the camera, a joint that should stay still (planted feet or hands), one movement signal, the thresholds of the two phases of a rep, the expected camera view, and every sentence the app shows. One analyzer runs every entry with the same state machine and the same evidence gate as the squat.

The first five tracked frames set the starting value, so a set has to start in the top position. A rep begins when the signal leaves the top phase, counts only if it reaches the bottom phase and comes back by a set margin, and ends when the signal is back at the top. Reps outside the duration window are dropped.

| Exercise | Rubric | Signal on the camera-facing side | Must stay visible | Still joint | Leave top / reach bottom / back at top / return margin | Rep duration |
| --- | --- | --- | --- | --- | --- | --- |
| Bodyweight squat | `squat-side-v2` | Hip drop divided by standing hip-to-ankle height | hip, knee, ankle | ankle | 0.10 / 0.15 / 0.03 / 0.04 | 0.8 to 8 s |
| Push-up | `push-up-side-v1` | Elbow angle closing (shoulder, elbow, wrist), degrees | shoulder, elbow, wrist | wrist | 25° / 40° / 15° / 10° | 0.6 to 8 s |
| Static lunge | `static-lunge-side-v1` | Knee angle closing (hip, knee, ankle), degrees | hip, knee, ankle | ankle | 20° / 35° / 15° / 10° | 0.8 to 8 s |
| Stiff-leg deadlift | `stiff-leg-deadlift-side-v1` | Hip angle closing (shoulder, hip, knee), degrees | shoulder, hip, knee, ankle | ankle | 20° / 35° / 15° / 10° | 1 to 10 s |

Angles are computed in pixel proportions: the y distance is scaled by the image height divided by its width before the angle is taken.

All four use the squat's evidence rules: joint confidence at least 0.6, the required joints present and confident in 80% of frames, no tracking gap over 0.75 s, no second person for 0.35 s or in over 20% of frames, the still joint moving less than 8% of the frame, and a set of at least 2 seconds. They also share the observation rule: when the last two reps' range is 85% or less of the first two, the result names those reps ("Your elbow bend became smaller in the last two reps.") and suggests "Try a pace you can keep consistent." Comparisons only pair sets of the same exercise in one session.

A test replays 600 synthetic squat traces through a frozen copy of the previous squat analyzer and requires the same outcome for each, so `squat-side-v2` behaves as before.

## Limits

- The push-up, lunge, and deadlift thresholds are starting values chosen to sit between typical full and partial movements. No trainer has reviewed them and no real set has been counted.
- A rule trusts the chosen exercise. A push-up analyzed with the squat rule can still produce squat reps, because the squat signal is the hip dropping. The exercise picker, or the classifier once trained, has to be right.
- The lunge measures the knee on the side facing the camera, which can be the front or the back leg. Comparing two sets only makes sense with the same front leg; the setup text asks for it, the app does not check it.
- The deadlift rule measures the hip angle only. It does not check that the knees stay nearly straight, so a squat-like movement can count.
- The push-up rule measures elbow bend only, not the hip line.

## 3D camera-angle check

**What it does.** About four times per second (every fourth processed frame at 15 fps), the capture code runs `VNDetectHumanBodyPose3DRequest` on the same camera frame as the 2D pose. From the camera-relative positions of the hips and shoulders, it computes the angle between the body's left-right axis and the line from the camera to the hips: 0° is a true side view, 90° faces the camera or turns away from it. While framing, when at least three of the last five estimates give a median above 30°, the status reads "Turn your side to the camera". After a set with at least four estimates whose median is above 30°, Plumb shows "This exercise needs a side view. Turn so your side faces the camera, then try again." instead of a result. With fewer estimates it does not decide and the 2D rules apply alone, as on the simulator.

**Switch.** Options → **Check the camera angle in 3D**, on by default. Turning it off stops the 3D requests.

**Validation readout.** Launch from Xcode with `-plumb-validation`. While framing, a capsule shows "3D view: N° from profile" or "no estimate". The result shows the set's median, the number of estimates, and whether the check accepted or refused the set. These lines exist only in Debug builds.

**Simulator coverage.** Unit tests check the geometry on synthetic bodies turned 0°, 15°, 45°, 60°, and 90°, with swapped left and right labels, the median rule, the framing prompt, and the switch. A Debug-only demo feed (`-plumb-ui-demo-front-view`) attaches a fixed 75° value so UI tests can follow the refusal path. None of this shows how Vision 3D pose behaves on a real person.

## To check on a physical iPhone

1. With `-plumb-validation`, frame yourself side-on. If the capsule keeps saying "no estimate", the 3D request is not running on this device; note the model and iOS build.
2. Stand side-on, at about 45°, facing the camera, and with your back to it. Write down the readout for each. Side-on should read well under 30° and the other three well above it. Change `ViewCheck.maximumSideDeviationDegrees` only from those readings, and record the change.
3. Repeat side-on in the push-up position (body horizontal) and at the bottom of a deadlift (torso bent). The hip and shoulder axis should still read low.
4. Try both sides facing the camera.
5. Compare a two-minute set with the check on and off: frame rate, heat, and "Stop to result" latency.
6. For each exercise, count reps by hand and compare with the app on a few sets, including a deliberately shallow set and an incomplete last rep.
7. If the check refuses side-on sets, switch it off in Options for the demo and say so; the 2D visibility rules still run.

For the squat holdout in [`squat-v1-protocol.md`](squat-v1-protocol.md), keep the 3D switch in one position for every holdout set and write which one in `notes`, because it can refuse a set that `squat-side-v2` alone would have measured.
