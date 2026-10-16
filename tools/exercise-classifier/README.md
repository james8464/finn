# Exercise recognition: angle rules, and optional trained models

Finn recognizes which exercise a person did from Vision joint angles, with hand-written rules that need no training and ship in every build (`AngleRules` in `PoseWindowFeatures.swift`). Options → **Recognize the exercise automatically** is on by default; when the rules are not sure, Finn uses the exercise chosen on the first screen. The team chose this as Finn's method on 12 October 2026: the Vision skeleton, joint angles, and ranges of good movement.

Trained models are optional and get no further work for now. The tools in this folder stay so the team can try one later. When a build includes a model, Options shows **Use the trained model instead (experimental)**, off by default; switched on, the app uses the first model the build has:

1. a Create ML action classifier on Vision keypoint sequences (`FinnExerciseClassifier.mlmodel`), trained from the team's own clips; the filming and training steps below are for this one;
2. a boosted-tree classifier on joint-angle windows (`FinnAngleClassifier.mlmodel`), trained on 12 October from public videos and synthetic poses; see [`angle-model/README.md`](angle-model/README.md).

None of the two models is in the repository yet. If no recognizer is confident, Finn uses the exercise chosen on the first screen, and the result says so.

Recognition only answers "which exercise is this". It does not judge technique. The rep counting and the observation still come from the rules in `Finn/Finn/Workout/ExerciseDefinition.swift`.

## Classes

| Folder label | What to record |
| --- | --- |
| `squat` | Bodyweight squats, side view |
| `push_up` | Push-ups, side view |
| `static_lunge` | Static lunges (split squat, feet planted), side view |
| `stiff_leg_deadlift` | Stiff-leg deadlifts, bodyweight or a light bar, side view |
| `other` | Other movement in the same setup: walking in and out, stretching, arm circles, adjusting the phone, sitting down |
| `none` | Standing or resting in frame between sets, barely moving |

The four exercise labels must match `classifierLabel` in `ExerciseDefinition.swift`; a unit test checks this. `other` and `none` matter as much as the exercises: they teach the model to say "not an exercise I know", which makes Finn fall back to the manual choice.

## Recording format

- One person per recording, nobody else in frame. Each participant agrees before filming, and knows the videos stay on the team's Mac and are deleted after training.
- iPhone Camera app, Video, 1080p or 720p at 30 fps, phone upright (portrait) on a stable surface. Front or back camera both work; training flips clips horizontally anyway.
- Place the phone the way Finn asks: hip height and a few steps away for squats, lunges, and deadlifts; on the floor or a low step for push-ups. Whole body in view, side to the camera.
- One take is 25 to 40 seconds of one class, done continuously at a normal pace. Film one take with the left side to the camera and one with the right side.
- Name each file `<participant>_<label>_<take>.mov` with a two-digit participant and take number: `p01_push_up_01.mov`, `p03_stiff_leg_deadlift_02.mov`. Use participant codes, not names.

With four people and two takes per class, that is 48 recordings, roughly an hour of filming. A 30-second take gives nine 3-second clips, so each class gets about 72 clips. Holding one person out for validation leaves about 54 training clips per class, above the 50 that Apple suggests per class for an action classifier.

## Cut the recordings into clips

AirDrop the recordings into one folder outside the repository, for example `~/finn-clips/raw`. Then, from the repository root:

```sh
python3 tools/exercise-classifier/prepare_clips.py ~/finn-clips/raw ~/finn-clips/dataset \
    --validation-participants p04 --dry-run
python3 tools/exercise-classifier/prepare_clips.py ~/finn-clips/raw ~/finn-clips/dataset \
    --validation-participants p04
```

The dry run prints the clip count per class and split, and warns about classes under 50 training clips. The second command cuts 3-second clips (skipping half a second at each end of a take), removes the audio, and writes `train/<label>/`, `validation/<label>/`, and `manifest.csv`. Every clip from a held-out participant goes to validation, so the validation score measures a person the model never saw. Without `--validation-participants`, Create ML splits clips at random, and clips from the same take land on both sides; the score then looks better than it is. The script needs `ffmpeg` (`brew install ffmpeg`) and refuses to write inside the repository.

## Train

```sh
xcrun swift tools/exercise-classifier/train_exercise_classifier.swift \
    ~/finn-clips/dataset ~/finn-clips/FinnExerciseClassifier.mlmodel
```

Create ML extracts Vision body poses from every clip, then trains an action classifier on those pose sequences. Apple's WWDC20 demo took about 30 minutes to extract poses from 362 videos on a Mac, so plan for tens of minutes. The script prints training accuracy, validation accuracy, and the validation confusion table, and writes a `.report.json` next to the model. Copy those numbers into the pull request or the validation notes as they are; they come from clips, not from the live app.

The defaults are a 15 fps pose rate and a 30-frame window, so each prediction covers 2 seconds. Finn samples poses at up to 15 fps during a set, and the script stores both values in the model's metadata, where the app reads them. If you train in the Create ML app instead, keep its 30 fps default: a model without Finn metadata is assumed to use 30 fps.

## Install in the app

```sh
cp ~/finn-clips/FinnExerciseClassifier.mlmodel Finn/Finn/FinnExerciseClassifier.mlmodel
```

Xcode compiles it into the app on the next build; no project change is needed. The Options page then shows **Use the trained model instead (experimental)**, off by default. When it is on, after each set Finn classifies overlapping 2-second windows of the captured poses (at most 40). It uses the recognized exercise only when at least 60% of the windows agree on it with a confidence of 0.8 or more. Otherwise, or when the winner is `other` or `none`, it uses the exercise chosen on the first screen, and the result screen says which one it used. These two thresholds are starting values, not measured ones.

The repository is public. The model contains no video, but it was trained on the team's poses; decide together before committing it. Delete the recordings and clips once the model is final.

## Check it on an iPhone

The validation score says how the model does on clips. It does not show how the app does live. On a physical iPhone with recognition turned on:

1. Do one set of each exercise from the recommended view, with the manual choice set to a different exercise. Note what the result screen says.
2. Do a set of something outside the four classes, such as jumping jacks. Finn should fall back to the manual choice.
3. Repeat one exercise with the other side facing the camera.
4. Note any wrong recognition with the exercise, the side, and the camera position.

## Files

- `prepare_clips.py`: cuts and labels recordings. Standard library plus `ffmpeg`.
- `test_prepare_clips.py`: its tests; `python3 -m unittest discover -s tools/exercise-classifier -p 'test_*.py'`.
- `train_exercise_classifier.swift`: the Create ML training script. It typechecks and validates its inputs; it has not run on real clips yet because none exist.
- `make_test_fixture.py`: rebuilds `Finn/FinnTests/Fixtures/ConstantPushUpClassifierFixture.mlmodel`, a model that always answers `push_up` with probability 0.92. It was never trained. It only lets the unit tests run Core ML on the simulator with the same interface as a Create ML action classifier. It needs `coremltools`, which the app and CI do not use.
