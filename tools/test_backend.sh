#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
scratch="$(mktemp -d "${TMPDIR:-/tmp/}finn-backend-tests.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

# Run the platform-independent analysis and Coach regressions without booting a simulator.
# Sources and tests are shared with Xcode; there is no separate implementation to maintain.
python3 - "$project_root" "$scratch" <<'PYTHON'
from pathlib import Path
import re
import sys

root, package = map(Path, sys.argv[1:])
source_folder = package / "Sources/Finn"
test_folder = package / "Tests/FinnTests"
source_folder.mkdir(parents=True)
test_folder.mkdir(parents=True)
(package / "Package.swift").write_text("""// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FinnBackendChecks",
    platforms: [.macOS("27.0")],
    targets: [
        .target(name: "Finn"),
        .testTarget(name: "FinnTests", dependencies: ["Finn"])
    ]
)
""")

sources = re.findall(r'\$project_root/(Finn/[^\"]+\.swift)',
                     (root / "tools/replay/replay.sh").read_text())
sources += ["Finn/Finn/Workout/" + name + ".swift" for name in [
    "SyntheticExerciseMotion", "CueSelector", "LocalSessionStore", "SetComparison",
    "FormTrend", "SkeletonGeometry", "FinnPreferences", "ModelGenerationGate", "ComparisonNarrator"
]]
sources += ["Finn/Finn/Coach/" + name + ".swift" for name in [
    "CoachContext", "CoachEngine", "CoachConversation", "ClaudeDemoEngine"
]]
sources += ["Finn/Finn/Onboarding/OnboardingProfile.swift"]
for relative in sources:
    source = root / relative
    (source_folder / source.name).symlink_to(source)

for name in [
    "SquatAnalyzer", "ExerciseAnalyzer", "FormChecks", "PoseIntegrity", "PushUpShoulders",
    "EvidenceAndCue", "SetWindow", "AthleteTracking", "LiveSet", "FormFrameSelection",
    "SessionStoreAndComparison", "FormTrend", "Coach", "ComparisonNarrator", "ModelGenerationGate",
    "PullUp", "PostureAdvice"
]:
    source = root / "Finn/FinnTests" / (name + "Tests.swift")
    (test_folder / source.name).symlink_to(source)

helper = root / "Finn/FinnTests/PoseTestHelpers.swift"
(test_folder / helper.name).symlink_to(helper)
PYTHON

swift test --package-path "$scratch" --jobs 2 "$@"
