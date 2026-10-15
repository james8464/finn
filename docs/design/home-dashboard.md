# Native interface

Plumb uses four system tabs: Summary, Workout, History and Coach. Each keeps its own navigation state. Settings is available in the toolbar; Workout also has a menu for related screens.

- **Summary:** saved-session totals, recent workout, most measured reps for the selected exercise, and awards. Empty states explain the next step.
- **Workout:** exercise selection, illustrated camera placement, relevant saved observations, and Start a set.
- **History:** saved measurements, session details and deletion controls.
- **Coach:** a conversation grounded in saved sets, with source information one tap away.

Use system text styles, semantic grouped backgrounds and a single blue action accent. Reserve system glass for navigation and controls. Show real measurements; avoid decorative charts, unimplemented feature cards and generated photo backdrops. Keep camera controls legible over live footage.

[Research and design decisions](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG coverage](hig-ui-coverage.md) · [Verification](native-ui-verification.md) · [Implementation plan](../architecture/plans/2026-10-15-native-ui.md)

The earlier photo dashboard is preserved in Git history and [PR 25](https://github.com/james8464/hackathon-project/pull/25). Its screenshots describe that version, not the current interface.
