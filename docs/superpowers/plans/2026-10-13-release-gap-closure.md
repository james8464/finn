# Release gap closure · 13 October 2026

The [README](../../../README.md) defines the submission scope: a reliable iPhone loop and a build submitted through App Store Connect. This plan closes the gaps that can be tested from the Mac without presenting generated footage as participant validation.

1. **Freeze a reproducible camera-condition suite.** Extend `tools/replay/generate_video_variants.py` with useful lighting, resolution, framing, and blur variants of the existing licensed fixture. Add cases to `tools/replay/test_generated_videos.sh` with explicit measured or retake expectations. Run every MP4 through Vision and the production analyzer. Keep provenance and limitations in `tools/replay/README.md`.
2. **Fix defects exposed by those replays.** First write a failing `FinnTests` case for any user-visible issue; then make the smallest production fix and rerun that case and the full relevant suite. Current example: a rejected set with 79.8% joint coverage is rounded to “80%” beside an 80% minimum.
3. **Verify the release candidate.** Check the hosted iOS workflow, run the local simulator and replay checks, build a Release archive, and run `docs/release/verify-archive.sh`. Update `docs/release/app-store-submission.md` with exact evidence.
4. **Keep claims aligned.** Update README and validation documents only with measured outcomes. Generated variants remain one source person and do not replace physical iPhone runs or specialist cue review.
5. **Record external gates.** Recheck device availability, App Store Connect distribution access, and PR #10. Leave teammate changes for its author while its requested changes, conflicts, and failing check remain open. Do not claim submission until App Store Connect records it.
