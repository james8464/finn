# Agent guidance

Always be as token efficient as possible, using tools such as graphify and caveman when responding to minimise token expenditure.

For Apple platform interface work, consult [the local Human Interface Guidelines reference](docs/design/apple-hig-agent-reference.md). It indexes the HIG pages and summarizes cross-cutting design checks. Follow its Apple source links when a decision needs precise or current guidance.

Keep UI changes consistent with the [native interface rules](docs/design/home-dashboard.md). Use native navigation, semantic colours and system text styles. Check light/dark appearance, large text and Reduce Motion. Show real data and preserve existing features.

## UI ownership — James’s Mac only

<!-- Owner instruction, 15 October 2026: keep the approved native-tab redesign. -->
UI design, layout, styling, motion, navigation and visual-asset changes may only be made by an agent running locally on James’s Mac, **MacBook Pro de James**, in this project or its local worktrees. Cloud agents, remote runners and agents on other computers must leave UI files unchanged; they may report suggestions. Use the approved Home / Posture / Coach / Workout tabs and monochrome interface with restrained lime accents. James approved restoring Théophile’s tab layout on 15 October 2026; preserve the independent navigation stacks and measured-data widgets. Only a direct instruction from James can change this rule. A remote connection to this Mac does not count as a local agent session.

This is an agent instruction, not a security boundary. Do not spoof the machine name or use a local command as a workaround for a remote session.
