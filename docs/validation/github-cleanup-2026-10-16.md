# GitHub branch consolidation — 16 October 2026

Main already contained the combined file tree from PR #36. This follow-up records the original
integration as a merge parent, preserving the individual branch histories after that squash.
It adds the two later motion/haptics commits and the latest physical Watch audit update.
All remote branch tips below are ancestors of the consolidated archive. Main requires linear
history, so the reviewed file changes are squash-merged and the complete branch history is
retained under `archive/2026-10-16/combined-branches`. No merge conflict was reported, and no
bundle identifier changed.

The motion changes route custom cues through the existing Off/Gentle/Regular preference,
shorten chart transitions, and respect the app's Reduce Motion setting.

## Branch tips preserved

| Branch | Commit |
| --- | --- |
| `claude/finn-home-screen-redesign-15a51a` | `f25eedfb8df96da783d9b653223290bb963ee777` |
| `claude/finn-nav-restructure-71c44c` | `fb290e6ddb960fdd080a891281e3d079e38a823d` |
| `design/finn-welcome-onboarding` | `e73a3506ce5d85d50952ff85c903808acf4ac1b1` |
| `finn/backend-reliability` | `1dc31c1a1b23145f7e1433780000ddeb02357e77` |
| `finn/full-device-audit` | `4239b1b5353564265f1b0a481ee01afb1fb59131` |
| `finn/icon-consistency` | `b1f3dd32612288d8603cd1476b7c84e7fec553d8` |
| `finn/interface-review` | `7e317f9a419fd3f6fa9a98e52bf08dcb8c061cd8` |
| `finn/layered-icon` | `7c746a0a1a58c6574d89cfb1c7e3ea87b2a7d387` |
| `finn/motion-haptics` | `0729b7f40596603b01c66271f0cc3f91958ddb80` |
| `finn/navig` | `50395fd83bb6fda8e8dabbd9362f5fce90fe83cd` |
| `finn/onboarding` | `4fa8d4a33a129801449562632b7b17292e6770eb` |
| `finn/presentation-refinement` | `7d5ea73394a16b65fcb0670f94eb60ec15c09fcb` |
| `main` | `05a2c75a9bb1dfc4684162221b86664e03cd21ef` |
| `main-integrate-all-20261016` | `b8424b5b53bfe9ae69c7406167a730d4aac817bb` |
| `main-preserved-finn-backend-reliability-20261016` | `f84480a5ed4f910090c72a7029e76d569449cf89` |
| `main-preserved-finn-keynote-quality-20261016` | `3f4207248b5de8e69c4d33865ee1afa95f18c89a` |
| `main-preserved-main-finn-rebrand-20261016` | `6342b9ef38cbe5c1e20ce0595108a21d3b88759b` |
| `theo-workouts-nila` | `f21f43428c5c242a3c77b9af8e18d79ddf183961` |

## Verification and cleanup

The consolidated tree passed 562 Swift unit tests in 66 suites, Coach submission/tab switching,
all dashboard destinations, and dark appearance/largest-text navigation in an iOS 27 simulator.
Full CI checks analysis, Release startup, all interface groups, Vision replay and the validation
scorer on the final main tree; superseded runs are cancelled to avoid duplicate work. Remote
branches are deleted only
after their captured tips are preserved in the archive and their reconciled changes are in main.
A changed remote tip must be reconciled rather than deleted.

The Watch audit still records simulator app-registration and physical-device compatibility/signing
limits. This consolidation does not claim those release gates have passed or establish accuracy
on unseen people from synthetic fixtures alone.
