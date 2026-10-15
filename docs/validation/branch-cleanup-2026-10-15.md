# Branch consolidation — 15 October 2026

Main already received the outstanding implementation through the squash integrations [#31](https://github.com/james8464/finn/pull/31) and [#32](https://github.com/james8464/finn/pull/32). Squashing explains why the original branches still appeared ahead in Git history. The keynote-readiness tree is identical to main at `f76e010`.

The Finn consolidation preserves that integrated implementation and adds the complete product rename, saved-data migrations, refreshed screenshots and publication configuration. It also preserves the three final attribution catalog entries from `e84ffd6` that were outside those integrations. The approved pink interface, measured coach selection, form trends, Watch rhythm, workout feedback, localization, onboarding replay, Apple Health and widget behavior remain integrated. The older release branch's movement illustration remains in Workout setup. Earlier competing screens and unrestricted model prose are superseded as recorded in the [integration review](branch-integration-2026-10-15.md).

Before deleting a remote branch, its exact tip is retained under an archive tag. These tags preserve every original commit and allow any branch to be restored without rewriting main's required linear history. Local worktrees with unfinished work are retained.

| Former active branch | Preserved tip | Archive tag |
| --- | --- | --- |
| `claude/adoring-wozniak-u81oz1` | `617a587f29` | [`archive/2026-10-15/claude/adoring-wozniak-u81oz1`](https://github.com/james8464/finn/tree/archive/2026-10-15/claude/adoring-wozniak-u81oz1) |
| `coach-conversational-ai` | `e84ffd6ead` | [`archive/2026-10-15/coach-conversational-ai`](https://github.com/james8464/finn/tree/archive/2026-10-15/coach-conversational-ai) |
| `design/visuals-tabs` | `c0ffdff05e` | [`archive/2026-10-15/design/visuals-tabs`](https://github.com/james8464/finn/tree/archive/2026-10-15/design/visuals-tabs) |
| `finn-release-fixes` | `3a70ffddb7` | [`archive/2026-10-15/finn-release-fixes`](https://github.com/james8464/finn/tree/archive/2026-10-15/finn-release-fixes) |
| `finn/feedback-localization-mwm` | `f3deae98c4` | [`archive/2026-10-15/finn/feedback-localization-mwm`](https://github.com/james8464/finn/tree/archive/2026-10-15/finn/feedback-localization-mwm) |
| `finn/form-analysis-optimization` | `cd6d0baffb` | [`archive/2026-10-15/finn/form-analysis-optimization`](https://github.com/james8464/finn/tree/archive/2026-10-15/finn/form-analysis-optimization) |
| `finn/watch-companion` | `689cb429d3` | [`archive/2026-10-15/finn/watch-companion`](https://github.com/james8464/finn/tree/archive/2026-10-15/finn/watch-companion) |
| `main-all-improvements-posture` | `7f79cb5475` | [`archive/2026-10-15/main-all-improvements-posture`](https://github.com/james8464/finn/tree/archive/2026-10-15/main-all-improvements-posture) |
| `main-keynote-readiness` | `460796f2ab` | [`archive/2026-10-15/main-keynote-readiness`](https://github.com/james8464/finn/tree/archive/2026-10-15/main-keynote-readiness) |
| `main-pink-watch-runtime` | `2c5287a0ba` | [`archive/2026-10-15/main-pink-watch-runtime`](https://github.com/james8464/finn/tree/archive/2026-10-15/main-pink-watch-runtime) |
| `onboarding` | `9aca3fae03` | [`archive/2026-10-15/onboarding`](https://github.com/james8464/finn/tree/archive/2026-10-15/onboarding) |
| `theophile/design` | `7e4ab1452f` | [`archive/2026-10-15/theophile/design`](https://github.com/james8464/finn/tree/archive/2026-10-15/theophile/design) |
| `ui/apple-native-revamp` | `1967def2e6` | [`archive/2026-10-15/ui/apple-native-revamp`](https://github.com/james8464/finn/tree/archive/2026-10-15/ui/apple-native-revamp) |
| `ui/theophile` | `5a98c970bb` | [`archive/2026-10-15/ui/theophile`](https://github.com/james8464/finn/tree/archive/2026-10-15/ui/theophile) |
| `ui/theophile-2` | `7e4ab1452f` | [`archive/2026-10-15/ui/theophile-2`](https://github.com/james8464/finn/tree/archive/2026-10-15/ui/theophile-2) |

Validation and release evidence: [Finn rename record](../release/finn-rename-status.md).
