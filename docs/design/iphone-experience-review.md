# Plumb iPhone design direction — 12 October 2026, first screen revised 13 October

## 13 October: a first screen that shows the set

The 12 October first screen was correct but bare. People tapped the toolbar before anything else, the raised hand of Privacy first, and the main button said **Set up camera**, a chore rather than a workout. Six simulated first-time users (a beginner, a home-fitness subscriber, an experienced lifter, a Build Challenge juror, someone wary of being filmed, someone in a hurry) all read it as a settings page; four of the six touched the toolbar first, and they rated their wish to open the app again between 3 and 5 out of 10.

What changed:

- The screen opens on a dark card that stands for the camera view. A line drawing of the chosen exercise does slow reps inside the two open corners of the app icon, with a plumb line and its bob over the midfoot (the body line for a push-up, the bar for pull-ups and muscle-ups). It is an illustration, not tracking, and it holds still under Reduce Motion.
- Chips above the card switch exercise in one tap; with six exercises the row scrolls, and the next chip peeks in. At accessibility text sizes they become a single menu.
- One filled action, **Start a set**, sits at the bottom, with its arrow in a circle of its own. The line above it, "Analyzed on this iPhone. No video is saved.", opens Privacy.
- History, Options and Privacy moved into one More menu at the top right. The title keeps the promise as a subtitle: "Find your line."
- The first time someone starts a set, a sheet says what the camera does (counts reps, keeps no video, sends nothing) before iOS asks for it. **Not now** leaves the permission untouched.
- After a session, a card shows the last session, its reps and the observation the person kept, and opens History.

Colour stays black and white. The dark card gives the screen its weight in both appearances.

Captures (iPhone 17 Pro simulator, iOS 27): [first screen](screenshots/2026-10-13-home-light.png), [Dark Mode](screenshots/2026-10-13-home-dark.png), [before the camera](screenshots/2026-10-13-camera-primer.png), [after a demo set](screenshots/2026-10-13-home-after-set-demo.png).

## What changed on 12 October

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

- **Setup:** Chips select the exercise and the dark card redraws it with its placement line. The privacy line sits directly above **Start a set**, the only filled control. History, Options and Privacy are in the More menu, so nothing at the top competes with starting a set. Camera permission follows **Start a set**, after Plumb says what the camera does.
- **Capture:** Camera pixels fill the screen and the live pose overlay follows the analyzed frames. White guidance and controls sit over a dark scrim that protects legibility over bright rooms. **Start set** and **Stop set** are native buttons; Stop is neutral because the app analyzes frames live and does not store video. Framing states use plain words as well as symbols. The current iPhone build shows framing and set status, without an in-set coaching prompt.
- **Result:** A large system text heading reports the outcome, with a plain **Done** action at the top. Measured rep count is secondary. When supported, one observation is the strongest content text, followed by the reps that support it and one next-set instruction. Otherwise, the result gives no clear pattern or a retake reason. Optional speech, comparison, rep details, and Share Summary use standard controls. The bottom next-set action stays reachable. The native glass toolbar was avoided here because its Done label did not scale in the iOS 27 accessibility audit.
- **History, Options, and Privacy:** History is an inset grouped list and the session detail uses the same observation hierarchy as a live result. Options uses native switches for exercise recognition and camera angle checking. Privacy uses headings and plain text, with the full policy link at a usable hit size. Destructive history actions use red values with sufficient contrast in both appearances, never brand colour.
- **Recovery:** Permission denial offers Settings and retry. Temporary unavailability offers retry. The reason is stated before the action. These screens remain scrollable at accessibility text sizes.

System text styles and Dynamic Type control every label. Primary text uses `Color.primary`; supporting copy uses an adaptive 72% primary label because the default secondary gray missed the simulator's small-text contrast audit in Light Mode. The primary button reverses the system background against the adaptive ink tint. Rep counts and time use monospaced digits. There is no custom display font. A slider would imply a continuous setting that this workout flow does not currently have, so none is added for decoration.

## Privacy and account boundary

Camera permission follows a user action. Frames and pose points are analyzed on the iPhone; no video is saved. Results are local summaries, with optional speech and an optional on-device explanation of a measured comparison. Share Summary uses the system share sheet and contains text only. The README does not scope an account or sync feature, so the current design has no sign-in control.

## Verification and limits

The iOS 27 simulator can validate layout in Light and Dark Mode, navigation, Dynamic Type, accessibility structure, the synthetic set path, and deterministic analysis. Its camera screen has a black stand-in; only a physical iPhone in varied lighting can verify framing, contrast over a live image, pose reliability, performance, and whether the cues help lifters. The synthetic path is marked **DEMO INPUT** in Debug builds so its results are never mistaken for measured camera data. Current screenshots and test status should be refreshed after each interface change.
