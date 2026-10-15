# Welcome screen handoff

> Latest visual revision: “Plumb / Welcome — Brand Theme Cover” supersedes the default layout below. It uses the cover’s #202020 background, Inter Semi Bold wordmark and statement, “Find Blue Online” with a pink underline, the existing squat photo with a charcoal-to-black fade, and a black lower panel containing “Welcome to Plum” and a gray button with pink text. The earlier 200% study remains an archived layout reference and does not represent this revision. Recheck text scaling during implementation.

Design: `Design/plumb.pen`, “Plumb / Welcome — HIG refined” and “Plumb / Welcome — 200% text study”.

## Visual decisions

- Preserve the requested charcoal #181818 background, exact pink #FF2D92, unannotated squat photo, and “Stronger starts Together”.
- Use a clear heading, generous spacing, one prominent “Try the Demo” action, and an optional Skip action.
- Use neutral page indicators with a 44-point control area. Connect to the existing three introductory pages; omit the control if these pages are absent.
- Primary button: 52 points high. Skip: 64 × 44 points. Keep bottom controls above the system safe area.
- Preview uses Inter because this editor rejects SF Pro. Production uses the system font: largeTitle bold for the slogan, title2 bold for the brand, body for Skip, headline for the primary action. Do not bundle Inter.
- This branded introductory screen retains its requested dark presentation in either system appearance. Other screens retain their own appearance behavior.

## Accessibility and behavior

- Use native buttons and page control, including pressed feedback and accessibility traits. “Try the Demo” opens the existing interactive demo; Skip bypasses the introduction. Preserve camera and data behavior.
- Dynamic Type: scale semantic styles, permit wrapping, grow button height, and scroll content when necessary. Keep the main action in a safe-area inset. The 200% study demonstrates reflow; it is not a runtime test of every Dynamic Type category.
- VoiceOver reading order: brand, Skip introduction, slogan heading, photo if informative, page control, Try the Demo. Describe an informative photo as “Person demonstrating a squat from the side”; hide it if decorative.
- No autoplay or decorative motion. Respect Reduce Motion for navigation and Reduce Transparency for any native materials.
- Black text on pink provides approximately 6.04:1 contrast; pink on charcoal approximately 5.11:1. White on charcoal is approximately 17.76:1. Neutral inactive page dots #8E8E93 provide approximately 5.45:1 against charcoal.
- Preserve readable colors with Increase Contrast and Bold Text. Native system status and home indicators replace mockup chrome.

## Verification

Visually reviewed default and 200% studies for overlapping text, alignment, photo placement, action visibility, and safe-area spacing. The design is static: VoiceOver, focus order, actual system font metrics, Dynamic Type extremes, landscape, small devices, localization, and light/dark system settings still require app-level testing.

## Apple sources

- [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Page controls](https://developer.apple.com/design/human-interface-guidelines/page-controls)
