# Finn branch integration — 16 October 2026

The integration starts at main e05e330 and retains every original local and remote branch tip as an ancestor. The inventory records exact pre-integration SHAs. No branch was deleted or force-pushed. Other worktrees and their indexes were left intact.

## Reconciliation

- New onboarding, welcome/name/profile questions, personalised reactions, paywall, Home coach card, Progress/strength projection and Workout navigation come from finn/onboarding, including its navigation and redesign ancestors. Persistent preference keys retain their original bytes.
- Coach keyboard/composer, cancellation, bounded prompts, history refresh, model guards, tracking, geometry/evidence gates and accessibility fixes come from backend-reliability. The new Finn badge, analysis card and glass suggested questions use the reliable composer and transcript.
- The signature icon and corrected artwork come from icon-consistency/layered-icon. New Progress guide components replace the older standalone guide; measurement facts and playback/Reduce Motion behaviour remain.
- Root uncommitted changes, current native Keynote, portable deck, five-minute playback, unique film sources, research catalogue/clips and maintenance records are committed on finn/interface-review and merged here.
- Other dirty checkouts were committed with a separate temporary index to main-preserved-* branches, without changing their files or indexes. Backend CI test grouping and presentation capture/replay fixes are integrated. The old rebrand snapshot remains reachable, while the later main rebrand, licence, icon and interface supersede its older layouts and wording.
- Welcome design source/images and full-device audit evidence are merged directly.
- Older branches whose work was squashed into main by the 15 October integrations are recorded as merge parents without restoring obsolete Plumb paths/screens. These include localisation/feedback, Watch delivery/rhythm, rule-based form checks, release fixes and the earlier native interface. See the preceding branch-integration report and legacy-integration-parents.json.

## Validation

Debug app, Watch companion and test targets build. All original branch tips pass Git ancestry checks. Python validation scorer: 5 passed. Clip preparation: 8 passed, 1 skipped (optional dependency). Every UI test class is assigned exactly once to CI's three interface groups. Full simulator, generated Vision replay and Release smoke verification are in progress; the final results will be appended before main publication.

Failed CI reports expire after three days to avoid recreating the storage problem. Code graphs remain local.
