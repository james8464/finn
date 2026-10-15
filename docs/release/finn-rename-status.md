# Finn rename and consolidation — 15 October 2026

## Delivered

- Renamed iPhone, Watch and widget products, Swift modules, tests, schemes, paths, launch flags, workflows, translations, StoreKit display text, artwork, documentation and support-site source to Finn.
- Preserved every Debug/Release bundle ID, the shared App Group and the HealthKit sync identity. Main app: `ai.mwm.build.challenge.team.08`.
- Preserved existing preferences, Watch pacing settings, history, badges, trained-model metadata and deep links through explicit compatibility migration. The previous name appears in eight implementation/test/config files solely for this purpose.
- Renamed the GitHub repository to [james8464/finn](https://github.com/james8464/finn), updated its description/homepage, branch names, issue/PR metadata and local remote. Branch consolidation and recoverable archive tags are recorded in the [branch audit](../validation/branch-cleanup-2026-10-15.md).
- Captured 21 current Finn screens, including Home, dark appearance, largest text, setup, privacy, options and the labelled synthetic set flow. Refreshed all ten release/demo image files. Historical design images are preserved at their original commit links.
- Refreshed the editable local Figma archive: four embedded screenshots, four legacy collection/mode names, and corresponding content hashes. The canvas has no former-brand text; ZIP integrity and image references were checked. Live Figma access is unavailable in this session, so the live guide still needs the updated local file imported or equivalent changes applied.

## Verification

| Check | Result |
| --- | --- |
| Swift logic and migration tests | 501 passed in 61 suites |
| UI tests on iPhone 18 Pro | 13 passed |
| Screenshot/UI tests on iPhone 18 Pro Max | 5 passed |
| Python validation, scoring and classifier preparation | 24 passed, 1 intentionally skipped |
| Generated-video replay checks | Passed |
| Release archive | Succeeded for iPhone, embedded Watch and widgets; signing disabled |
| Release archive inspection | Privacy manifest and Health purpose string present; Debug demo/validation code excluded |
| Local documentation links | Checked |
| Repository/Pages publication | See GitHub Actions for this main commit |

Test logs: `/tmp/finn-final-tests.log`, `/tmp/finn-max-capture-tests.log`, `/tmp/finn-final-release.log`, `/tmp/finn-final-replays.log`. The unsigned archive is `/tmp/Finn-final.xcarchive`.

The source and simulator checks do not validate physical camera coaching accuracy, device Health/Watch permissions or distribution provisioning. App Store Connect display-name/listing changes require its authenticated team session. The linked live Figma file cannot be edited here: its connector is unavailable and Figma Computer Use is not approved. The updated editable `.fig` file is included in the repository.
