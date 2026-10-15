# Plumb interface

Use Home, Posture, Coach and Workout (+), in that order. James approved restoring Théophile’s tab composition on 15 October 2026. The floating bar uses his home, runner, person-with-sparkles and plus symbols. Each destination retains its own navigation stack.

- **Home:** selected exercise illustration, seven-day measured reps, best set, awards and latest saved session. Activity opens History.
- **Posture:** saved sessions and their measured set reviews. Do not invent posture scores.
- **Coach:** conversation grounded in saved sets, with source information available.
- **Workout:** exercise selection, camera-placement illustration and Start a set. Selecting the plus tab opens setup; it does not start the camera.

Keep the black-and-white foundation, system text styles and concise labels. Théophile’s original background is desaturated and softened behind Home. Lime highlights selected tabs, exercise chips and action arrows; charts use a darker green in light appearance for contrast. Other content surfaces remain opaque. Preserve light/dark appearance, Dynamic Type, Reduce Motion and Reduce Transparency.

Large titles collapse with scrolling. Bottom controls respect safe areas. The tab bar hides while the keyboard is open; the Coach composer remains accessible. At accessibility text sizes tab labels remain visible, the bar uses two rows, and Home widgets stack vertically. Coach offers a Done keyboard control to restore navigation without sending a message.

## Source and preservation

Théophile’s branch is [design/visuals-tabs](https://github.com/james8464/hackathon-project/tree/design/visuals-tabs), last inspected at `c0ffdff`. His dashboard originated in `536d3ba`; the branch and its history were not lost. This refinement reuses the original HomeBackdrop asset and tab composition without replacing the app’s measurement or storage logic.

Keep the combined design on `ui/apple-native-revamp` and PR 26 draft until James requests a merge. Other worktrees remain independent.

[Research](../architecture/specs/2026-10-15-native-ui-design.md) · [HIG coverage](hig-ui-coverage.md) · [Verification](native-ui-verification.md)
