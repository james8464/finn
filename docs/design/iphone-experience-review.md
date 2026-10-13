# Plumb iPhone design direction — 12 October 2026

## What changed

Plumb is a focused iPhone utility for reviewing a workout set. Its interface now uses a white canvas in Light Mode and black in Dark Mode, San Francisco system text styles, SF Symbols for interface actions, and semantic iOS colours. There is no green accent in the app. One filled action moves the workout forward; other actions use native navigation, text buttons, disclosures, lists, and sharing. The custom monochrome icon remains the brand mark. [The live Figma brand guide](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q) and its [local project copy](../../Design/README.md) now express the same direction.

The prior screen used the brand mark and title twice, a large editorial headline, wide gaps between short setup steps, and green on the toolbar, rows, links, rule, and primary button. That emphasis made routine controls compete with the actual task. The revision leaves the native large title, a compact exercise picker, two placement rows that change with the selected exercise, a short on-device processing note, and **Set up camera** at the bottom. History, Options, and Privacy remain in the native toolbar without adding a tab bar for secondary destinations.

Reviewed iPhone 18 Pro Max simulator captures: [Light Mode](screenshots/2026-10-12-minimal-setup-light.png) and [Dark Mode](screenshots/2026-10-12-minimal-setup-dark.png). They show a normal launch, without synthetic input.

The [result capture](screenshots/2026-10-12-minimal-result-demo.png) shows the same hierarchy after a synthetic set. Its **DEMO INPUT** marker exists only in Debug builds; this image is for design review, not App Store use.

## Apple references

| Reference | Lesson applied to Plumb |
| --- | --- |
| [2025 Apple Design Awards: iA Writer](https://developer.apple.com/design/awards/2025/) | Remove distractions during a focused task. The camera view shows framing status and set controls without decorative charts. The pose overlay is a functional alignment aid. |
| [2025 Apple Design Awards: Mela](https://developer.apple.com/design/awards/2025/) | Show detail when it becomes useful. Placement comes before capture; one observation comes after; rep measurements and methodology sit behind disclosures. |
| [2026 Apple Design Awards: Moonlitt](https://developer.apple.com/design/awards/) | Native SwiftUI, easy entry, and careful Liquid Glass in navigation can make a small utility feel at home on iPhone. |
| [2026 Apple Design Awards: The Outsiders](https://developer.apple.com/design/awards/) | Workout data earns its space when it helps the next decision. Plumb leads with the measured observation and next-set action rather than an invented score. |
| [2026 Apple Design Awards: Detail](https://developer.apple.com/design/awards/) | A camera-first task can keep advanced analysis behind a simple capture flow. Generated wording remains optional and tied to deterministic measurements. |

These are design principles from Apple's award descriptions, not copied screens. Apple's [colour](https://developer.apple.com/design/human-interface-guidelines/color) guidance supports semantic colours that adapt to appearance and contrast. Its [materials](https://developer.apple.com/design/human-interface-guidelines/materials) guidance places Liquid Glass in navigation and controls, and advises against decorative glass in content. The [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) guidance supports a small number of prominent actions. Plumb relies on system controls to supply the platform's current appearance rather than imitating glass with custom blur, borders, or gradients.

## Screen rules

- **Setup:** A native menu selects the exercise; two short rows change their placement and orientation guidance with that choice. The privacy sentence appears before camera permission. The bottom action is the only filled control. System navigation displays the app name without repeating its mark in content.
- **Capture:** Camera pixels fill the screen and the live pose overlay follows the analyzed frames. White guidance and controls sit over a dark scrim that protects legibility over bright rooms. **Start set** and **Stop set** are native buttons; Stop is neutral because the app analyzes frames live and does not store video. Framing states use plain words as well as symbols. On a same-exercise retry, one short sentence from the previous relevant cue stays near the top during framing and capture, without live criticism or animation.
- **Result:** A large system text heading reports the outcome, with a plain **Done** action at the top. Measured rep count is secondary. The observation is the strongest content text, followed by the reps that support it and one next-set instruction. A consistent-range result names that one measured signal and does not declare overall form perfect. Optional speech, comparison, rep details, and Share Summary use standard controls. The bottom next-set action stays reachable. The native glass toolbar was avoided here because its Done label did not scale in the iOS 27 accessibility audit.
- **History, Options, and Privacy:** History is an inset grouped list and the session detail uses the same observation hierarchy as a live result. Options uses native switches for exercise recognition and camera angle checking. Privacy uses headings and plain text, with the full policy link at a usable hit size. Destructive history actions use red values with sufficient contrast in both appearances, never brand colour.
- **Recovery:** Permission denial offers Settings and retry. Temporary unavailability offers retry. The reason is stated before the action. These screens remain scrollable at accessibility text sizes.

System text styles and Dynamic Type control every label. Primary text uses `Color.primary`; supporting copy uses an adaptive 72% primary label because the default secondary gray missed the simulator's small-text contrast audit in Light Mode. The primary button reverses the system background against the adaptive ink tint. Rep counts and time use monospaced digits. There is no custom display font. A slider would imply a continuous setting that this workout flow does not currently have, so none is added for decoration.

## Privacy and account boundary

Camera permission follows a user action. Frames and pose points are analyzed on the iPhone; no video is saved. Results are local summaries, with optional speech and an optional on-device explanation of a measured comparison. Share Summary uses the system share sheet and contains text only. Sign in with Apple is planned for a real cross-device summary service; showing a sign-in button before such a service exists would imply sync and recovery the app cannot provide. It must never gate a set.

## Verification and limits

The iOS 27 simulator can validate layout in Light and Dark Mode, navigation, Dynamic Type, accessibility structure, the synthetic set path, and deterministic analysis. Its camera screen has a black stand-in; only a physical iPhone in varied lighting can verify framing, contrast over a live image, pose reliability, performance, and whether the cues help lifters. The synthetic path is marked **DEMO INPUT** in Debug builds so its results are never mistaken for measured camera data. Current screenshots and test status should be refreshed after each interface change.
