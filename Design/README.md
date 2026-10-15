# Plumb brand theme

- [Live Figma brand guide](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q)
- [Editable local Figma copy](Plumb%20%E2%80%94%20Brand%20Theme.fig)
- [Brand preview](Plumb%20Brand%20Theme%20preview.png)
- [Production app icon and flat artwork](../Plumb/BrandArtwork/README.md)
- [iPhone experience review and Apple design references](../docs/design/iphone-experience-review.md)

The Figma guide is the identity reference for the iPhone app: purpose, mark, colour, type, voice, icon appearance, and the current Home and workout expressions. It deliberately defines a brand rather than fixed screen layouts. The local `.fig` file and preview were refreshed from the live guide on 15 October 2026.

## Idea and identity

**Plumb** is a calm, observant workout-technique companion. The mark is a custom rounded **P**: its straight stem conveys alignment, while two open corners in the iPhone icon evoke the camera observing a set. The monogram stays legible at Home Screen size without prescribing one ideal exercise pose. The promise is **“Find your line.”** Preserve the mark's proportions and leave generous clear space. Use the layered [Icon Composer source](../Plumb/Plumb/AppIcon.icon) for the iPhone icon and the flat mark for editorial materials.

## Colour

The current Home dashboard follows the 14 October screen reference: a dark amber photograph, translucent cards, white text and a lime (`#CCF759`) selection accent. The **Figma direction replaces lime with pink (`#FF2D92`)** for the selected tab and small highlights. This change is in the brand guide; the iPhone implementation still uses lime. Workout, history and settings components retain their semantic colours. See [implementation notes](../docs/design/home-dashboard.md).

| Token | Hex | Role |
| --- | --- | --- |
| Black | `#000000` | Light appearance labels and primary action |
| White | `#FFFFFF` | Light canvas; dark appearance labels and primary action |
| Supporting | `#474747` | Reference for small supporting text in Light Mode |
| Grouped | `#F2F2F7` | Reference for optional grouped surfaces in Light Mode |
| Separator | `#C6C6C8` | Reference for quiet divisions in Light Mode |
| Icon ink | `#141414` | Custom mark and dark icon ground |
| Pink accent | `#FF2D92` | Proposed Home selection and small highlights |
| Pink on Light | `#AD0058` | Accessible small pink text on white |
| Pink on Dark | `#FF78B5` | Accessible small pink text on dark surfaces |

The iPhone interface uses semantic iOS colours (`systemBackground`, primary labels, system separators) and a monochrome adaptive action. Supporting copy uses 72% of the adaptive primary label because the default secondary gray missed a small-text contrast audit in Light Mode. The values above are Figma references, not fixed overrides for system colours. The system resolves Light, Dark, and increased contrast appearances. The proposed pink is an accent, never a form verdict; pair selection colour with shape and label, and keep the person clearly visible in the camera view.

The capture **Stop set** control is white over the camera in both appearances; red would suggest that Plumb is recording video. History uses contrast-tested destructive red (`#C62828` in Light Mode, `#FF453A` in Dark Mode) only for deletion. This is a functional state, not a brand accent.

Use SF Symbols for interface actions where appropriate. Keep the app icon and brand mark custom; Apple's [SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) prohibits using the symbols, or confusingly similar images, in app icons and logos.

## Typography

- Use San Francisco through iOS system text styles and Dynamic Type. Regular carries guidance; Semibold marks decisions and key figures.
- Use sentence case. Use monospaced digits for reps, time, and measured values. Avoid condensed display type and exaggerated tracking.
- Figma's visible specimens use Inter because its renderer does not display SF Pro. The file retains named SF Pro text styles for handoff; Inter is not the app font. Do not add a custom iOS font.

## Voice and imagery

Describe what Plumb can observe, then give one specific next step. Say “Your last two reps were shorter” rather than “Your form is wrong.” State tracking limits plainly and never imply injury prevention, diagnosis, or certainty from a single camera angle. In workout and feedback screens, prefer real movement with full-body context, fine evidence traces, and restrained motion. The Home dashboard uses a generated amber athlete backdrop as decorative artwork, not footage or evidence of a measured set. Avoid fake heatmaps and decorative AI motifs.

## Apple references

[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) · [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) · [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) · [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) · [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
