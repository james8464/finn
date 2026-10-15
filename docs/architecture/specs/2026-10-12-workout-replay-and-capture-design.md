# Finn replay and capture design

Finn needs repeatable testing without asking someone to exercise on every run. The simulator must cover the same setup, capture, analysis, and result flow for each supported exercise. A separate Mac command must accept a saved, consented or licensed workout video, run Apple's Vision body-pose request on its frames, and score those poses with Finn's production exercise analyzer. This distinguishes repeatable functional tests from real-video validation.

## Simulator fixtures

Keep deterministic pose traces in a Debug-only fixture source. The source follows the exercise selected in setup and feeds the existing session model. Include a complete six-rep trace for squat, push-up, static lunge, and stiff-leg deadlift, plus a missing-joint trace that must produce an honest refusal. The fixture path is visibly marked **DEMO INPUT** and excluded from release archives. UI tests assert the selected exercise, measured or refused result, and the presence of the relevant cue or reason. The tests do not claim Vision accuracy.

## Saved-video replay

A macOS command reads an existing video upright with AVFoundation, samples at Finn's 15 fps analysis rate, runs `VNDetectHumanBodyPoseRequest`, and writes the same `PoseFrame` JSON shape used by the app. It prints a machine-readable outcome from Finn's exercise analyzer. Video and generated poses stay outside Git. Re-running the command on the same file is deterministic enough to compare analyzer revisions, while actual camera framing, thermal behavior, and 3D pose still require a physical iPhone.

## Capture UI

During an active set, show only the existing framing/status line, an elapsed clock in monospaced system type, a single Stop button, and Cancel. Keep the camera and skeleton visible. Elapsed time is a clock, not a rep count or quality score. It resets for each set and disappears outside capture. System controls and the monochrome brand remain unchanged.

## Acceptance

- All four exercise fixtures complete through the iPhone UI without human movement.
- A negative fixture ends with a specific refusal, not a fabricated measurement.
- The Mac replay command accepts a video file, emits pose JSON, and prints a scored or refused outcome.
- The capture timer appears only while a set is active and increases over time.
- Existing iOS and validation tests pass; release builds contain no fixture or video-file test code.
