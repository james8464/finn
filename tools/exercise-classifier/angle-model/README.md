# Angle model and rule-based recognizer

Two ways to recognize the exercise from Vision's 2D joints, both built on the same numbers: `PoseWindowFeatures` in `Plumb/Plumb/Workout/PoseWindowFeatures.swift`. For each 2.5-second window (1.25 s apart) they hold the spread of the elbow, knee, hip, and shoulder angles, their medians, the torso tilt from vertical, how far the hips drop, the gap between the ankles, and where the wrists sit. The camera-facing side is the one Vision tracks with more confidence; for the hips and shoulders, which overlap in a side view, the far side stands in when the near one is missing.

- **Rules** (`AngleRules`, used by `AngleRuleClassifier`): which joint moves, by how much, and how the torso is tilted. Push-up: torso near horizontal and straight at the hip, elbows bend, knees stay straight. Stiff-leg deadlift: the hip hinges through at least 35° as the torso tips forward and comes back, with straight knees and straight arms. Squat and static lunge: knees bend at least 35° and the hips drop with the torso mostly upright; the ankle gap separates them (under 0.3 leg lengths is a squat, over 0.45 a lunge), and without the far ankle the rules do not guess. Everything else is "other", and almost no movement is "none".
- **Angle model** (`CoreMLAngleClassifier`): a Create ML boosted-tree classifier trained on the same features. Optional: the app uses the rules by default and the model only when a build includes it and Options → **Use the trained model instead** is on. Since 12 October the team does not spend more time on it.

The app votes over the windows of a set the same way for both: an exercise needs at least 60% of windows with confidence 0.8 or more (rules always give 1 or abstain).

## Data

| Source | What | Licence | Used for |
| --- | --- | --- | --- |
| Duddela Sai Prashanth, Priya Kamath, Rakshith Bhandary, S Ashlesh Pai, Pratham PN, Advith P, Abhishek Mashetty. *A Multi-View Raw Video Dataset of Seven Fitness Exercises with Good/Bad Form Labels*, Mendeley Data, version 2, [doi:10.17632/kgbb3yn47p.2](https://doi.org/10.17632/kgbb3yn47p.2) | 346 side-view MP4 videos filmed with smartphones in a gym, 26 participants: bodyweight squat, push-up, and five dumbbell exercises | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), checked on the dataset record on 12 October 2026 | squat, push-up, and "other" (side bend, bent-over row, curl, shoulder press, overhead triceps) |
| `SyntheticExerciseMotion.swift` (Debug only) | Stick-figure side-view sequences with random proportions, tempo, depth, camera yaw up to 20°, framing, jitter, dropped joints, and weaker far-side confidence | written for Plumb | all six classes; the only source for static lunge, stiff-leg deadlift, and "none" |

Changes made to the Mendeley material, as CC BY asks: only the side-view files were downloaded; each HEVC video was rewrapped with the `hvc1` tag that Apple decoders accept and its audio dropped, without re-encoding; Vision poses were extracted from it. The dataset contains 19 groups of byte-identical files, some filed under two participants or two exercises; training keeps one copy of each, so no duplicate crosses the train/test split. The videos, poses, and models stay in `~/Documents/plumb-donnees`, outside the repository. The model contains no video, but it was trained on recordings of real people: the team decides together before it enters the public repository.

No dataset with an open licence was found for lunges or deadlifts. UCF101 and Penn Action publish no licence, and Kinetics points to YouTube videos owned by their uploaders.

## Results on held-out data

Real videos are split by participant: subjects 004, 008, 012, 016, 020, and 024 are never seen in training (79 recordings after removing duplicates). The rule thresholds were adjusted once by looking at training participants only. "No pose" means Vision found no measurable window in the whole video, so neither recognizer can decide; in the app this falls back to the chosen exercise.

| Held-out real sets | Angle model | Rules |
| --- | --- | --- |
| Squat | 12 of 12 | 12 of 12 |
| Push-up | 7 of 11 (4 no pose) | 6 of 11 (4 no pose, 1 uncertain) |
| Other exercises, should stay uncertain | 51 of 56 (5 no pose) | 51 of 56 (5 no pose) |
| Sets given a wrong exercise | 0 | 0 |

Per 2.5-second window, the angle model labels 279 of 279 squat windows, 81 of 82 push-up windows, and 1166 of 1178 other windows correctly on held-out participants. On held-out synthetic sequences both recognizers are at or near 100% for all six classes; that only shows the features separate the stick figure's movements, not that lunges or deadlifts will be recognized on real people.

Over all 327 real recordings, the rules recognize 27 of 45 push-up sets (8 without any pose), 41 of 46 squat sets, and give no exercise to 236 of 236 other sets.

## How close this is to the app

Close in several ways: the videos are portrait, from smartphones, side-on, mostly at 15 fps, and the poses come from the same Vision request the app runs, sampled at 15 per second. They also differ:

- the phones were held or placed by collectors in a busy gym, with bystanders in most frames; the extraction keeps the largest person, while the app refuses a set with someone else in view;
- the participants are 26 young adults in one gym; body types, clothing, and lighting are narrow;
- in portrait, a person doing push-ups on the floor is small and Vision often loses the hips and legs, which is where most failures come from;
- static lunges and stiff-leg deadlifts have no real data at all.

Thursday's clips, filmed the way Plumb asks, are the first real test for lunges and deadlifts and the right data to retrain both models.

## Rebuild

```sh
sh tools/exercise-classifier/angle-model/build.sh /tmp/plumb-tools
/tmp/plumb-tools/extract-poses <folder of exercise/quality/*.mp4> ~/Documents/plumb-donnees/poses/<name>
/tmp/plumb-tools/train-angle-classifier ~/Documents/plumb-donnees/poses/<name> ~/Documents/plumb-donnees/models/<name> --synthetic-per-class 250
```

`build.sh` compiles the two tools from the app's own `WorkoutModels.swift`, `PoseWindowFeatures.swift`, and `SyntheticExerciseMotion.swift`, so training and the app compute the same features. `extract-poses` expects videos Apple can decode; rewrap `hev1` HEVC files first with `ffmpeg -i in.mp4 -c copy -tag:v hvc1 -an out.mp4`. Training takes about a second; extracting poses takes about 3 seconds per 30-second video on this Mac. The trainer writes `PlumbAngleClassifier.mlmodel`, `report.md`, and `report.json`.

To try the model in the app, copy it to `Plumb/Plumb/PlumbAngleClassifier.mlmodel`; Xcode compiles it, Options switches to the trained-model wording, and `bundledAngleModelRecognizesSyntheticSetsWhenPresent` starts running. This was checked locally on 12 October and the file was removed again.
