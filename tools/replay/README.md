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

`fixtures/` contains three regression videos and one known-issue video, all entirely synthetic: a side-view squat assembled from generated standing, halfway, and bottom poses (six repetitions); a held standing pose (zero repetitions); and two versions of the squat with parts of the lower body covered. They contain no recording of a real person. Run the three regression clips through the real macOS Vision extractor and the production exercise analyzer:

```sh
tools/replay/test_generated_videos.sh
```

The expected results are six measured squat reps, a retake for no movement, and a retake when the lower body is hidden. The iOS simulator test also plays the squat video on the workout screen with its matching `squat-six-reps-poses.json`, captured from Vision on the same video. The GitHub iOS workflow runs both checks automatically. Source poses change in hard steps; this checks the video reader, Vision integration, evidence gate, rep counter, and visible app flow, but is not a realistic biomechanics or continuous-motion benchmark.

`fixtures/known-issue-feet-hidden.mp4` covers only the feet. In this experiment, Vision still inferred ankle positions with enough confidence to count six reps, despite the missing visual evidence. Reproduce with `tools/replay/replay.sh --exercise bodyweightSquat --video tools/replay/fixtures/known-issue-feet-hidden.mp4`. This is a known limitation, not a passing safety check. Confidence alone cannot prove that a joint is visible; do not use these fixtures to claim reliable analysis under partial occlusion.

Generated fixtures verify navigation, timing, scoring rules, and refusal. A blank video checks that the Mac pipeline runs and refuses absent pose. Neither proves that a real iPhone can see a particular person, that camera angle estimation is accurate, or that a cue is sound coaching. Those require consented real movement clips and physical-device validation before public claims.
