#!/usr/bin/env python3
"""Balance every no-argument iPhone UI test across three independent CI machines."""

import argparse
from pathlib import Path
import re


# Recorded October 2026 durations only balance work; no duration excludes a test.
CLASS_SECONDS = {
    "WorkoutFlowUITests": 838,
    "DashboardUITests": 381,
    "NativeUIReviewUITests": 230,
    "ExerciseOptionsUITests": 171,
    "PresentationReviewUITests": 198,
    "CoachReliabilityUITests": 128,
    "SkeletonOverlayUITests": 137,
    "CameraAngleUITests": 119,
    "ClippingRegressionUITests": 184,
    "FinnUITests": 53,
    "WatchCompanionUITests": 50,
    "AppleFitnessUITests": 42,
    "InterfaceAccessibilityUITests": 16,
    "ScreenTourUITests": 1,
    "OnboardingTourUITests": 1,
}
METHOD_SECONDS = {
    "AppleFitnessUITests/testFitnessOptionIsOffAndUnavailableWithDemoInput": 42,
    "CameraAngleUITests/testFrontViewPushUpIsMeasuredNotRefused": 27,
    "CameraAngleUITests/testFrontViewSetKeepsCountWithoutSideViewPostureAdvice": 61,
    "CameraAngleUITests/testValidationModeShowsTheThreeDimensionalVerdict": 31,
    "ClippingRegressionUITests/testAwardSheetDoesNotClipText": 62,
    "ClippingRegressionUITests/testCameraPrimerDoesNotClipText": 39,
    "ClippingRegressionUITests/testHealthSheetDoesNotClipText": 35,
    "ClippingRegressionUITests/testSettingsRowsDoNotClipText": 47,
    "CoachReliabilityUITests/testCoachAnswersWithoutAModelAndSurvivesTabChanges": 114,
    "CoachReliabilityUITests/testCoachComposerAtLargestTextInEveryLanguage": 91,
    "DashboardUITests/testAllDashboardDestinationsAndTabs": 48,
    "DashboardUITests/testFrenchDashboardUsesFrenchForMainActionsAndEmptyState": 13,
    "DashboardUITests/testHomeAndPostureNavigationInSupportedLanguages": 69,
    "DashboardUITests/testLargeTextKeepsNavigationUsable": 23,
    "DashboardUITests/testNestedNavigationSurvivesCameraPresentation": 23,
    "DashboardUITests/testOriginalHomeScrollPositionSurvivesTabSwitch": 16,
    "DashboardUITests/testPostureCardOpensThePostureTabAndExerciseGuide": 12,
    "DashboardUITests/testProductionLaunchRendersAllTabsAndDestinations": 68,
    "DashboardUITests/testRestoredDemoNeverWritesHistory": 19,
    "DashboardUITests/testSavedWorkoutAppearsOnDashboard": 46,
    "ExerciseOptionsUITests/testDemoLungeAndDeadliftProduceMeasuredSets": 66,
    "ExerciseOptionsUITests/testDemoMissingWristRefusesPushUpWithoutInventingReps": 31,
    "ExerciseOptionsUITests/testDemoPushUpCanBeMeasuredWithoutPerformingOne": 46,
    "ExerciseOptionsUITests/testExercisePickerChangesSetupGuidance": 146,
    "ExerciseOptionsUITests/testOptionsExplainAngleRulesAndTurnThemOnByDefault": 94,
    "ExerciseOptionsUITests/testTrainedModelSwitchUsesDemoClassifierAndReportsIt": 174,
    "FinnUITests/testExample": 11,
    "FinnUITests/testLaunchPerformance": 71,
    "InterfaceAccessibilityUITests/testHomeDetailTextScales": 27,
    "NativeUIReviewUITests/testCameraPrimerActionsAtBothTextSizes": 50,
    "NativeUIReviewUITests/testDarkAppearanceAndLargestText": 52,
    "NativeUIReviewUITests/testFrenchNavigationAndBestSet": 19,
    "NativeUIReviewUITests/testHealthOfferAtLargestText": 36,
    "NativeUIReviewUITests/testHomeLargestTextAccessibilityAudit": 17,
    "NativeUIReviewUITests/testLargeTextLongPagesReachTheirLastControls": 118,
    "NativeUIReviewUITests/testNativeDestinations": 39,
    "NativeUIReviewUITests/testRestoredLargestTextControls": 29,
    "PresentationReviewUITests/testLargestTextWithReducedMotion": 102,
    "PresentationReviewUITests/testMeasuredResultChartDrawsBars": 28,
    "PresentationReviewUITests/testPrivacyDisclosuresRetainTheCameraPolicy": 22,
    "PresentationReviewUITests/testSettingsHaveOneControlForEachPreference": 20,
    "PresentationReviewUITests/testSupportingPagesInDarkAppearance": 91,
    "ProgressAndWorkoutUITests/testGuidedCameraAdviceMeasuresOnlyTheChosenStage": 65,
    "ProgressAndWorkoutUITests/testGuidedWorkoutAtLargestTextAndReducedMotionInEveryLanguage": 240,
    "ProgressAndWorkoutUITests/testSuggestedWorkoutCanBeFollowedWithoutCameraAdvice": 45,
    "SkeletonOverlayUITests/testDemoSetShowsTheSkeletonWithTheKneeAngle": 20,
    "SkeletonOverlayUITests/testResultDrawsTheDeepestAndShallowestRep": 31,
    "SkeletonOverlayUITests/testVideoFileSetShowsTheSkeletonAndCountsReps": 42,
    "SkeletonOverlayUITests/testVideoWithHiddenFeetIsCountedFromTheHips": 44,
    "WatchCompanionUITests/testDemoSetMirrorsToPairedWatch": 50,
    "WorkoutFlowUITests/testCaptureAndResultAccessibilityAudits": 57,
    "WorkoutFlowUITests/testCaptureShowsElapsedTimeAndResetsForNextSet": 36,
    "WorkoutFlowUITests/testComparisonAndSavedHistoryAccessibilityAudits": 56,
    "WorkoutFlowUITests/testDarkCaptureKeepsCameraAndControlsClear": 23,
    "WorkoutFlowUITests/testDemoSetShowsMeasuredResultAndRetake": 64,
    "WorkoutFlowUITests/testDeniedCameraShowsRecoveryWithoutRecording": 26,
    "WorkoutFlowUITests/testDismissedCueAcknowledgesFeedback": 24,
    "WorkoutFlowUITests/testHandsFreeShowsHintAndCountsRepsLive": 25,
    "WorkoutFlowUITests/testHistoryAccessibilityAudit": 35,
    "WorkoutFlowUITests/testLargeTextSetupCaptureAndResultAccessibilityAudits": 41,
    "WorkoutFlowUITests/testPrimaryActionsStayNearBottomOfWorkoutFlow": 29,
    "WorkoutFlowUITests/testPrivacyDarkModeAccessibilityAudit": 84,
    "WorkoutFlowUITests/testPrivacyScreenAccessibilityAudit": 72,
    "WorkoutFlowUITests/testPrivacySummaryIsReachableFromSetup": 59,
    "WorkoutFlowUITests/testSavedHistoryOpensMeasuredSetDetails": 43,
    "WorkoutFlowUITests/testSetupAccessibilityAudit": 17,
    "WorkoutFlowUITests/testSetupDarkModeAccessibilityAudit": 17,
    "WorkoutFlowUITests/testSetupReducedTransparencyAccessibilityAudit": 16,
    "WorkoutFlowUITests/testSpokenObservationIsOptionalAndStopsWhenDismissed": 33,
    "WorkoutFlowUITests/testStopRemainsReachableWithLargeTextInDarkMode": 23,
    "WorkoutFlowUITests/testTabTextScalingAccessibilityAudit": 15,
    "WorkoutFlowUITests/testUnavailableCameraOffersRetryWithoutSettings": 17,
    "WorkoutFlowUITests/testValidationLaunchShowsStopTiming": 23,
}
GROUP_COUNT = 3


def discovered_methods(root: Path) -> dict[str, float]:
    durations = {}
    seen_classes = set()
    for path in sorted((root / "Finn/FinnUITests").rglob("*.swift")):
        source = path.read_text(encoding="utf-8")
        # Comments cannot introduce a phantom test or class into discovery.
        source = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.DOTALL)
        classes = re.findall(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b", source)
        if not classes:
            continue
        declarations = re.findall(r"\bclass\s+(\w+)\s*[:{]", source)
        if len(classes) != 1 or len(declarations) != 1:
            raise ValueError(f"Ambiguous multiple classes in UI test file: {path.name}")
        name = classes[0]
        if name in seen_classes:
            raise ValueError(f"Duplicate UI test class: {name}")
        seen_classes.add(name)
        methods = re.findall(r"\bfunc\s+(test\w*)\s*\(([^)]*)\)", source)
        if not methods:
            raise ValueError(f"No discoverable tests in UI test class: {name}")
        fallback = CLASS_SECONDS.get(name, len(methods) * 30) / len(methods)
        for method, parameters in methods:
            if parameters.strip():
                raise ValueError(f"Unsupported parameterised XCTest method: {name}/{method}")
            selector = f"FinnUITests/{name}/{method}"
            if selector in durations:
                raise ValueError(f"Duplicate UI test selector: {selector}")
            durations[selector] = METHOD_SECONDS.get(f"{name}/{method}", fallback)
    if len(durations) < GROUP_COUNT:
        raise ValueError("Not enough UI tests to populate the CI groups")
    return durations


def interface_groups(root: Path) -> list[list[str]]:
    durations = discovered_methods(root)
    groups = [[] for _ in range(GROUP_COUNT)]
    totals = [0.0] * GROUP_COUNT
    for selector in sorted(durations, key=lambda item: (-durations[item], item)):
        index = min(range(GROUP_COUNT), key=lambda item: (totals[item], item))
        groups[index].append(selector)
        totals[index] += durations[selector]
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
    for selector in groups[index]:
        print(selector)


if __name__ == "__main__":
    main()
