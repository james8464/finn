# Exercise rules v1 and the 3D camera-angle check

**Status on 13 October 2026: implemented and tested on the iOS 27 simulator with synthetic pose traces and generated-video replays, and the analysis logic with walk-in, walk-out, occlusion and wobble traces in a Linux build of the same Swift files.** Earlier capture versions were replayed on Vision poses from public side-view videos (see "Replay on real videos" below); the current revision (`squat-side-v7`, `*-side-v6`) has not. No expert review or physical-iPhone run exists yet for anything on this page. The squat keeps its own protocol in [`squat-v1-protocol.md`](squat-v1-protocol.md).

## How a rule is written

Each exercise is one entry in [`ExerciseDefinition.swift`](../../Plumb/Plumb/Workout/ExerciseDefinition.swift). It names the joints that must stay visible on the side facing the camera, a joint that should stay still (planted feet or hands), one movement signal, the thresholds of the two phases of a rep, the expected camera view, and every sentence the app shows. One analyzer runs every entry with the same state machine and the same evidence gate as the squat.

The starting value comes from the whole set, not its first frames: the 10th percentile of hip height for the squat (hips at their highest) and the 90th percentile of the joint angle for the others (joint at its most open). A set can therefore start mid-movement. Each rep is measured from its own local top, the highest or most open point since the previous rep ended, because a real phone's view drifts by a few percent during a set and people doing continuous reps rarely stand all the way up. A rep begins when the signal leaves that local top, counts only if it reaches the bottom phase and comes back by the return margin, and ends when the person is back near the top or has come back 65% of that rep's depth. Reps outside the duration window are dropped. After a set, the result says how many movements were too shallow (with the deepest one and the depth needed), too fast or too slow, or unfinished, so a set with no counted rep is never left unexplained.

| Exercise | Rubric | Signal on the camera-facing side | Must stay visible | Still joint | Leave top / reach bottom / back at top / return margin | Rep duration |
| --- | --- | --- | --- | --- | --- | --- |
| Bodyweight squat | `squat-side-v7` | Hip drop divided by standing hip-to-ankle height | hip, knee, ankle | ankle | 0.10 / 0.15 / 0.05 / 0.04 | 0.5 to 8 s |
| Push-up | `push-up-side-v6` | Elbow angle closing (shoulder, elbow, wrist), degrees | shoulder, elbow, wrist | wrist | 25° / 40° / 15° / 10° | 0.4 to 8 s |
| Static lunge | `static-lunge-side-v6` | Knee angle closing (hip, knee, ankle), degrees | hip, knee, ankle | ankle | 20° / 35° / 15° / 10° | 0.5 to 8 s |
| Stiff-leg deadlift | `stiff-leg-deadlift-side-v6` | Hip angle closing (shoulder, hip, knee), degrees | shoulder, hip, knee, ankle | ankle | 20° / 35° / 15° / 10° | 0.6 to 10 s |

A pause or wobble on the way down no longer fixes a rep's depth: the deepest point until the rep ends is its range. A set that opens partway down its first rep (it started during the countdown) measures that rep from the set's top.

The rep durations are shorter than in the first versions because a rep now ends 65% of the way back up instead of at the very top; at the old minimums, one-second squats on real video were dropped as too fast.

Angles are computed in pixel proportions: the y distance is scaled by the image height divided by its width before the angle is taken.

All four use the squat's evidence rules: joint confidence at least 0.3, the required joints present and confident in 80% of frames, no tracking gap over 0.75 s (3 s while someone else is in view, see "Other people in view" below), the still joint staying within 10% of the frame (spread between its 10th and 90th percentile positions, so one misplaced detection does not count as the phone moving), and a set of at least 2 seconds. A refusal names what was missing, with numbers: the share of frames where the joints were seen and the hardest joint to see, the length and start of the tracking gap, or how far the still joint moved. They also share the observation rule: when the last two reps' range is 85% or less of the first two, the result names those reps ("Your elbow bend became smaller in the last two reps.") and gives an exercise-specific next action tied to that range. Comparisons only pair sets of the same exercise in one session.

Since the 13 October camera-capture revision (`squat-side-v5`, `*-side-v4`), every third analyzed frame also asks Vision for a fast person mask. A joint inside the skeleton but outside the person mask is removed before the evidence gate sees it. Since `squat-side-v7` (`*-side-v6`), the search around each joint is 4% of the athlete's body size (at least two mask pixels) instead of two mask pixels, because the fast mask is thin at the hands and feet and refused visible ankles on the silhouette's edge; a missing or empty mask counts as no check instead of hiding every joint; and only the joints a check refuted stay out of the two frames until the next check. The generated covered-feet clip's cover stops about 6% of the frame above the ankle, outside the search. This guards against a confident ankle inferred behind an obstruction. Generated video fixtures measure six clear squats in the original, dim, farther, and slower versions, and refuse no motion, hidden legs, covered feet, and a too-small subject. The mirrored diagnostic is refused because its joint coverage is below the gate. Their abrupt pose changes and synthetic imagery do not establish sensitivity or specificity on real people. Person segmentation covers bystanders too, so the physical-device holdout must include partial occlusions, overlapping people, and false-refusal measurement.

## The set itself, not the walk

Since `squat-side-v7` (`*-side-v6`), a capture is trimmed to the set (`SetWindow`). On a real phone the person starts the capture at the phone and walks to their spot, then walks back to stop it; the legs leave the picture as they come close and the planted foot slides across the frame. Measured as part of the set, those frames were refused as a tracking gap or a moving phone. The set runs from the first moment the athlete is in position (the exercise's joints clear on one side and the still joint within 8% of the frame of its usual place, held 0.6 s) to the last one, widened over frames where the athlete is still at the spot with a joint unclear: the hip (the shoulder for push-ups) within 12% of the frame of its place and the shoulder-to-hip length within 25% of its usual size. Walking toward the phone makes the torso grow well past that before the legs leave the picture. Reps done at the spot with an ankle hidden therefore stay in the set and are judged by the gate; only walking in and out is trimmed. When no in-position stretch lasts 2 s, nothing is trimmed and the refusal describes the whole capture.

## Hands-free capture

With hands-free on (the default in the app), the countdown starts once the athlete has held still in position for 1.5 s (the still joint within 4% of the frame) in the exercise's starting posture: standing, or for the push-up a plank (torso closer to horizontal than vertical, hands below the shoulders). A slight angle seen by the 3D check does not hold the start; a clear front view does. During the set, the same analysis runs every 0.4 s of frames to show and say the reps counted so far; a rep clearly faster (under 70% of the first three reps' median time) or shorter (85% or less of the first two reps' range) than the person's own first reps is shown and said once, then not again for three reps. After at least one rep, the set ends when the athlete is seen walking off their spot for 2 s, is unseen for 4 s (longer than the gate's 3 s allowance for someone passing in front), or adds no rep for 8 s (the exercise's longest rep plus 2 s, if longer) while the analysis accepts the set and sees the athlete at the top, not partway through a slow rep.

## Most frequent pattern

Each measured set saves what it showed: movements too shallow to count, too fast or slow to count, an unfinished last movement, the end-of-set range or posture observation, a rep faster than the first ones, an angled view. The pattern seen in at least 2, and at least 30%, of the person's last 10 sets of an exercise becomes the focus shown before the next set and named again when it comes back. Thresholds do not change; only the emphasis does.

## Posture advice (new on 13 October)

At the deepest phase of each completed rep, the analyzer takes the median posture reading from nearby frames. Supporting joints must have confidence of at least 0.5. The first two and last two reps must all have readings, and their movement ranges must be within 10%. Both final readings must rise beyond the first pair's average by the threshold below. An angled view above 30° suppresses posture advice when 3D angle estimates are available; missing supporting joints suppress it without losing otherwise valid rep counts. The result still shows at most one cue and falls back to the existing range observation when appropriate.

| Exercise | Camera-visible change | Minimum rise | Suggested focus |
| --- | --- | --- | --- |
| Squat | Torso angle farther from upright | 12° | Keep torso angle similar across reps |
| Push-up | Hip lower relative to the shoulder-to-ankle line | 6% of that line's length | Keep hips aligned with shoulders and ankles |
| Static lunge | Torso angle farther from upright | 12° | Keep torso angle similar across reps |
| Stiff-leg deadlift | Knee bend increased | 12° | Keep a comfortable, similar knee bend |

These thresholds are hypotheses for detecting change within one person's set. They are not target angles, proof of poor form, or a complete technique assessment. A qualified trainer and physical-iPhone sessions must review false cues and the wording before claiming coaching accuracy.

A test replays 600 synthetic squat traces through a frozen copy of `squat-side-v2`. The current version must measure every set version 2 measured, give the same count on more than half of them, count fewer reps on at most one set in twenty, and never more than one rep fewer. On the current code: 281 sets measured by both, 177 with the same count, 1 with one rep fewer, none lost.

## Other people in view

Since `squat-side-v4` (and `*-side-v3` for the other exercises), Plumb follows one athlete instead of refusing a set when someone else is in view. `AthleteTracker` picks the most prominent person while framing (large and near the centre) and moves to someone else only if they are clearly more prominent. When the set starts it locks onto that person. In every frame it takes the person whose clear joints are closest to where the athlete's same joints were last seen; the median distance must stay under 12% of the athlete's size between frames, up to a third after a gap. Comparing joint by joint keeps the track when Vision drops the legs for a frame. When two people fit almost equally well, the frame has no athlete rather than risk a swap. Other people are drawn thin and grey on the camera screen and never analyzed. The 3D view check only uses an estimate whose root falls on the athlete.

A frame without the athlete is a gap. A gap while someone else stands where the athlete was last seen (any of their clear joints within a quarter of the athlete's size of the athlete's last box; usually walking between the athlete and the phone) may last 3 s; any other gap keeps the 0.75 s limit, including one with someone standing elsewhere in the room (until 13 October, anyone anywhere in view allowed 3 s). A tracking-gap refusal names only the joints that were lost. During a set, the tracker picks the athlete up again after 1 s without a match when exactly one person is in view, at 0.5 to 2 times the athlete's size, overlapping where they were last seen, and not where someone else stood when the athlete was last matched (a coach beside them is never taken for them; getting down into a push-up can make Vision miss the athlete for a moment). A longer occlusion is refused with "Someone else was in view and Plumb lost you for 4.1 s, starting 7.9 s into the set...". Frames from a source that does not follow one person keep the old rule: another person for 0.35 s or in over 20% of frames refuses the set.

The same 50 Mendeley squat videos were run through the app's own capture analysis on a Mac (Vision, then the tracker, then the squat rubric). Other people are in view in most of them: in 45 of 50 for at least a fifth of the frames.

| 50 gym videos, app capture path | Without tracking (v3 rules) | With tracking (v4) |
| --- | --- | --- |
| Measured | 5 | 44 |
| Refused | 45, "Another person was in view" | 6: joints seen in under 80% of frames (3), ankle moved 11 to 18% (3) |
| Counts within one rep of the dip counter | | 43 of 44 (21 exact) |

The one count off by more than a rep is a "bad form" set (9 against 13 dips). Videos with someone walking right in front of the athlete are rare in this set, so the 3 s occlusion limit is a starting value.

## Replay on real videos

Version 2 counted no squat on Guilhem's iPhone. To reproduce it without filming anyone, the app's own Vision request was run over 50 side-view squat videos and 48 push-up videos from the Mendeley dataset used for exercise recognition (CC BY 4.0, see `tools/exercise-classifier/angle-model/README.md`; the videos and poses stay outside the repository), and the analyzer was replayed on those poses with the 3D check off.

| | `squat-side-v2` | `squat-side-v3` |
| --- | --- | --- |
| Squat videos measured | 0 of 50 | 42 of 50 |
| Why refused | joint confidence under 0.6 on every video: Vision gives real hips about 0.5 | still joint moved 10 to 18% (5 videos, phones in a busy gym), joints seen in under 80% of frames (2), 0.8 s tracking gap (1) |
| Counts | | 7 to 22 reps per 30-second video |

There is no human count for these videos yet. Two checks stand in for one. A separate counter that finds dips in the smoothed hip height, with no state machine and no thresholds from the app, agrees within one rep on all 42 measured videos and exactly on 19. Counting by eye on stills taken three times a second gave about 15 reps for subject 002 (app: 15) and 16 for subject 014 (app: 16). Earlier drafts of version 3 counted 11 and 10 on them; on subject 014 the person stopped coming back to the set's starting height after a few reps, so later reps were timed from that last full stand and dropped as longer than 8 s. Measuring each rep from its own local top fixed it.

Push-ups: 33 of 48 measured with `push-up-side-v2`. Counts are low on several "bad form" videos where the elbow bends less than 40°, which is the rule working; 24 of 33 agree within one rep with the same kind of dip counter on the elbow angle. Lunges and deadlifts have no real video.

A 10° phone tilt changes neither count: the squat signal is a ratio of vertical distances on the same frame, the knee angle does not depend on the frame's rotation, and the 3D check measures the body's axis relative to the camera. `tenDegreePhoneTiltDoesNotChangeTheCount` covers it.

## Limits

- The push-up, lunge, and deadlift thresholds are starting values chosen to sit between typical full and partial movements. No trainer has reviewed them and no real set has been counted.
- A rule trusts the chosen exercise. A push-up analyzed with the squat rule can still produce squat reps, because the squat signal is the hip dropping. The exercise picker, or the classifier once trained, has to be right.
- The lunge measures the knee on the side facing the camera, which can be the front or the back leg. Comparing two sets only makes sense with the same front leg; the setup text asks for it, the app does not check it.
- The deadlift rep counter still measures the hip angle only. The optional posture cue can flag increasing knee bend, but cannot certify a stiff-leg deadlift or reject a squat-like movement.
- The push-up rep counter still measures elbow bend only. The optional posture cue compares hip alignment across reps, but cannot certify a straight body line.

## 3D camera-angle check

**What it does.** About four times per second (every fourth processed frame at 15 fps), the capture code runs `VNDetectHumanBodyPose3DRequest` on the same camera frame as the 2D pose. It moves the hips and shoulders into the camera's frame with `cameraOriginMatrix` and computes the angle between the body's left-right axis and the line from the camera to the hips: 0° is a true side view, 90° faces the camera or turns away from it.

- Median of the set's estimates at 30° or less: nothing to say.
- Above 30°: the set is measured, and the result adds "Plumb saw you about N° from side-on. Turn a little more side-on next time; counts are most reliable from the side." While framing, three of the last five estimates above 30° show "Turn a little: side to the camera". Neither stops the set.
- At 75° or more, with estimates spanning at least 3 s: the set is refused with "This exercise needs a side view. Turn so your side faces the camera, then try again. Plumb measured about N° away from the view it needs."
- Fewer than four estimates: no decision, and the 2D rules apply alone, as on the simulator.

**What went wrong before (fixed 12 October 2026).** Earlier builds took joint positions from `cameraRelativePosition`, which only shifts each joint by the root's position without turning it into the camera's axes. Every body then looked square to the camera, and the check refused every set with a 30° limit: run through the app's capture code, 50 public side-view squat videos gave medians of 74 to 89°, and all 50 were refused. This is the likely reason squats were never counted on a real iPhone.

**Measured since the fix.** Vision 3D pose on the Mac, every 0.5 s, on the Mendeley squat videos (CC BY 4.0, kept outside the repository):

| Camera view | Videos | Median per video, 10th / 50th / 90th percentile | At 75° or more |
| --- | --- | --- | --- |
| Side | 50 | 14° / 21° / 47° | 0 |
| Diagonal | 50 | 40° / 48° / 59° | 0 |
| Front | 50 | 82° / 85° / 87° | 50 |

So 75° separates front views from the rest on these videos. 30° sends the turn tip to 15 of the 50 side videos: the phones in this dataset were placed by hand in a busy gym and not all are square to the person, and Vision 3D pose is noisy (single estimates often read 60 to 75° on side videos). That is why only the median over several seconds can refuse.

**Switch.** Options → **Check the camera angle in 3D**, on by default. Turning it off stops the 3D requests.

**Validation readout.** Launch from Xcode with `-plumb-validation`. While framing, a capsule shows "3D view: N° from profile" or "no estimate". The result shows the set's median, the number of estimates, and whether the check accepted or refused the set. These lines exist only in Debug builds.

**Simulator coverage.** Unit tests check the geometry on synthetic bodies turned 0°, 15°, 45°, 60°, and 90°, with swapped left and right labels, the median rule, the three outcomes, a brief front view that does not refuse, the framing prompt, and the switch. A Debug-only demo feed (`-plumb-ui-demo-front-view`) attaches a fixed 75° value so UI tests can follow the refusal path. Vision 3D pose does not run on the simulator; the table above comes from the Mac.

## To check on a physical iPhone

1. With `-plumb-validation`, frame yourself side-on. If the capsule keeps saying "no estimate", the 3D request is not running on this device; note the model and iOS build.
2. Stand side-on, at about 45°, facing the camera, and with your back to it. Write down the readout for each. Side-on should read under 30°, 45° between 30 and 75°, and the front and back views 75° or more. Change `ViewCheck.maximumSideDeviationDegrees` or `clearlyFrontDegrees` only from those readings, and record the change.
3. Repeat side-on in the push-up position (body horizontal) and at the bottom of a deadlift (torso bent). The hip and shoulder axis should still read low.
4. Try both sides facing the camera.
5. Compare a two-minute set with the check on and off: frame rate, heat, and "Stop to result" latency.
6. For each exercise, count reps by hand and compare with the app on a few sets, including a deliberately shallow set and an incomplete last rep.
7. If the check refuses a side-on set, note the readout, switch it off in Options for the demo, and say so; the 2D visibility rules still run.

For the squat holdout in [`squat-v1-protocol.md`](squat-v1-protocol.md), keep the 3D switch in one position for every holdout set and write which one in `notes`, because it can refuse a set that the 2D rule alone would have measured.
