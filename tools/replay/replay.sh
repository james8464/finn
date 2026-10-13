#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h:h}"
if [[ "${1:-}" == "--build-to" ]]; then
  binary="$2"
  build_only=true
else
  binary="${TMPDIR:-/tmp/}plumb-replay-$$"
  build_only=false
  trap 'rm -f "$binary"' EXIT
fi

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
if $build_only; then exit 0; fi
"$binary" "$@"
