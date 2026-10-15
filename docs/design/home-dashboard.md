# Plumb interface

James requested Théophile’s original design on 15 October 2026, superseding the monochrome hybrid. Restore the source design from [design/visuals-tabs at c0ffdff](https://github.com/james8464/hackathon-project/tree/c0ffdff).

- Home uses the original full-colour background, lime Try Plumb/demo card, glass Last workout, Posture, Best set, Sessions and Awards cards, and scrolling Home/account header.
- The glass bar contains Home, Posture, Coach and Workout (+), with the original symbols, spacing, selection treatment and default label size.
- Posture opens measured set reviews. Workout opens setup, never the camera immediately. The illustrated demo neither records nor saves sample workouts.
- Preserve newer independent navigation stacks, saved data, localization, keyboard dismissal and camera/privacy behavior.
- Unavailable posture scores stay blank. Sample values appear only in explicitly labelled previews.

The original design uses dark appearance. At accessibility text sizes the tabs use two rows and Home cards stack. Tab labels retain 11 points at default size but scale with the body curve; caption2 plateaus at smaller settings. Preserve Reduce Motion and Reduce Transparency. Bottom actions must remain above navigation.

Keep work on `ui/apple-native-revamp` with PR 26 draft. Main and teammates’ branches are independent.

[Research](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG reference](apple-hig-agent-reference.md) · [Verification](native-ui-verification.md)
