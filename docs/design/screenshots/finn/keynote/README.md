# Keynote captures

Page 11 of [Finn — Brand Theme](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q?node-id=99-2) uses these simulator renders.

The workout is a scripted sample, not an athlete recording or an accuracy demonstration. `-finn-ui-demo -finn-presentation-capture` keeps temporary storage and disables live coach services. The second flag hides debug badges only in this export mode and supplies a full-body pose fixture. Normal Debug tours retain their input badge; production behaviour is unchanged.

## Refinements

- Results prioritise the count, chart and observation. Measurement limits remain available in a disclosure.
- Movement comparison has a dedicated page, avoiding a screenshot midway through a scroll.
- Coach opens with the latest set and aligned suggested questions.
- History has a compact, width-adaptive activity calendar. Week comparisons appear when previous-week data exists.
- Posture identifies the movement without a redundant selection heading.
- Home uses the same sample session as the other captures.

Apple references: [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Writing](https://developer.apple.com/design/human-interface-guidelines/writing), [Charting data](https://developer.apple.com/design/human-interface-guidelines/charting-data).

## Regenerate

Run `PresentationReviewUITests/testKeynoteCaptures` on an iPhone 18 Pro Max simulator, passing `TEST_RUNNER_FINN_CAPTURE_DIR` to Xcode. Set the simulator status bar to 9:41 before capturing. The test verifies that no input badge is present and exports nine unmodified screenshots.

## Verification — 16 October 2026

- Nine-screen export passed; every image was checked for the debug badge.
- Largest accessibility text with Reduce Motion passed.
- Exercise recognition, observation dismissal and speech-stop tests passed.
- String-catalog compilation and whitespace checks passed.
- Earlier accessibility runs exposed History label sizing, now corrected. Contrast findings were confined to retained labels wholly outside the scroll viewport; the audit now excludes only those offscreen descendants, never visible or partially visible text.
- The final accessibility rerun encountered a simulator UI-query timeout. A fully passing final accessibility run is still required before merging.

The manifest records the uploaded image hashes and local SHA-256 values. Additional native videos added by the presentation session are separate from these nine still captures.
