# Finn iPhone and Watch audit — 15–16 October 2026

## Scope and evidence

This is a **test-only review**. The audit branch changes no app source. The frozen iPhone/Watch candidate is `ea7259a` on `finn/interface-review`, carried into this branch through `b6837c2`; later commits on other feature branches are outside this result. The copied test source at `/tmp/finn-full-audit-dark-20261015` has a sorted SHA-1 manifest of its `Finn` files of `5abe5c2d940acd38dbd527ca52706530f0845320`.

Hardware and tools: Xcode 27; iOS 27 iPhone 18 Pro Max simulator (`11C0BAAB-3356-467A-90D3-322EA601EB3B`); paired watchOS 27 Apple Watch Series 12, 46 mm simulator (`4BDC8F2F-21A0-4352-A74A-46CC984E8403`). The final paired retry used a *fresh* iOS 27 iPhone 18 Pro Max (`7E71008B-5D12-4A17-BB18-3BDFFC2A755C`) and watchOS 27 Apple Watch Series 12 (`65AD898A-B1DB-4AA1-9087-1E7C4D68293D`), pair `F3B280E7-F624-4E59-B4FC-2542C84A035F`. Tests use labelled synthetic poses and generated video. They do not establish real-person count/cue accuracy or physical Watch behavior.

| Check | Result |
| --- | --- |
| iPhone/Watch build for testing | **Passed** on the frozen candidate. Both simulator apps were built; matching bundles were installed on the paired devices. |
| Swift logic tests | **501 passed** in the source-matched comprehensive simulator run. [Detailed interface review](full-app-ui-review-2026-10-15.md). An earlier candidate independently passed the same 501 tests. |
| Comprehensive simulator baseline | 582 combined logic and iPhone UI tests: **565 passed, 16 failed, 1 physical-camera test skipped**. The failures included stale UI expectations and accessibility reports. Focused reruns corrected the stale expectations; the linked review retains exact results and screenshots. |
| Focused dark/interface rerun | **20 passed, 2 contrast audits failed** on this candidate. Dark rendering under system Light, screen tours, Privacy/setup, large text, Reduce Motion, camera-denial recovery, chart bars, and navigation passed. |
| Generated Vision replay | **Passed** 15 squat-video variants plus mirrored and hidden-feet checks. Measurable clips counted six reps. Stillness, complete lower-body occlusion, excessive distance, blur and camera shake produced a final retake. The other five exercises have logic tests, not equivalent video-replay coverage. |
| iPhone synthetic set | **Passed**: six squats counted, one live cue shown, and a measured result produced. Input stayed clearly labelled as a demo. [Live](evidence/finn-device-audit/live-set.png) · [Result](evidence/finn-device-audit/range-result.png). |
| Large text and system Light | **Passed visual spot check** on the result screen at the largest accessibility text size. The app retained dark appearance and the main actions stayed visible. |
| Spanish home | **Mixed**: primary headings and actions translated, but “No awards yet” remained in English. [Capture](evidence/finn-device-audit/spanish-home.png). |
| Widget deep link | **Partly checked**: the URL parser passes its unit test; opening the URL in the simulator raised iOS's first-use “Open in Finn?” confirmation. The simulator had no controllable touch surface in this run, so destination navigation was not visually confirmed. |
| Watch idle screen | **Passed**: app opened with a legible iPhone prompt and visible settings control. [Capture](evidence/finn-device-audit/watch-idle.png). |
| Paired Watch live/result and language | **Failed end-to-end; cause unresolved.** On the fresh connected pair, both apps installed and the Watch opened, but it remained idle through a labelled six-rep iPhone result. The iPhone `wcd` log reported `paired:YES, appInstalled:NO` and `WCErrorCodeWatchAppNotInstalled`. An Xcode `test-without-building` run passed its **iPhone-only assertions** but the Watch was still idle afterward. This does not verify stage, coaching, or result delivery. [Six-rep phone result](evidence/finn-device-audit/clean-pair-phone-six-rep-result.png) · [Watch after six reps](evidence/finn-device-audit/clean-pair-watch-after-six-rep.png) · [Watch after Xcode test](evidence/finn-device-audit/clean-pair-watch-after-xcode-test.png). An earlier French relaunch ended with CoreSimulator `NSMachErrorDomain -308`, so language rendering is unconfirmed. |

### Feature coverage

| Feature | Evidence and limit |
| --- | --- |
| Six exercise choices, counting and posture rules | All six have Swift rule tests; the generated moving-video trial covers squat only. No independent human annotation certifies the cues. |
| Set controls, hands-free start, retake and camera denial | Logic and UI tests cover the transitions; a synthetic squat completed on the simulator. Live permission and camera behavior were not repeated on a physical iPhone in this audit. |
| History, comparison, awards, sharing and Coach | Logic and UI coverage is present; the source-matched UI review records the exact runs. Apple Intelligence service behavior and sharing to another app need device checks. |
| Onboarding, Options, Privacy, appearance and accessibility | UI tours and focused tests exercised these screens, including large text and Reduce Motion. Two contrast audits failed on this frozen candidate and were fixed on a later branch. Spanish copy remains incomplete. |
| Watch, AirPods, Health, Siri, widget and Live Activity | Message/policy and data-mapping tests pass. A Watch idle screen rendered, but paired live delivery remains unverified. Hardware-dependent taps, audio routing, Health authorization, spoken Siri use, signed widget provisioning and Lock Screen presentation remain open. |

## Findings

### F1 — Result chart wording needs an evidence qualification

**Medium.** A six-rep squat result said Finn **could not check squat depth from this camera position**, while displaying a **“Range per rep”** chart and a cue that range became shorter in the last two reps. Relative camera-observed motion may support that cue, but the interface does not explain the distinction from validated depth. A person could read the chart as a depth judgement despite the view limit. [Final candidate capture](evidence/finn-device-audit/range-result.png). The [earlier front-view capture](evidence/finn-device-audit/front-view-result.png) shows the same wording.

**Improvement:** Identify the chart as camera-observed motion, or add a short view-specific qualification beside it. Keep the existing count and withheld-advice behavior.

### F2 — README overstates the visible Watch experience

**Low.** The README says the companion mirrors the **count** and supports **start/stop messages**. `WatchSetView.swift` displays one coaching line and stage/status text, with a settings link for optional rhythm. It does not display a rep count or provide start/stop controls. The [Watch design document](../design/apple-watch-and-airpods.md) correctly says the iPhone owns set controls, but still describes a lime accent while the app uses pink.

**Improvement:** Reconcile the README and Watch design document with the intended release behavior, or add the missing Watch controls/count if those are required.

### F3 — Spanish iPhone localization is incomplete

**Medium.** Of 958 iPhone string-catalog entries, **125 lack Spanish** and three lack French. The Spanish gaps include workout, result, settings, and privacy copy; those screens fall back to English. On the running Spanish Home screen, **“No awards yet”** appeared in English beneath **“Premios”**. [Capture](evidence/finn-device-audit/spanish-home.png). The 38 Watch and 16 widget strings have entries in all four supported languages.

**Improvement:** Complete the remaining translations, especially visible actions and privacy disclosures, then inspect the full first-launch/workout/result path in Spanish.

### F4 — Two result contrast audits fail on this candidate

**Medium.** The focused UI run reported failures in `testCaptureAndResultAccessibilityAudits` and `testComparisonAndSavedHistoryAccessibilityAudits`. Its retained crops show the Debug “DEMO INPUT” banner and result text partly behind the scrolling header; a SwiftUI node had no auditable bounds. Follow-up isolation identified that node as the result toolbar’s **Done** button. The Debug banner is absent from Release. The [interface review](full-app-ui-review-2026-10-15.md) has the exact audit evidence. Subsequent fixes on `finn/interface-review` are outside this frozen candidate and need a fresh run.

**Follow-up outside this frozen candidate:** `finn/interface-review` commit `98a8f33` addressed the two audits; its focused rerun reported five passes, including the saved-history and largest-text checks. The updated candidate still needs its own complete validation before release. Keep full contrast auditing enabled.

### F5 — Disconnected Watch screen forces English

**Low, source review; French relaunch not completed.** `WatchSetView.swift` sets its SwiftUI locale from the latest iPhone state, but falls back to `en-GB` when there is no state. The first-launch prompt and settings therefore use English on an otherwise French or Spanish Watch until the phone sends a state, despite complete Watch translations. The English idle screen was confirmed visually. One French relaunch ended with CoreSimulator `NSMachErrorDomain -308`; a repeat remained on the launch image under heavy simulator load, so there is no French-screen capture.

**Improvement:** Use the Watch's current locale until a valid iPhone language arrives, then follow the iPhone language for shared set content.

### F6 — Paired Watch delivery fails on the clean simulator pair

**High; paired delivery failed, root cause not isolated.** Two earlier connected simulator-pair attempts left the Watch on its idle prompt during an iPhone set. One logged `wcd` failures to enumerate installed Watch apps (`NSXPCConnectionInvalid`) and “initial set up failed.” Restarting `wcd` did not restore delivery.

On 16 October, a new pair booted and showed **active, connected** in `simctl list pairs`. The frozen combined `Finn.app` installed on the iPhone; its embedded `FinnWatch.app` was also installed on the Watch, located with `simctl get_app_container`, launched, and displayed the normal idle screen. The companion identifier in the Watch's `Info.plist` matched the phone's bundle identifier (`ai.mwm.build.challenge.team.08`). Nonetheless, the phone's `wcd` log showed `WCSessionState reachable:NO, paired:YES, appInstalled:NO`, “WCSession counterpart app not installed”, and `updateApplicationContext failed due to WCErrorCodeWatchAppNotInstalled`. A labelled six-rep auto demo reached the [iPhone result](evidence/finn-device-audit/clean-pair-phone-six-rep-result.png); the [Watch remained idle](evidence/finn-device-audit/clean-pair-watch-after-six-rep.png). This establishes the visible failure and the OS-reported registration mismatch, but not whether packaging, simulator registration, or application code caused it.

The source-matched Xcode `test-without-building` run then installed/launched the same frozen iPhone candidate on that pair using `Finn_Finn_iphonesimulator27.0-arm64.xctestrun`. `WatchCompanionUITests.testDemoSetMirrorsToPairedWatch` **passed its single iPhone UI test** (156.887 seconds; result bundle `/tmp/Finn-watch-clean-pair.xcresult`), reaching Start set, Stop set, and Set reviewed. That test contains no Watch assertion. The [Watch still displayed the idle prompt after the Xcode run](evidence/finn-device-audit/clean-pair-watch-after-xcode-test.png). It should not be reported as a paired-delivery pass.

**Next check:** Diagnose Watch app registration and `WCSession.isWatchAppInstalled` on a physical paired iPhone/Watch or a simulator pair that reports the Watch app installed to `wcd`; then explicitly assert stage, coaching, and result on the Watch. Keep this gate open until those three states are observed. The current UI test should gain Watch-side assertions or evidence capture so its name cannot be mistaken for end-to-end coverage.

**Physical-device follow-up, 16 October:** Xcode sees the owner's iPhone 16 Pro Max on iOS 27.0.1, but its nearby-device pairing flow did not discover the worn Watch. The owner confirmed the Watch is paired to that iPhone and runs **watchOS 10.6.2** (older Apple Watch SE, exact generation unconfirmed). This build's Watch target has `WATCHOS_DEPLOYMENT_TARGET = 27.0`, so that Watch cannot install or run the candidate even if Xcode discovers it. The owner's Watch Developer Mode option was not visible. A signed iPhone build of the frozen candidate also stopped before compilation because the configured MWM team's provisioning profiles exclude this iPhone; Xcode's automatic device-registration attempt said the current account is not authorized to register it. The iPhone was not modified. Physical paired delivery therefore remains untested. Use a watchOS 27-capable Watch and a provisioning profile that includes the iPhone for this gate; the older Watch is still useful for a separate compatibility decision if the product lowers its Watch deployment target.

## Remaining validation

The simulator can check navigation, local data flows, generated-video set transitions, and paired Watch state synchronization. It cannot validate physical Watch taps with the wrist down, Health permission and Fitness writes on a person's devices, real AirPods audio routing, battery impact, or real camera/coach accuracy. Those remain release gates, as documented in the [Watch plan](../design/apple-watch-and-airpods.md) and [validation protocol](squat-v1-protocol.md).

The 501 passing Swift tests cover exercise rules, local history, comparisons, coaching selection, Watch messages, Health mapping, widgets, intents, and permissions logic. UI tests cover the main navigation, onboarding, setup, capture, results, settings, Privacy, Coach, awards and saved history. End-to-end Vision video evidence remains limited to squat variants; other exercises need representative moving clips and independently annotated counts/cues before accuracy claims. The simulator also cannot establish real Apple Intelligence availability, App Group provisioning on a signed phone, or actual Siri speech behavior.
