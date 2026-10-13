# Plumb Git Guide

**`main` is the shared source of truth.** Pull its latest changes before starting, and coordinate before editing the same files. Small, agreed changes can go directly to `main`; larger work can use a short-lived pull request that is reviewed and merged back into `main`. This keeps one lasting branch while allowing a teammate's work to be checked before it lands.

## First-time setup

```bash
git clone https://github.com/james8464/hackathon-project.git
cd hackathon-project
open Plumb/Plumb.xcodeproj
```

## Before editing

```bash
git switch main
git pull --ff-only origin main
git status
```

If you already have local edits and the pull cannot proceed, save or commit your work before resolving the conflict. Do not discard someone else's changes.

## Save and share a finished change

```bash
git status
git add <files-you-changed>
git commit -m "Describe the change"
git pull --rebase origin main
git push origin main
```

Review the files listed by `git status` before committing. Use a specific message, such as `Update workout coaching plan` or `Improve camera setup screen`.

If the rebase reports a conflict, resolve it and check the result before pushing. Ask a teammate when both people changed the same product behavior.

## Check the result

```bash
git status
git log -1 --oneline
```

A clean working tree and `main` up to date with `origin/main` mean the local checkout matches GitHub.

## When a teammate opens a pull request

Read the description and changed files, compare with current `main`, and check the automated tests. Try the affected flow if the change touches the app. **Approve** when it is mergeable, the behavior and copy are sound, and checks pass. **Request changes** when there is a concrete issue; explain the smallest fix and re-review after it is pushed. A request for changes is not a rejection of the idea. Avoid merging a stale or conflicting branch just because its feature sounds useful. Once merged, remove the temporary branch so `main` remains the only lasting branch.

The repository is public, but [LICENSE](../LICENSE) reserves rights to the named project members and grants other viewers no reuse license. Check rights before adding outside code, models, media, or nonpublic workout footage. Keep video fixtures synthetic or explicitly consented.
