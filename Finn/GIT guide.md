# Finn Git Guide

**`main` is the shared source of truth, and nobody pushes to it.** Every change, however small, goes on a short-lived branch and reaches `main` through a reviewed pull request. This applies to people and to coding agents alike.

## First-time setup

```bash
git clone https://github.com/james8464/finn.git
cd finn
open Finn/Finn.xcodeproj
```

## Before editing

```bash
git switch main
git pull --ff-only origin main
git switch -c <short-topic-name>
```

If you already have local edits, they come along to the new branch. Do not discard someone else's changes.

## Save and share a finished change

```bash
git status
git add <files-you-changed>
git commit -m "Describe the change"
git push -u origin <short-topic-name>
gh pr create
```

Review the files listed by `git status` before committing. Use a specific message, such as `Update workout coaching plan` or `Improve camera setup screen`.

If `main` moved on and the pull request conflicts, update your branch with `git pull --rebase origin main`, check the result, and push the branch again. Ask a teammate when both people changed the same product behavior.

## When a teammate opens a pull request

Read the description and changed files, compare with current `main`, and check the automated tests. Try the affected flow if the change touches the app. **Approve** when it is mergeable, the behavior and copy are sound, and checks pass. **Request changes** when there is a concrete issue; explain the smallest fix and re-review after it is pushed. A request for changes is not a rejection of the idea. Avoid merging a stale or conflicting branch just because its feature sounds useful. Once merged, delete the branch so `main` remains the only lasting branch.

The repository is public, but [LICENSE](../LICENSE) reserves rights to the named project members and grants other viewers no reuse license. Check rights before adding outside code, models, media, or nonpublic workout footage. Keep video fixtures synthetic or explicitly consented.
