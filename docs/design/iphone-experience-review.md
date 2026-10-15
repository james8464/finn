# Workout flow design

This records the Workout tab's setup, capture, and result screens. The newer [Home dashboard](home-dashboard.md) is the app's entry screen.

## Flow

1. **Setup:** Exercise chips change the illustrated movement and placement guide. One **Start a set** action leads to a short camera explanation, then the iOS permission prompt. A nearby privacy line explains local processing and no saved video.
2. **Capture:** Camera pixels remain visible behind the tracked skeleton, framing status, live count, and Start/Stop controls. Text accompanies symbols; audio is optional. Stop is neutral because Plumb analyzes frames without saving video.
3. **Result:** Show the measured outcome first: one supported observation with evidence and a next-set action, no clear pattern, or a retake reason. Rep details, comparison, speech, and text sharing are secondary. Keep navigation and the next action reachable at accessibility text sizes.
4. **Recovery:** Permission denial and camera interruption explain the problem before offering Settings or retry. History, Options, and Privacy use native navigation and controls.

The interface uses San Francisco text styles, SF Symbols, semantic colors, a white or black canvas, and the custom monochrome [brand mark](../../Design/README.md). The camera overlay and controls need contrast over live imagery. Dynamic Type, VoiceOver, and Reduce Motion must preserve the capture and stop actions. Apple's [layout](https://developer.apple.com/design/human-interface-guidelines/layout), [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), and [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) guidance informs these choices; the [local HIG index](apple-hig-agent-reference.md) covers the wider system.

## Design evidence

The 13 October simulator captures show [setup](screenshots/2026-10-13-home-light.png), [Dark Mode](screenshots/2026-10-13-home-dark.png), [camera primer](screenshots/2026-10-13-camera-primer.png), and [after a demo set](screenshots/2026-10-13-home-after-set-demo.png). Earlier 12 October captures show [light setup](screenshots/2026-10-12-minimal-setup-light.png), [dark setup](screenshots/2026-10-12-minimal-setup-dark.png), and a [synthetic result](screenshots/2026-10-12-minimal-result-demo.png). The older images document the design change, not the current Home screen.

Simulator checks cover layout, navigation, accessibility structure, and the labeled synthetic path. A physical iPhone is still needed to check live camera contrast, pose reliability, audio, and whether the cues help people.
