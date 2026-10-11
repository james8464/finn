# Plumb physical iPhone run sheet

Use this on a connected iOS 27 iPhone before claiming a working camera-to-result experience. Record the device model, iOS build, Plumb commit/build, tester, date, and each result in [`squat-v1-results.md`](squat-v1-results.md). This smoke run checks the app path; it is **not** a substitute for the 30-set holdout or specialist review in [`squat-v1-protocol.md`](squat-v1-protocol.md). Use a consenting tester, bodyweight squats only, and keep bystanders out of frame.

| Check | Action | Expected result to verify |
| --- | --- | --- |
| First launch | Install a development build, open it, then tap **Set up camera** | Camera permission appears only after the tap; the preview is upright and matches the visible person |
| Denied permission | Deny Camera, tap **Try again**, then allow Camera in Settings and return | No live-analysis state while denied; the next attempt opens the preview without reinstalling |
| Setup and orientation | Place the phone upright at hip height, a few steps away; turn sideways | Full body fits in the preview; no unexpected mirroring or rotated pose result |
| First measured set | Do about six unloaded squats, tap **Stop set** | Count and named rep evidence match what the tester saw; any cue is camera-supported and understandable |
| Short or incomplete set | Stop after fewer than four full reps, then try an incomplete final rep | No unsupported technique cue or invented complete rep; retake path remains clear |
| Weak evidence | Safely obstruct the hip/ankle or move out of frame; test front and three-quarter views separately | Record whether Plumb abstains or gives a measured result. A measured unsuitable view is a validation failure to log, even if the UI looks plausible |
| Interruption | Background the app during preview and during a set; interrupt camera use if practical | Capture ends cleanly; no stale frames or false active-analysis state on return |
| Second set | Start another set in the same session | Comparison uses only the two completed sets and states changed/no clear change without a form or safety score |
| Local history | Open History, delete one session, then delete all local data | Deleted summaries disappear and remain absent after relaunch |
| Offline and optional recap | Turn on Airplane Mode, complete a set and comparison; try **Explain comparison** if offered | Core analysis works locally; unavailable or invalid generation uses reviewed wording |
| Accessibility | Repeat setup/result with Large Text, VoiceOver, Dark Mode, and Reduce Motion | Start/Stop stays reachable; recording status, result, evidence, and dismissal read in useful order |
| Duration and thermal | Run one long set until the two-minute limit; note temperature and memory behavior | Capture stops within the limit and produces an honest result or retake; no crash or runaway memory |

For latency, launch from Xcode with `-plumb-validation`, manually tap **Stop set**, and copy the on-screen **Stop to result** value for each scored set into the protocol sheet. The automatic two-minute stop has no comparable tap latency. Record exact failures and the camera position used; do not turn a successful simulator test into a physical-device pass.
