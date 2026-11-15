# Finn brand system

- [Live Figma brand guide](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q)
- [Production app icon and flat artwork](../Finn/BrandArtwork/README.md)
- [iPhone experience review and Apple design references](../docs/design/iphone-experience-review.md)

The live Figma guide covers the broader identity. The current production icon and its editable layers live in the Xcode project; use that source when the guide shows earlier icon concepts.

## Idea and identity

**Finn** is a workout coach. Its forward-leaning F has three separate plates: a silver stem, a light upper arm and a short pink crossbar. Use the layered [Icon Composer source](../Finn/Finn/AppIcon.icon) for the iPhone and Watch icons. The matching flat artwork is for small editorial uses. The promise is **“Stronger starts together.”**

## Colour

The whole app is dark-only, whatever the system appearance. The look is calm and restrained, like the brand cover: charcoal, white text, and pink as a thin accent rather than a surface.

| Token | Hex | Role |
| --- | --- | --- |
| Charcoal | `#202020` | Brand cover and welcome screen background |
| Home background | `#090909` | Behind the Home cards |
| White | `#FFFFFF` | Text; supporting text is white at 70% |
| Pink | `#FF2D92` | The brand accent ([Figma `brand/pink/selection`, node 68:12](https://www.figma.com/design/Y9asB4rM1J0tJcbr7Wim2q?node-id=68-12)). Exact sRGB value |
| Soft pink | `#F15FA1` | Lines and text only |
| Light pink | `#FF78B5` | Links and small highlights on supporting screens |
| Icon ground | `#24282D` | App icon background |
| Destructive | `#FF453A` | Deletion only |

### Using pink

- At 100%, `#FF2D92` is for lines up to 2 points (underlines, outlines, card edges, chart lines) and small marks up to 8 points on their shorter side.
- Any larger pink surface, button included, is 75% opacity or less. Finn's next-workout card on Home and the next workout on the Workout tab share one surface: `#FF2D92` from 55% to 30%, a 1.5-point full-strength edge, a soft glow and white text. Try Finn does not follow this rule yet: its fill goes from 80% to 50%, with a 2-point edge and a stronger glow.
- `#F15FA1` is never a fill: lines and text only.
- The outline that groups the Finn card and Last workout is 1 point of `#FF2D92` at 40%.
- One exception, for legibility: with Reduce Transparency or Increase Contrast the Finn cards become solid `#FF2D92` with black text.
- Do not add a new pink. Use the tokens above (`DashboardStyle.accent` in code).

Supporting screens use the system's dark grouped surfaces and native controls. Reserve other colours for meaningful states such as a destructive action; never use colour alone to communicate a form judgement. The camera view should leave the person and their movement clearly visible. See [what each screen contains](../docs/design/home-dashboard.md).

The capture **Stop set** control is white over the camera; red would suggest that Finn is recording video. History uses destructive red only for deletion. This is a functional state, not a brand accent.

Use SF Symbols for interface actions where appropriate. Keep the app icon custom; Apple's [SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) prohibits using the symbols, or confusingly similar images, in app icons and logos.

## Typography

- Use San Francisco through iOS system text styles and Dynamic Type. Regular carries guidance; Semibold marks decisions and key figures.
- Use sentence case. Use monospaced digits for reps, time, and measured values. Avoid condensed display type and exaggerated tracking.
- Figma's visible specimens use Inter because its renderer does not display SF Pro. The file retains named SF Pro text styles for handoff; Inter is not the app font. Do not add a custom iOS font.

## Voice and imagery

Describe what Finn can observe, then give one specific next step. Say “Your last two reps were shorter” rather than “Your form is wrong.” State tracking limits plainly and never imply injury prevention, diagnosis, or certainty from a single camera angle. In workout and feedback screens, prefer real movement with full-body context, fine evidence traces, and restrained motion. Avoid fake heatmaps and decorative AI motifs.

## Apple references

[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) · [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) · [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) · [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) · [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
