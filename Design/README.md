# Plumb brand theme

- [Live Figma brand guide](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q)
- [Editable local Figma copy](Plumb%20%E2%80%94%20Brand%20Theme.fig)
- [Brand preview](Plumb%20Brand%20Theme%20preview.png)
- [Production app icon and flat artwork](../Plumb/BrandArtwork/README.md)
- [iPhone experience review and Apple design references](../docs/design/iphone-experience-review.md)

The Figma guide is the identity reference for the iPhone app: purpose, mark, colour, type, voice, and icon appearance. It deliberately defines a brand rather than fixed screen layouts. The local `.fig` file is a saved snapshot; edit the live file for new decisions, then save a fresh project copy.

## Idea and identity

**Plumb** is a calm, observant workout-technique companion. The mark is a custom rounded **P**: its straight stem conveys alignment, while two open corners in the iPhone icon evoke the camera observing a set. The monogram stays legible at Home Screen size without prescribing one ideal exercise pose. The promise is **“Find your line.”** Preserve the mark's proportions and leave generous clear space. Use the layered [Icon Composer source](../Plumb/Plumb/AppIcon.icon) for the iPhone icon and the flat mark for editorial materials.

## Colour

| Token | Hex | Role |
| --- | --- | --- |
| Black | `#141414` | Primary icon mark, text, and dark icon ground |
| White | `#FFFFFF` | Light icon ground and reversed mark |
| Ink | `#16231F` | Supporting text and interior brand ground |
| Chalk | `#F5F7F3` | Quiet interior ground and reversed text |
| Mist | `#DCE8E1` | Subtle supporting surface |
| Evergreen | `#1F6A53` | Primary action and selective interactive accent in Light Mode |
| Mint | `#BEEBD6` | Sparse interior accent, never part of the app icon |
| Signal | `#2B845F` | Primary action and selective interactive accent in Dark Mode |

The icon is strictly black and white in its main appearances. The iPhone app uses white and black system surfaces, system typography, and Evergreen or Signal for the single primary action and a few interactive details. Green does not decorate content or encode an unsupported judgement about form. Keep supporting text dark enough to pass contrast checks in Light Mode. Use dynamic semantic iOS colours for backgrounds, labels, separators, warnings, and errors. Mint stays out of small text and filled buttons. The live Figma file includes Light, Dark, and increased contrast modes with the tested Signal value; the local `.fig` file is an earlier snapshot. The camera view should leave the person and their movement clearly visible.

The capture **Stop set** control is white over the camera in both appearances; red would suggest that Plumb is recording video. History uses `#C62828` for its destructive delete action in Light Mode and `#FF453A` in Dark Mode, keeping the text readable in both appearances. This is a functional control colour, not a brand accent.

Use SF Symbols for interface actions where appropriate. Keep the app icon and brand mark custom; Apple's [SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) prohibits using the symbols, or confusingly similar images, in app icons and logos.

## Typography

- Use San Francisco through iOS system text styles and Dynamic Type. Regular carries guidance; Semibold marks decisions and key figures.
- Use sentence case. Use monospaced digits for reps, time, and measured values. Avoid condensed display type and exaggerated tracking.
- Figma's visible specimens use Inter because its renderer does not display SF Pro. The file retains named SF Pro text styles for handoff; Inter is not the app font.

## Voice and imagery

Describe what Plumb can observe, then give one specific next step. Say “Your last two reps were shorter” rather than “Your form is wrong.” State tracking limits plainly and never imply injury prevention, diagnosis, or certainty from a single camera angle. Prefer real movement with full-body context, fine evidence traces, and restrained motion. Avoid synthetic athlete imagery, fake heatmaps, and decorative AI motifs.

## Apple references

[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) · [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) · [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) · [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) · [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
