# Plumb iPhone experience review — 12 October 2026

## Direction

The screen should feel like a quiet Apple utility used between sets: one clear action, truthful live feedback, and a result that names its evidence. Use native SwiftUI controls, SF Symbols in controls only, system text styles, semantic colors, and generous spacing. Reserve Evergreen/Signal for the primary action. Avoid gradient backgrounds, glass cards, invented scores, fake motion visualizations, generic AI chat, and ornamental coaching language. Use Liquid Glass only where the system places it in navigation and controls; keep content surfaces plain.

## Design references and choices

| Reference | What it demonstrates | Plumb decision |
| --- | --- | --- |
| [Apple Design Awards 2026: Moonlitt](https://developer.apple.com/design/awards/) | A focused SwiftUI utility with easy onboarding and careful system-material use. | One small brand mark, one setup action, plain content, and native navigation. |
| [Apple Design Awards 2025: iA Writer](https://developer.apple.com/design/awards/2025/) | Focus through removing distractions. | Keep the camera view free of charts and a floating pose skeleton; show only framing and set controls. |
| [Apple Design Awards 2025: Mela](https://developer.apple.com/design/awards/2025/) | Details appear at the moment they matter. | Show placement guidance before capture, one observation after capture, and rep detail on the result. |
| [Apple Design Awards 2025: Train Fitness](https://developer.apple.com/design/awards/2025/) | Platform sensing can reduce screen interaction and improve accessibility. | Make the iPhone flow usable first; evaluate optional spoken feedback and Watch sensing only after device validation. |

These are interaction lessons, not layouts or assets to copy.

## Applied HIG decisions

- [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles), [iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios), [layout](https://developer.apple.com/design/human-interface-guidelines/layout), and [writing](https://developer.apple.com/design/human-interface-guidelines/writing): Setup has a single dominant camera action, concise instructions, and subdued secondary destinations. Results lead with the observation; rep measurements and range methodology sit behind native disclosures. Only the next-set action uses a filled button.
- [Color](https://developer.apple.com/design/human-interface-guidelines/color) and [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): System background and label colors adapt to appearance and contrast. Text carries every state; color alone never does. System text styles support Dynamic Type. UI tests audit setup, capture, and result at an accessibility text size in Dark Mode, and verify the Stop control remains reachable. The corresponding setup and result screenshots were visually inspected on an iPhone 18 Pro simulator.
- [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy): Camera permission follows **Set up camera**. Setup states that analysis stays on the iPhone and no video is saved. History and Privacy remain reachable without granting camera access. The policy link has a 44-point minimum hit height, and Privacy section titles carry heading traits for assistive navigation. Derived history and recovered backups request [complete file protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files); lock/unlock behavior still needs a physical iPhone.
- Camera recovery names permission denial, temporary unavailability, and interruption separately. The permission screen offers Settings; an unavailable camera offers retry. Recovery text grows inside a scroll view at accessibility text sizes.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): System controls can use the platform's native material. Camera pixels and measured results stay visually clear; no decorative glass panel overlays the person.
- [Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple): Do not ask for an account on first launch. Current history exists only on the phone, so sign-in would not unlock a benefit. When cross-device history or a shared coach workflow exists, offer an optional account from History after the person has used the core loop; explain exactly what syncs and use the system-provided button. Keep camera frames local and never make sign-in a prerequisite for a set. A real identity service, storage design, deletion flow, and privacy update are prerequisites for that feature.

## Verification boundary

An iOS 27 simulator can test navigation, text sizes, appearances, accessibility audits, the synthetic set path, and deterministic scoring. It cannot validate real framing, pose accuracy, thermal behavior, VoiceOver's spoken order on a physical device, or the usefulness of cues to lifters. A physical iPhone and consenting sets remain required before making those claims.
