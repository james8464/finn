#!/bin/sh
# builds the two command-line tools from the app's own pose and feature code
#   sh tools/exercise-classifier/angle-model/build.sh [output folder]
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
OUT=${1:-"$ROOT/.build/angle-model"}
WORKOUT="$ROOT/Finn/Finn/Workout"
mkdir -p "$OUT"
xcrun swiftc -O -o "$OUT/extract-poses" "$HERE/ExtractPoses/main.swift" "$WORKOUT/WorkoutModels.swift"
xcrun swiftc -O -D DEBUG -o "$OUT/train-angle-classifier" "$HERE/TrainAngleClassifier/main.swift" \
    "$WORKOUT/WorkoutModels.swift" "$WORKOUT/PoseWindowFeatures.swift" "$WORKOUT/SyntheticExerciseMotion.swift"
echo "built $OUT/extract-poses and $OUT/train-angle-classifier"
