#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h:h}"
binary="${TMPDIR:-/tmp/}plumb-replay-$$"
trap 'rm -f "$binary"' EXIT

xcrun swiftc -swift-version 6 -o "$binary" \
  "$project_root/tools/replay/ReplayVideo.swift" \
  "$project_root/Plumb/Plumb/Workout/WorkoutModels.swift" \
  "$project_root/Plumb/Plumb/Workout/ExerciseDefinition.swift" \
  "$project_root/Plumb/Plumb/Workout/EvidenceGate.swift" \
  "$project_root/Plumb/Plumb/Workout/SquatAnalyzer.swift" \
  "$project_root/Plumb/Plumb/Workout/ViewCheck.swift" \
  "$project_root/Plumb/Plumb/Workout/ExerciseRecognition.swift" \
  "$project_root/Plumb/Plumb/Workout/AthleteTracker.swift" \
  "$project_root/Plumb/Plumb/Capture/PoseFrameAnalyzer.swift"
"$binary" "$@"
