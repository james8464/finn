#!/usr/bin/env python3
"""Assign every iPhone UI test class to one of three independent CI machines."""

import argparse
from pathlib import Path
import re


# Approximate class durations from the October 2026 simulator runs. These only balance
# machines; they never choose which tests run. New classes use their test count as a guide.
APPROXIMATE_SECONDS = {
    "WorkoutFlowUITests": 723,
    "DashboardUITests": 355,
    "NativeUIReviewUITests": 289,
    "ExerciseOptionsUITests": 187,
    "PresentationReviewUITests": 150,
    "CoachReliabilityUITests": 140,
    "SkeletonOverlayUITests": 113,
    "CameraAngleUITests": 113,
    "ClippingRegressionUITests": 110,
    "FinnUITests": 77,
    "WatchCompanionUITests": 42,
    "AppleFitnessUITests": 21,
    "InterfaceAccessibilityUITests": 16,
    "ScreenTourUITests": 1,
    "OnboardingTourUITests": 1,
}
GROUP_COUNT = 3


def interface_groups(root: Path) -> list[list[str]]:
    durations = {}
    for path in sorted((root / "Finn/FinnUITests").rglob("*.swift")):
        source = path.read_text()
        classes = re.findall(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b", source)
        for name in classes:
            if name in durations:
                raise ValueError(f"Duplicate UI test class: {name}")
            test_count = len(re.findall(r"\bfunc\s+test\w*\s*\(", source))
            durations[name] = APPROXIMATE_SECONDS.get(name, max(1, test_count) * 30)

    if len(durations) < GROUP_COUNT:
        raise ValueError("Not enough UI test classes to populate the CI groups")
    groups = [[] for _ in range(GROUP_COUNT)]
    totals = [0] * GROUP_COUNT
    for name in sorted(durations, key=lambda name: (-durations[name], name)):
        index = min(range(GROUP_COUNT), key=lambda index: (totals[index], index))
        groups[index].append(name)
        totals[index] += durations[name]
    return [sorted(group) for group in groups]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=["analysis", "interface-1", "interface-2", "interface-3"])
    args = parser.parse_args()
    if args.suite == "analysis":
        print("FinnTests")
        return
    root = Path(__file__).resolve().parent.parent
    try:
        groups = interface_groups(root)
    except ValueError as error:
        parser.error(str(error))
    index = int(args.suite.rsplit("-", 1)[1]) - 1
    for name in groups[index]:
        print(f"FinnUITests/{name}")


if __name__ == "__main__":
    main()
