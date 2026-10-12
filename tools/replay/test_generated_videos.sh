#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h:h}"
fixtures="$project_root/tools/replay/fixtures"
replay="$project_root/tools/replay/replay.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

check_result() {
  local label="$1" video="$2" expected_status="$3" reps="$4"
  local result
  result="$($replay --exercise bodyweightSquat --video "$fixtures/$video" \
    --poses-output "$scratch/$label-poses.json")"
  print -r -- "$result" | python3 -c '
import json, sys
label, expected_status, expected_reps = sys.argv[1:]
result = json.load(sys.stdin)
assert result["status"] == expected_status, (label, result)
assert result["measuredReps"] == int(expected_reps), (label, result)
assert result["frameCount"] > 0, (label, result)
print("{}: {}, {} reps, {} frames".format(
    label, result["status"], result["measuredReps"], result["frameCount"]))
' "$label" "$expected_status" "$reps"
}

check_result "synthetic squat" "squat-six-reps.mp4" measured 6
check_result "standing still" "standing-no-reps.mp4" retake 0
check_result "lower body hidden" "squat-lower-body-hidden.mp4" retake 0
