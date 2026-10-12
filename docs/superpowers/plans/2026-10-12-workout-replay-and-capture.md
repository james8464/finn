# Workout Replay and Capture Implementation Plan

> **For agentic workers:** Implement each task with a failing test first, then verify the full suite.

**Goal:** Test all supported workout flows without repeated exercise and make active capture clearer.

**Architecture:** A Debug-only fixture generator feeds the existing `PoseStreaming` and session model. A macOS replay command uses Vision and the production analyzer on an external video. The capture view reads a session start time for a native elapsed clock.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Vision, XCTest, Swift Testing, iOS 27 simulator.

**Spec:** `docs/superpowers/specs/2026-10-12-workout-replay-and-capture-design.md`

## Tasks

- [x] Add failing UI tests for the six-rep Debug fixtures and a missing-joint refusal case. Implement fixture frames in a focused Debug-only file, connect the selected exercise to the demo source, and verify the tests against the production analyzer.
- [x] Add a failing UI test for an elapsed clock that advances during capture and resets for a new set. Expose capture start time from the session model and show the clock using system text styles; verify the test.
- [x] Add a macOS video replay command that outputs `PoseFrame` JSON and an analyzer report. Verify it with a generated video smoke case and a synthetic pose fixture; document how to reuse one real clip without adding it to Git. A generated blank video was processed at 15 fps and refused; pose JSON was rescored by the command. Real-video behavior is still unverified without a clip.
- [x] Review simulator captures in Light and Dark Mode, run the complete local iOS suite and repository checks, and confirm the release archive excludes Debug paths. Capture screenshots were reviewed; the combined iOS 27 iPhone 18 Pro Max run passed 208 tests with one external-video test skipped. An unsigned Release archive built and passed `docs/release/verify-archive.sh`.

## Review focus

- Fixture time stamps and set duration must satisfy the real analyzer's evidence rules.
- Exercise switching must configure the next set, including after a prior result.
- A missing-joint fixture must abstain for the right reason.
- Video orientation and frame times in the Mac tool must match the app's reader.
- Capture timer must not show during framing, countdown, or result.
