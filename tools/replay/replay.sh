#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h:h}"
if [[ "${1:-}" == "--build-to" ]]; then
  binary="$2"
  build_only=true
else
  binary="${TMPDIR:-/tmp/}finn-replay-$$"
  build_only=false
  trap 'rm -f "$binary"' EXIT
fi

xcrun swiftc -swift-version 6 -o "$binary" \
  "$project_root/tools/replay/ReplayVideo.swift" \
  "$project_root/Finn/Finn/Workout/WorkoutModels.swift" \
  "$project_root/Finn/Finn/Workout/ExerciseDefinition.swift" \
  "$project_root/Finn/Finn/Workout/EvidenceGate.swift" \
  "$project_root/Finn/Finn/Workout/SquatAnalyzer.swift" \
  "$project_root/Finn/Finn/Workout/ViewCheck.swift" \
  "$project_root/Finn/Finn/Workout/ExerciseRecognition.swift" \
  "$project_root/Finn/Finn/Workout/AthleteTracker.swift" \
  "$project_root/Finn/Finn/Workout/SetWindow.swift" \
  "$project_root/Finn/Finn/Workout/SilhouetteCheck.swift" \
  "$project_root/Finn/Finn/Workout/MistakeProfile.swift" \
  "$project_root/Finn/Finn/Workout/BodySegments.swift" \
  "$project_root/Finn/Finn/Workout/FormChecks.swift" \
  "$project_root/Finn/Finn/Workout/SpokenLanguage.swift" \
  "$project_root/Finn/Finn/Workout/FitnessWorkout.swift" \
  "$project_root/Finn/Finn/Workout/LiveSet.swift" \
  "$project_root/Finn/Finn/Workout/AngleRecognition.swift" \
  "$project_root/Finn/Finn/Workout/PoseWindowFeatures.swift" \
  "$project_root/Finn/Finn/Capture/PoseFrameAnalyzer.swift"
if $build_only; then exit 0; fi
"$binary" "$@"
