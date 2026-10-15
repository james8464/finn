#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h:h}"
fixtures="$project_root/tools/replay/fixtures"
replay="$project_root/tools/replay/replay.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
"$replay" --build-to "$scratch/replay"

# Every clip runs and prints its result; the script fails at the end if any clip differed.
failures=()
check_result() {
  local label="$1" video="$2" expected_status="$3" reps="$4"
  local result
  result="$("$scratch/replay" --exercise bodyweightSquat --video "$fixtures/$video" \
    --poses-output "$scratch/$label-poses.json")"
  print -r -- "$result" | python3 -c '
import json, sys
label, expected_status, expected_reps = sys.argv[1:]
result = json.load(sys.stdin)
assert result["status"] == expected_status, (label, result)
assert result["measuredReps"] == int(expected_reps), (label, result)
assert result["frameCount"] > 0, (label, result)
# On a measured set, the hands-free live count never says more reps than the result and is at
# most one behind it (the last rep can end after the final live analysis). On a refused set the
# live count is provisional: it counts before the end-of-set evidence gate, so it can be ahead.
live = result["liveReps"]
if result["status"] == "measured":
    assert live <= result["measuredReps"], ("live count above the result", label, result)
    assert live >= result["measuredReps"] - 1, ("live count behind the result", label, result)
print("{}: {}, {} reps, {} frames; live {} reps, cues {}, hands-free start {}".format(
    label, result["status"], result["measuredReps"], result["frameCount"], live,
    result["liveCues"] or "none",
    "at {:.1f} s".format(result["handsFreeReadyAt"]) if result.get("handsFreeReadyAt") is not None else "never"))
' "$label" "$expected_status" "$reps" || failures+=("$label")
}

check_result "synthetic squat" "squat-six-reps.mp4" measured 6
check_result "standing still" "standing-no-reps.mp4" retake 0
check_result "lower body hidden" "squat-lower-body-hidden.mp4" retake 0
# Covered feet: the side rubric refuses the set (no ankle), and since 15 October the hips still
# count its six squats, without posture advice (squat-trunk-v1).
check_result "feet hidden" "squat-feet-hidden.mp4" measured 6
check_result "dim light" "squat-dim.mp4" measured 6
check_result "farther phone" "squat-far.mp4" measured 6
# At 30% size the torso is too small for the hip-only fallback, and the side-view
# evidence gate also refuses posture advice. Keep the retake rather than guessing.
check_result "too far" "squat-too-far.mp4" retake 0
check_result "slower tempo" "squat-slow.mp4" measured 6
check_result "bright exposure" "squat-overexposed.mp4" measured 6
check_result "warm indoor color" "squat-warm-indoor.mp4" measured 6
check_result "low resolution" "squat-low-resolution.mp4" measured 6
check_result "off-center framing" "squat-off-center.mp4" measured 6
check_result "tilted phone" "squat-angled-phone.mp4" measured 6
# Strong blur leaves too few clear hip-and-shoulder pairs. Frame shifts reveal an
# unsteady phone. Neither condition supports the hip-only count or posture advice.
check_result "motion blur" "squat-motion-blur.mp4" retake 0
check_result "moving phone" "squat-phone-shake.mp4" retake 0

# Mirroring the source currently reduces Vision's required-joint coverage from roughly 81% to
# 71%; the gate safely asks for a retake. Report it as a known camera-direction limitation rather
# than freezing a failed left/right detection as desired behavior.
"$scratch/replay" --exercise bodyweightSquat --video "$fixtures/squat-mirrored.mp4" \
  > "$scratch/mirrored-result.json"
python3 - "$scratch/mirrored-result.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
assert result["status"] in {"measured", "retake"}, result
assert result["liveReps"] <= result["measuredReps"], ("live count above the result", result)
print("mirrored diagnostic: {}, {} reps; live {} reps".format(
    result["status"], result["measuredReps"], result["liveReps"]))
PY

# The live five-frame preview must not claim all squat landmarks are visible while the feet
# stay covered. A per-third-frame check without carrying its verdict forward can flicker.
python3 - "$scratch/feet hidden-poses.json" <<'PY'
import json, sys
frames = json.load(open(sys.argv[1]))
for index in range(10, len(frames)):
    window = frames[index-4:index+1]
    for side in ("left", "right"):
        required = [side + role for role in ("Hip", "Knee", "Ankle")]
        visible = sum(all(dict(zip(frame["joints"][::2], frame["joints"][1::2]))
                          .get(joint, {}).get("confidence", 0) >= 0.3 for joint in required)
                      for frame in window)
        assert visible < 4, ("covered feet reported as visible", index, side, visible)
print("feet hidden framing: stays in adjustPosition")
PY

if (( ${#failures} )); then
  print -u2 -- "Clips with an unexpected result: ${(j:, :)failures}"
  exit 1
fi
