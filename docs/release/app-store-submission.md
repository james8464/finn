# Plumb App Store submission track

**Status on 13 October 2026: preparing a release candidate; no App Store Connect upload has been verified.** The October 16 challenge target is a submitted build, not guaranteed App Review approval or public availability.

## Known project settings

| Item | Current state |
| --- | --- |
| Xcode project | `Plumb/Plumb.xcodeproj`, `Plumb` scheme |
| Platform | iPhone only, iOS 27.0 minimum |
| Bundle ID | `com.james8464.Plumb` in the project; ownership in App Store Connect unconfirmed |
| Version/build | 1.0 / 1; increment build for each upload |
| Xcode team | `Z29CKRV8C9` configured; paid Program membership and distribution rights unconfirmed |
| Local signing identities | One Apple Development identity is present; no Apple Distribution identity was found on 12 October. A development-signed Release archive for `com.james8464.Plumb` built and passed strict code-signature verification with the configured team; App Store distribution signing remains unverified |
| Connected physical iPhone | iPhone 16 Pro Max is **unavailable** to Xcode on 12 October. The last known pairing record says it was last connected on 1 October and Developer Mode was disabled; confirm both settings on the phone rather than treating cached device data as current |
| Repository | Public GitHub repository, `main` branch |
| Public pages | [Support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html) published via GitHub Pages on 11 October; both returned HTTPS 200 with the supplied publisher/contact details |
| Test status | On 13 October, local iOS 27 simulator checks passed 177 unit tests and three video UI tests. Four generated-video replays covered six clear squat reps, stillness, hidden legs, and covered feet; the three weak-evidence clips requested retakes. A local unsigned Release simulator build succeeded. These checks do not validate real-camera accuracy. A prior [hosted workflow for commit `694af9d`](https://github.com/james8464/hackathon-project/actions/runs/38241391066) and development-signed archive succeeded; the current revision still needs hosted verification and a new signed archive. Physical camera, cue, and headphone validation remains pending. |

James can purchase or confirm the Apple Developer Program membership. The team must then verify the Account Holder can enter App Store Connect, that the bundle ID belongs to the team, and that distribution signing works. A configured Xcode team ID alone does not establish these conditions.

## Physical iPhone setup needed for validation

Connect and unlock the iPhone 16 Pro Max with a suitable cable, accept any **Trust This Computer** prompt, then open **Settings → Privacy & Security → Developer Mode** on the iPhone. Turn it on, restart when prompted, and confirm **Enable** with the device passcode after restart. Reopen Xcode's Device Hub and verify the phone changes from unavailable to available before trying a development-signed run. The Developer Mode status above is from a cached, offline pairing record and must be rechecked once connected. [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) and [physical-device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) describe these steps. A personal Apple Account can be used for a development run; App Store upload still requires the appropriate distribution access.

## Required before archive/upload

1. Finish the physical iPhone checks and holdout/expert review in [`../validation/squat-v1-protocol.md`](../validation/squat-v1-protocol.md). In particular, check measured results from unsuitable front and three-quarter views, and check whether the sampled person mask rejects hidden joints without refusing clear ones. The Vision 3D camera-angle tip starts at 30° from profile, while sustained views at 75° or more can trigger refusal; these limits need physical iPhone validation. Follow [`../validation/exercise-rules-v1.md`](../validation/exercise-rules-v1.md), narrow unvalidated claims, and review actual Foundation Models output on an eligible device; if unavailable, keep the deterministic fallback.
2. **Completed for the current candidate:** James Durup and jamesdurup@icloud.com appear on the published [support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html) pages. The iPhone Privacy link opened the live policy in Safari on the iOS 27 simulator on 11 October. Recheck the pages against the final signed upload and confirm the link on a physical iPhone.
3. Audit the final binary's data flows and complete App Privacy answers. A [source-backed answer draft](app-privacy-answers.md) proposes “Data Not Collected” for the current build; the final answer must match the exact uploaded binary and account configuration. Apple requires a privacy policy URL and app privacy responses for iOS: [App privacy help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
4. Capture truthful screenshots from the implemented iPhone app. A [setup-screen candidate](screenshots/iphone-18-pro-max-setup.jpg) now exists at an accepted iPhone 18 Pro Max size, with [capture provenance](screenshots/README.md). It was taken from the normal simulator app, not a physical camera run. Final result and comparison screenshots remain pending physical-device validation. Do not pass the labeled synthetic demo feed off as a real camera workout. See [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
5. Verify a Release build, signing, first-launch permission, denial/recovery, set capture, retake, second set, comparison, local deletion, background interruption, offline behavior, large text, VoiceOver order, and no placeholder claims. Run [`verify-archive.sh`](verify-archive.sh) against the final `.xcarchive` to check that Debug-only synthetic demo and validation markers are absent. The current unsigned archive contains the expected bundle ID, version, camera permission text, and icon assets; an accidentally bundled team Git guide was removed from the app target. A development-signed archive also passes signature verification, but App Store distribution signing and upload remain open.

If the release build keeps the push-up, static lunge, and stiff-leg deadlift rubrics, the listing copy, support page, and privacy policy still describe a squat-only app and need the same scope before submission. The new checks run on the device (Vision 3D pose, and a Core ML exercise classifier once one is trained), so the "Data Not Collected" draft is unaffected, but recheck it against the final binary. Release builds exclude the Debug demo classifier and demo 3D feed; [`verify-archive.sh`](verify-archive.sh) also looks for `DemoExerciseClassifier`.

## Upload and submission

1. Create the Plumb app record in App Store Connect with the verified bundle ID and version 1.0. Complete category, age rating, availability, pricing, support URL, privacy URL, screenshots, and the copy in [`listing-copy.md`](listing-copy.md). Add a reviewer contact and the notes from that draft.
2. Archive the `Plumb` scheme in Xcode using a distribution signing team, validate the archive, upload it, and wait for build processing. A local unsigned Release build is not an uploaded build. [Apple's upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) explains processing and association by bundle ID/version.
3. Select the processed build on the app version, complete App Privacy, then **Add for Review** and **Submit for Review**. Record the exact state shown by App Store Connect; “Ready for Review” is not “In Review.” See [Apple's submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
4. Record date/time, app version/build, App Store Connect state, and any review message below. Do not claim acceptance until Apple confirms it.

## Submission log

| Date/time (Paris) | Version/build | State | Evidence / owner |
| --- | --- | --- | --- |
| 11 October 2026 | 1.0/1 local project | Not uploaded | Unsigned archive and setup screenshot candidate checked; test-only demo and validation markers excluded from Release binary; public support/privacy URLs verified; distribution signing, account access, physical device, result screenshots, and final validation pending |
