# Project cleanup and readability — 16 October 2026

## Scope

Inventoried all 1,154 tracked paths: text, binary assets and symlinks. Read every file for inventory, hashing and duplicate detection, then checked source references, project membership and presentation dependencies before deleting candidates. Graphify indexed 336 code inputs into 4,610 nodes and 11,591 edges. This is a repository inventory and dependency audit, not a claim that every image or movie received a fresh visual review.

The [file disposition inventory](project-cleanup-2026-10-16.csv) records each original tracked path. Removed 298 obsolete files (35.60 MiB of logical file content), plus replaced the old long-deck generator with its still-used helper module. Git history remains intact; these deletions do not shrink historical Git objects.

## Removed

- Old Plumb Figma export, Finder metadata and a machine-specific node_modules link.
- Generated frame caches, superseded long-deck previews, notes, SVG outputs, upload scripts and completed one-off patch scripts.
- Superseded film review files. Current Keynote, portable deck, playback movie, film, source footage, score, final mix and research remain.
- Unlinked Spark SDK binaries and wrapper. The project had no package reference or import of this SDK.
- Empty AppIcon asset-catalog placeholder. iPhone and Watch use the three-layer AppIcon.icon source.
- Unused HomeSymbol and Sparkline views; duplicate architecture plan.

## Readability and current identity

Expanded first-party Swift functions, guards, branches, loops, switch cases and argument lists. Added repeatable formatter configuration. Python and browser source use their standard formatters. Clarified geometry variables and extracted the rehearsal controls into readable player.js with descriptive camel-case names. Scene data stays separate JSON, preserving the Progress renderer's update path. Updated remaining active motto copy to “Stronger starts together.”

The old icon named in the request belonged to the backend-reliability worktree. Its icon package had no local edits; it now matches the current main icon. Other changes in that worktree remain untouched. Other dirty worktrees contain independent unfinished work and were not deleted or reset. The canonical checkout is /Users/james/Developer/Hackathon.

Historical validation and integration records, source dependencies and compatibility code remain when still useful. In particular, the old Plumb storage-folder name migrates existing workout history; deleting it would strand saved data. Empty onboarding image slots are referenced by the active onboarding flow and are not unused assets.

## Validation

- All 562 simulator unit tests in 66 suites pass.
- All 245 standalone backend tests in 19 suites pass.
- Python scoring tests: 11 pass. Clip-preparation tests: 8 pass, 1 skipped for an optional dependency.
- iPhone, Watch, widget and test targets build successfully after SDK/icon cleanup.
- All surviving first-party Swift files pass the configured formatter check.
- Local Markdown links resolve. Rehearsal playback, next-slide navigation, auto-advance control and speaker notes work without browser console errors.
- Current presentation delivery binaries are unchanged; hashes are checked against the starting revision.
- Startup and Progress UI smoke results are recorded before merge.
