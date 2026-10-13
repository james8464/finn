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

The command prints JSON with `status` (`measured`, `retake`, or `failed`), `frameCount`, `measuredReps`, and a `reason` or `rubricVersion` when available. `--poses-output` is optional. Supported exercise values are `bodyweightSquat`, `pushUp`, `staticLunge`, and `stiffLegDeadlift`. The pose JSON can also be supplied to the app's Debug video-file path on the simulator with `-plumb-video-file <video> -plumb-video-poses <json>`; Xcode must make those files readable to the simulator process.

## Generated video checks

`fixtures/` contains synthetic videos only. The original four cover a six-rep side-view squat, a held standing pose, hidden legs, and covered feet. Twelve reproducible variants of the six-rep squat change light and color, subject size, framing, blur, apparent phone movement, or tempo. All variants derive from the same source person and motion; they are not new participants. Run them through the macOS Vision extractor and the same exercise analyzer as the app:

```sh
tools/replay/test_generated_videos.sh
```

Expected results on the current macOS Vision path: six measured reps for the original and the clear lighting, size, position, tilt, resolution, and tempo variants; a retake for no movement, hidden legs, covered feet, a person made too small, or phone shake. Motion blur asked for a retake until `squat-side-v7`; with the wider person-mask search it measures the six reps (CI run of 13 October). The mirrored clip is diagnostic: this generated pose falls below the current joint-coverage gate and asks for a retake. We do not loosen the gate to force a positive result. The iOS simulator tests play the clear and covered-feet clips on the workout screen with matching pose JSON captured from Vision. The GitHub iOS workflow runs these checks automatically. Source poses change in hard steps, so this tests the video reader, Vision integration, person-mask gate, and rep counter; it is not a realistic biomechanics benchmark.

| Variant | What it probes | Current replay |
| --- | --- | --- |
| [Mirrored](fixtures/squat-mirrored.mp4) | Opposite facing direction | Retake: required joints clear in about 71% of frames, below the 80% gate |
| [Dim](fixtures/squat-dim.mp4) | Lower light and saturation | 6 measured reps |
| [Farther](fixtures/squat-far.mp4) | Person at 60% of original size | 6 measured reps |
| [Too far](fixtures/squat-too-far.mp4) | Person at 30% of original size | Retake |
| [Slower](fixtures/squat-slow.mp4) | Longer rep duration | 6 measured reps |
| [Overexposed](fixtures/squat-overexposed.mp4) | Bright exposure and flatter contrast | 6 measured reps |
| [Warm indoor](fixtures/squat-warm-indoor.mp4) | Warmer color balance | 6 measured reps |
| [Low resolution](fixtures/squat-low-resolution.mp4) | Coarse source detail restored to the original frame size | 6 measured reps |
| [Off center](fixtures/squat-off-center.mp4) | Athlete nearer one edge | 6 measured reps |
| [Tilted phone](fixtures/squat-angled-phone.mp4) | Image plane rotated about 7° | 6 measured reps |
| [Motion blur](fixtures/squat-motion-blur.mp4) | Three-frame temporal blend | Six measured reps since `squat-side-v7` (a retake before: the blurred mask edge hid the ankles) |
| [Moving phone](fixtures/squat-phone-shake.mp4) | Frame shifts during the set | Retake: required joints are not clear often enough |

Rebuild the variants with `python3 tools/replay/generate_video_variants.py`. It uses `ffmpeg` on PATH or the local `imageio-ffmpeg` package; the checked-in MP4s let teammates run replay without generating them. These transformations reuse the same synthetic person and poses, so they are correlated tests rather than twelve new participants or independent technique examples. The tilted-phone video rotates a 2D frame; it does **not** test a real three-quarter camera viewpoint or the Vision 3D angle check.

`fixtures/squat-feet-hidden.mp4` covers only the feet. Before the 13 October capture change, Vision inferred ankles behind the obstruction and the app counted six reps. The new path uses [Vision person segmentation](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest) on every third analyzed frame; those ankles no longer pass the evidence gate. A person mask can still fail on real clothing, lighting, and overlaps with other people. The video is a regression for this one obstruction, not proof of reliable occlusion handling in general.

Generated fixtures verify navigation, timing, scoring rules, and refusal. A blank video checks that the Mac pipeline runs and refuses absent pose. Neither proves that a real iPhone can see a particular person, that camera angle estimation is accurate, or that a cue is sound coaching. Those require consented real movement clips and physical-device validation before public claims.
