# Native interface

Plumb uses four system tabs: Summary, Workout, History and Coach. Each keeps its own navigation state. Settings is available in the toolbar; Workout also has a menu for related screens.

- **Summary:** selected workout, seven-day activity, best set for the selected exercise, awards and the latest saved session.
- **Workout:** exercise selection, illustrated camera placement, relevant saved observations, and Start a set.
- **History:** saved measurements, session details and deletion controls.
- **Coach:** a conversation grounded in saved sets, with source information one tap away.

Use system text styles, a semantic white/black canvas and monochrome actions that invert with appearance. Reserve system glass for navigation and controls. Show real measurements; avoid decorative charts, unimplemented feature cards and generated photo backdrops. Keep camera controls legible over live footage.

[Research and design decisions](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG coverage](hig-ui-coverage.md) · [Verification](native-ui-verification.md) · [Implementation plan](../architecture/plans/2026-10-15-native-ui.md)

The earlier photo dashboard is preserved in Git history and [PR 25](https://github.com/james8464/hackathon-project/pull/25). Its screenshots describe that version, not the current interface.

## Widget refinement

Summary uses an illustrated selected-workout card, a seven-day rep widget, compact Best set/Awards tiles and a recent-session card. The chart groups sets by their local capture date and excludes future measurements. Empty history shows a short explanation instead of fabricated graph bars. Accessibility text sizes stack compact tiles vertically.

Keep this exploration on `ui/apple-native-revamp`. Do not merge it into main without James's instruction. Secondary surfaces use quiet grey fills and thin borders, without shadows; symbols identify content. System large titles collapse with the primary scroll view. Workout actions and the Coach composer use safe-area insets so content stays reachable.

## Chosen visual direction

James selected the earlier black-and-white exercise illustration as the strongest reference. Keep the large dark exercise card and capsule actions. Use Fitness-inspired compact widgets for real measurements, without coloured dashboard tiles or stock photography. Colour remains appropriate for Stop, errors and system status. Keep labels factual and short; omit introductory slogans and repeated explanations.
