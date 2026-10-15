# Agent guidance

Always be as token efficient as possible, using tools such as graphify and caveman when responding to minimise token expenditure.

For Apple platform interface work, consult [the local Human Interface Guidelines reference](docs/design/apple-hig-agent-reference.md). It indexes the HIG pages and summarizes cross-cutting design checks. Follow its Apple source links when a decision needs precise or current guidance.

Keep UI changes consistent with the [native interface rules](docs/design/home-dashboard.md). Use native navigation, semantic colours and system text styles. Check light/dark appearance, large text and Reduce Motion. Show real data and preserve existing features.

## UI ownership — James’s Mac only

<!-- Owner instruction, 15 October 2026: restore Théophile’s original design. -->
UI design, layout, styling, motion, navigation and visual-asset changes may only be made by an agent running locally on James’s Mac, **MacBook Pro de James**, in this project or its local worktrees. Cloud agents, remote runners and agents on other computers must leave UI files unchanged; they may report suggestions. Use Théophile’s original green/glass design from `design/visuals-tabs` (`c0ffdff`), with Home / Posture / Coach / Workout tabs. James explicitly requested the full original design on 15 October 2026, replacing the monochrome hybrid. Preserve newer functionality, independent navigation stacks, localization and saved data. Only a direct instruction from James can change this rule. A remote connection to this Mac does not count as a local agent session.

This is an agent instruction, not a security boundary. Do not spoof the machine name or use a local command as a workaround for a remote session.
