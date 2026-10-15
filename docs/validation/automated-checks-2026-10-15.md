# Automated checks — 15 October 2026

## MWM-configured working tree

- Xcode Debug simulator build: passed. Bundles Spark and its privacy manifest; the binary contains the sandbox key and not the production key.
- Xcode Release simulator build: passed. The binary contains the production key and not the sandbox key.
- Swift unit tests on iOS 27 simulator: 424 passed, 0 failed. Result: `/tmp/plumb-mwm-unit-tests.xcresult`.
- Focused privacy UI tests on iOS 27 simulator: 2 passed, 0 failed. Result: `/tmp/plumb-mwm-privacy-ui.xcresult`.
- Generated-video replay: 14 of 15 clip expectations passed, plus the mirrored and feet-hidden diagnostics. The `squat-too-far.mp4` fixture expected six measured reps but received a retake with zero reps because knee visibility was 62%, below the 80% evidence threshold. The standalone replay build script was updated to include the form-check and body-segment sources. Log: `/tmp/plumb-mwm-replay-final.log`.

## Connected iPhone, automated only

The full Xcode test run used a disposable Personal Team copy of commit `b209c55` with unique bundle IDs, on an iPhone 16 Pro Max running iOS 27.0.1. It did not install or sign the MWM-configured working tree. Results: 435 passed, 7 failed, 8 skipped. Result: `/tmp/plumb-iphone-test-20261015/personal-device-unique-retry.xcresult`.

All seven failed tests are UI accessibility checks:

- `CameraAngleUITests/testFrontViewSetIsRefusedUntilTheCheckIsSwitchedOff`: small hit target.
- `WorkoutFlowUITests/testCaptureAndResultAccessibilityAudits`: small Cancel and Listen to observation targets; low contrast in rep detail labels.
- `WorkoutFlowUITests/testDarkCaptureKeepsCameraAndControlsClear`: small Cancel target.
- `WorkoutFlowUITests/testDeniedCameraShowsRecoveryWithoutRecording`: low contrast in recovery controls.
- `WorkoutFlowUITests/testLargeTextSetupCaptureAndResultAccessibilityAudits`: tab labels do not fully scale with Dynamic Type.
- `WorkoutFlowUITests/testSetupAccessibilityAudit`: tab labels do not fully scale with Dynamic Type.
- `WorkoutFlowUITests/testSetupDarkModeAccessibilityAudit`: tab labels do not fully scale; Posture and Coach labels also fail contrast in dark mode.

The disposable app and runner were removed after testing. The older Plumb UI test runner was removed to make room under Apple's Personal Team app limit; the older Plumb app itself was left in place. Xcode can reinstall that runner on the next test run.

## Coverage limits

Automated demo UI tests cannot validate live camera accuracy on a person, Apple Watch pairing and heart rate, AirPods audio routing, Health permissions and Fitness writes, or an actual subscription purchase. The MWM build cannot be signed for this iPhone until Xcode has access to the MWM Apple Developer team and its app capabilities. A broad simulator UI run on the earlier clean clone stalled after about 20 minutes and was stopped; focused UI and the full unit suite completed separately on the updated project.
