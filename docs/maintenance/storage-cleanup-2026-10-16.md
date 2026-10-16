# Storage cleanup — 16 October 2026

Local free space rose from about 4.3 GiB to about 14 GiB. APFS sharing and snapshots mean allocated file sizes do not equal immediately recovered space.

Presentation storage fell from 1.8 GiB to 207 MiB. Removed obsolete version archives, duplicate Keynote/PPTX/movie exports, decoded frame caches, intermediate renders and superseded audio mixes. Preserved final Keynote, PPTX, five-minute playback, original film footage and score, selected native inputs, source artwork, current scene movies, script and rebuild tools.

Removed Finn compilation/test caches in /tmp and Xcode DerivedData, superseded raw capture takes, downloaded design-resource disk images after ejecting them, and downloaded film clips only after verifying exact matches with retained source files. The companion JSON logs the second cleanup phase; the initial phase removed old presentation revisions and the first compilation caches before encountering a mounted read-only design-resource image. That image was ejected and cleanup resumed.

GitHub: deleted 93 superseded test-report artifacts, totalling 10.80 GiB. Retained the two newest main-branch reports, newest backend reliability report and the Pages deployment artifact. No Actions caches or release assets existed. Repository source assets and replay fixtures are still needed. Git history and worktrees were retained; Git storage was compacted without pruning history. Existing uncommitted app and CI changes were preserved.

Verified all ten embedded Keynote movies against current masters, reopened the final Keynote, and checked rehearsal/script links after cleanup.
