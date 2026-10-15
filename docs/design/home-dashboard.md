# Finn interface

James requested Théophile’s original design on 15 October 2026, superseding the monochrome hybrid. Restore the source design from [design/visuals-tabs at c0ffdff](https://github.com/james8464/finn/tree/c0ffdff).

- Home uses the minimalist charcoal background (James’s subsequent request), pink Finn card, glass Last workout, Posture, Best set, Sessions and Awards cards, and scrolling Home/account header.
- The pink Finn card shows Try Finn and the demo until the person has tried Finn, then Finn speaking as the coach: an F badge, the next workout (day · time · intensity) and one quoted line of encouragement, a different one each time Home appears. The coach card is neon glass: see-through pink with a bright pink edge, a soft glow and white text; Increase Contrast and Reduce Transparency show it solid with black text. The switch is a temporary trigger (`FinnFirstTryTrigger.swift`) until the real first-try flow.
- Home widgets have no outline, except one light pink outline (1 pt, 40% opacity, concentric corners) that groups the Finn card and Last workout. Its outer edges align with the cards below. Use the exact sRGB Figma `brand/pink/selection` (`#FF2D92`), with black text on filled pink. Keep useful labels and measured facts; omit motivational headings and repeated explanatory subtitles.

The glass bar contains Home, Posture, Coach and Workout (+), with the original symbols, spacing, selection capsule and default label size. Stable dark fills and a subtle selection gradient retain the glass outline while keeping label contrast predictable.
- Posture opens measured set reviews. Workout opens setup, never the camera immediately. The illustrated demo neither records nor saves sample workouts.
- Preserve newer independent navigation stacks, saved data, localization, keyboard dismissal and camera/privacy behavior.
- Unavailable posture scores stay blank. Sample values appear only in explicitly labelled previews.

The original design uses dark appearance. At accessibility text sizes the tabs use two rows and Home cards stack. Tab labels retain 11 points at default size but scale with the body curve; caption2 plateaus at smaller settings. Preserve Reduce Motion and Reduce Transparency. Bottom actions must remain above navigation.

James requested integration into main after verification. Preserve current main functionality while keeping the approved Home / Posture / Coach / Workout destinations.

[Research](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG reference](apple-hig-agent-reference.md) · [Verification](native-ui-verification.md)
