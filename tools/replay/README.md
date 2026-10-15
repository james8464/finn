# Repeatable workout replay

The iOS simulator runs **Debug-only generated pose fixtures** for all four supported exercises. They pass through the normal setup, set, scoring, and result screens without anyone doing reps. Each fixture has six complete reps; a push-up fixture with a missing wrist checks that Plumb asks for a retake rather than making up measurements. Xcode launches them with `-plumb-ui-demo` or `-plumb-ui-demo-missing-wrist`. The yellow **DEMO INPUT** badge makes this mode unmistakable, and release archive verification excludes it.

Run the entire local iPhone suite with the `Plumb` scheme in Xcode, or run focused simulator UI tests:

```sh
xcodebuild test -project Plumb/Plumb.xcodeproj -scheme Plumb \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -parallel-testing-enabled NO \
  -only-testing:PlumbUITests/ExerciseOptionsUITests \
  -only-testing:PlumbUITests/WorkoutFlowUITests
```

For a saved video that you have permission to use, the Mac command reads its frames upright, samples at the app's 15 fps rate, runs the app's Vision pose extractor, and scores them with the **same exercise analyzer** as the iPhone. Pass an absolute path and keep recordings of real people and their pose JSON outside this repository:

```sh
tools/replay/replay.sh --exercise pushUp --video /absolute/path/to/clip.mov \
  --poses-output /tmp/plumb-pushup-poses.json
tools/replay/replay.sh --exercise pushUp --poses /tmp/plumb-pushup-poses.json
```

The Mac extractor can pad the picture with a black border before Vision sees it (`PLUMB_REPLAY_MARGIN=0.25 tools/replay/replay.sh ...`, a share of the picture size). Vision then finds the shoulders and head of a person the frame cuts off; the app's camera path does not do this. The JSON also gives `recognized`, the exercise the angle rules read from the poses whatever was chosen.

A push-up the arm rubric cannot read (filmed from the front, or so close that the arm is cut off) is counted from the shoulders going down and up (`push-up-shoulders-v2`, no elbow bend or posture). The hands must stay planted. On three real sets (local, not in this repository) it gave 10, 6 or 7, and 10 reps for 10, 7 and 10 performed.

The command prints JSON with `status` (`measured`, `retake`, or `failed`), `frameCount`, `measuredReps`, `repTimes` (start and end of each measured rep, in seconds, to check a count against the video), and a `reason` or `rubricVersion` when available. `--poses-output` is optional. Supported exercise values are `bodyweightSquat`, `pushUp`, `staticLunge`, and `stiffLegDeadlift`. The pose JSON can also be supplied to the app's Debug video-file path on the simulator with `-plumb-video-file <video> -plumb-video-poses <json>`; Xcode must make those files readable to the simulator process.

## One count, live and in the result

The live count is the analysis of the set so far, run every 0.4 s on the frames seen, with the same analyzer as the result. Measured over a longer set, a movement said as a rep can stop counting: on 15 October Guilhem did fast push-ups (about 0.65 s a cycle) and the top the set is measured from settled lower as the set went on; reps measured from it became too fast or merged. The live count then kept every rep it had ever said, reached 29 and froze there, while the result gave 18. Since 15 October the live count follows the analysis, down as well as up (`LiveSetEvent.repCountRevised`, shown and never spoken, and a number is never said twice), and the result's count replaces it when the set ends. The replay JSON gives `liveMaxReps`, the highest number the live count showed: above `liveReps`, the person saw the count come down. A movement that goes down again before coming back up far enough to end a rep is over at the turn: it is not a rep (`incomplete` in the diagnostics, said on the result), and the next one is measured from where the person turned. Before, that rep stayed open and every later dip merged into it: twelve fast push-ups whose tops sat below the opening plank gave one 6.7 s rep, with the live count climbing to 11 and falling to 1. The push-up tempo floor went from 0.4 s to 0.25 s (`push-up-side-v7`, `push-up-shoulders-v2`): a full bend at that pace is a rep, and the 40° bend a rep needs keeps Vision's flicker out.

Local replays on 15 October, phone on the floor, filmed from the front (Théophile; the recordings stay outside the repository):

| Recording | Done by hand | Before | After |
| --- | --- | --- | --- |
| 20 push-ups, fast | 20 | 20, live 20 | 20, live 20 (never above 20) |
| 7 descents on the knees or the fists, none a push-up | 7 | 6, live 6 | 6, live 6 (the one with the face at the floor loses the shoulders) |
| Théophile's six sets of 14 October | 11, 10, 10, 7, 10, 13 | 11, 10, 10, 6, 10, 13 | unchanged, live never above the result |

## Generated video checks

`fixtures/` contains synthetic videos only. The original four cover a six-rep side-view squat, a held standing pose, hidden legs, and covered feet. Twelve reproducible variants of the six-rep squat change light and color, subject size, framing, blur, apparent phone movement, or tempo. All variants derive from the same source person and motion; they are not new participants. Run them through the macOS Vision extractor and the same exercise analyzer as the app:

```sh
tools/replay/test_generated_videos.sh
```

Expected results on the current macOS Vision path: six measured reps for the original and the clear lighting, size, position, tilt, resolution, and tempo variants; a retake for no movement or hidden legs. Covered feet, phone shake and strong motion blur give six reps counted from the hips (`squat-trunk-v1`, see below). The person made too small was refused until the reliability pass of 13 October and now measures its six reps. The mirrored clip asked for a retake until `squat-side-v7`; with the wider person-mask search and the set window, it measures the six reps (local macOS replay, 13 October). The mirrored clip stays diagnostic: the script accepts either result for it. Each clip also runs the hands-free path frame by frame, as the camera feeds it (`LiveSetMonitor`, `StartReadiness`): on a measured set the live count may never exceed the result and may be at most one rep behind it (on a refused set it is provisional: the too-small and phone-shake clips count one live rep before the gate refuses them), and the script prints the live cues and when a hands-free start would trigger. On the recorded six-rep poses the live count is 6 with no cue and the start triggers after 1.5 s of standing; on the covered-feet poses it counts the six squats from the hips and never starts (the ankle is never clear while framing). We do not loosen the gate to force a positive result. The iOS simulator tests play the clear and covered-feet clips on the workout screen with matching pose JSON captured from Vision. The GitHub iOS workflow runs these checks automatically. Source poses change in hard steps, so this tests the video reader, Vision integration, person-mask gate, and rep counter; it is not a realistic biomechanics benchmark.

| Variant | What it probes | Current replay |
| --- | --- | --- |
| [Mirrored](fixtures/squat-mirrored.mp4) | Opposite facing direction | Six measured reps since `squat-side-v7`; before, a retake with required joints clear in about 71% of frames, below the 80% gate |
| [Dim](fixtures/squat-dim.mp4) | Lower light and saturation | 6 measured reps |
| [Farther](fixtures/squat-far.mp4) | Person at 60% of original size | 6 measured reps |
| [Too far](fixtures/squat-too-far.mp4) | Person at 30% of original size | 6 measured reps since the reliability pass of 13 October (side rubric); before, a retake with the joints visible in about 62% of frames |
| [Slower](fixtures/squat-slow.mp4) | Longer rep duration | 6 measured reps |
| [Overexposed](fixtures/squat-overexposed.mp4) | Bright exposure and flatter contrast | 6 measured reps |
| [Warm indoor](fixtures/squat-warm-indoor.mp4) | Warmer color balance | 6 measured reps |
| [Low resolution](fixtures/squat-low-resolution.mp4) | Coarse source detail restored to the original frame size | 6 measured reps |
| [Off center](fixtures/squat-off-center.mp4) | Athlete nearer one edge | 6 measured reps |
| [Tilted phone](fixtures/squat-angled-phone.mp4) | Image plane rotated about 7° | 6 measured reps |
| [Motion blur](fixtures/squat-motion-blur.mp4) | Nine-frame temporal blend with strong spatial blur | 6 reps counted from the hips (`squat-trunk-v1`, since 15 October); the side rubric refuses it, the hip clear in about a fifth of the frames |
| [Moving phone](fixtures/squat-phone-shake.mp4) | Frame shifts during the set | 6 reps counted from the hips (`squat-trunk-v1`, since 15 October); the side rubric refuses it |

Rebuild the variants with `python3 tools/replay/generate_video_variants.py`. It uses `ffmpeg` on PATH or the local `imageio-ffmpeg` package; the checked-in MP4s let teammates run replay without generating them. These transformations reuse the same synthetic person and poses, so they are correlated tests rather than twelve new participants or independent technique examples. The tilted-phone video rotates a 2D frame; it does **not** test a real three-quarter camera viewpoint or the Vision 3D angle check.

`fixtures/squat-feet-hidden.mp4` covers only the feet. Before the 13 October capture change, Vision inferred ankles behind the obstruction and the app counted six reps. The new path uses [Vision person segmentation](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest) on every third analyzed frame; those ankles no longer pass the evidence gate, so the side rubric does not measure the set. Since 15 October its six squats are counted from the hips instead, without depth in leg lengths and without posture advice. A person mask can still fail on real clothing, lighting, and overlaps with other people. The video is a regression for this one obstruction, not proof of reliable occlusion handling in general.

Generated fixtures verify navigation, timing, scoring rules, and refusal. A blank video checks that the Mac pipeline runs and refuses absent pose. Neither proves that a real iPhone can see a particular person, that camera angle estimation is accurate, or that a cue is sound coaching. Those require consented real movement clips and physical-device validation before public claims.

## Squats counted from the hips (`squat-trunk-v1`)

On 15 October Guilhem filmed squats with the phone on the floor, tilted up, mostly facing it. The live count reached 3 and stayed there for the rest of the set: the side rubric is measured on the whole set so far, and once the knee and ankle had been unclear in more than a third of it (or lost for longer than 0.75 s), every later analysis refused the set. A front view also refused the result, and an athlete who stepped out of the picture and came back elsewhere was never followed again.

When the side rubric refuses a squat set or counts fewer reps, `ExerciseAnalyzer` now counts it from the height of the hips (either side), with the shoulders standing in when Vision loses both hips. Heights are divided by the set's median torso length, and the rep thresholds follow the set's own travel, never under 0.3 torso lengths. A gap of more than 1 s starts the next rep afresh, and frames where the torso looks 1.4 times longer than usual (the athlete at the phone) are left out. The result says the reps were counted from the hips and gives no posture advice.

Local replays (poses extracted on a Mac with this tool; the recordings stay outside the repository):

| Recording | Squats done | Before | After |
| --- | --- | --- | --- |
| Guilhem, screen recording, set 1 (front, then side; phone on the floor) | 2 | 0 | 2 |
| Guilhem, screen recording, set 2 | 7 | 0 (3 live on the iPhone) | 6 (the squat done facing away, while Vision saw nobody, is missed) |
| Théophile, squat sets 1, 3 and 6 (side, phone on the floor) | 11, 10, 13 | 11, 10, 13 | 11, 10, 13 |
| Théophile, push-up sets 2, 4 and 5 | 10, 7, 10 | 10, 6, 10 | 10, 6, 10 |

The screen recording has the app's counter drawn over the legs, so Vision on the Mac sees the knees and ankles less often than the iPhone did. On 150 squat videos of the Mendeley multi-view dataset (no rep counts published), all 50 front views were refused before and are now counted; the count matches the old live count on 38 of them. Six videos whose count changed were checked by eye: 2 of 2 front, diagonal and side sets with the reps the old set window cut off (for example 15 squats on subject 20 side, 11 counted before) match the video.
