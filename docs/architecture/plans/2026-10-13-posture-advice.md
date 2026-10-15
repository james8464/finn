# Posture Advice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one evidence-linked, exercise-specific posture suggestion after a measured set, while preserving the current range cue and honest retake behavior.

**Architecture:** At the deepest point of each completed rep, measure one additional side-view posture signal: torso lean for squats and lunges, hip alignment for push-ups, or knee bend for stiff-leg deadlifts. Compare the first two and last two reps only when all four samples are reliable, the view is side-on, and rep range is comparable. Select at most one cue per set; fall back to the existing range cue. Persist optional posture readings so old histories still decode.

**Tech Stack:** Swift, Swift Testing, Vision pose frames, SwiftUI result view.

**Spec:** README.md, “Finn idea” and “Current state,” updated 13 October 2026.

## Tasks

- [x] Add failing end-to-end tests for exercise-specific posture cues. Run the focused tests and confirm the new cases fail for the expected reason.
- [x] Cover missing supporting joints, angled views, changed rep range, all four exercise signals, and old saved sessions.
- [x] Implement optional per-rep posture readings and one posture cue per set, using the current result and spoken/share surfaces. Keep old saved sessions decodable. Run focused tests until green.
- [x] Update the README and validation notes to describe the implemented scope and remaining physical-device and coach review. Run the full unit suite and simulator build, and inspect the diff.
- [x] Commit and push `main`.

## Review Focus

- Side-view confidence and missing joints must prevent posture cues without suppressing valid rep counts.
- Posture changes must be compared at the same phase of comparable reps, not across arbitrary frames.
- One cue per set must remain true when range and posture both change.
- Old session JSON must decode with no posture reading.
- The copy must describe visible movement, never diagnose safety or guarantee ideal form.
