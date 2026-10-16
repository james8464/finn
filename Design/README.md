# Finn brand theme

- [Live Figma brand guide](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q)
- [Production app icon and flat artwork](../Finn/BrandArtwork/README.md)
- [iPhone experience review and Apple design references](../docs/design/iphone-experience-review.md)

The live Figma guide covers the broader identity. The current production icon and its editable layers live in the Xcode project; use that source when the guide shows earlier icon concepts.

## Idea and identity

**Finn** is a workout coach. Its forward-leaning F has three separate plates: a silver stem, a light upper arm and a short pink crossbar. Use the layered [Icon Composer source](../Finn/Finn/AppIcon.icon) for the iPhone and Watch icons. The matching flat artwork is for small editorial uses. The promise is **“Find your line.”**

## Colour

Home uses a minimalist charcoal background, borderless cards and the exact Figma pink `#FF2D92` in place of lime. The source is [`brand/pink/selection`, node 68:12](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q?node-id=68-12), verified from the live file on 15 October 2026. Utility controls keep their semantic colours. See [interface rules](../docs/design/home-dashboard.md).

| Token | Hex | Role |
| --- | --- | --- |
| Black | `#000000` | Light appearance labels and primary action |
| White | `#FFFFFF` | Light canvas; dark appearance labels and primary action |
| Supporting | `#474747` | Reference for small supporting text in Light Mode |
| Grouped | `#F2F2F7` | Reference for optional grouped surfaces in Light Mode |
| Separator | `#C6C6C8` | Reference for quiet divisions in Light Mode |
| Pink accent | `#FF2D92` | Home selection and highlights |
| Icon ground | `#24282D` | App icon background |

The iPhone interface uses semantic iOS colours (`systemBackground`, primary labels, system separators) and a monochrome adaptive action. Supporting copy uses 72% of the adaptive primary label because the default secondary gray missed a small-text contrast audit in Light Mode. The values above are Figma references, not fixed overrides for system colours. The system resolves Light, Dark, and increased contrast appearances. Reserve colour for meaningful platform states such as a destructive action; never use colour alone to communicate a form judgement. The camera view should leave the person and their movement clearly visible.

The capture **Stop set** control is white over the camera in both appearances; red would suggest that Finn is recording video. History uses contrast-tested destructive red (`#C62828` in Light Mode, `#FF453A` in Dark Mode) only for deletion. This is a functional state, not a brand accent.

Use SF Symbols for interface actions where appropriate. Keep the app icon custom; Apple's [SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) prohibits using the symbols, or confusingly similar images, in app icons and logos.

## Typography

- Use San Francisco through iOS system text styles and Dynamic Type. Regular carries guidance; Semibold marks decisions and key figures.
- Use sentence case. Use monospaced digits for reps, time, and measured values. Avoid condensed display type and exaggerated tracking.
- Figma's visible specimens use Inter because its renderer does not display SF Pro. The file retains named SF Pro text styles for handoff; Inter is not the app font. Do not add a custom iOS font.

## Voice and imagery

Describe what Finn can observe, then give one specific next step. Say “Your last two reps were shorter” rather than “Your form is wrong.” State tracking limits plainly and never imply injury prevention, diagnosis, or certainty from a single camera angle. In workout and feedback screens, prefer real movement with full-body context, fine evidence traces, and restrained motion. Avoid fake heatmaps and decorative AI motifs.

## Apple references

[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) · [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) · [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) · [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) · [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
