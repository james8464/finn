# Plumb App Store submission track

**Status on 11 October 2026: preparing a release candidate; no App Store Connect upload has been verified.** The October 16 challenge target is a submitted build, not guaranteed App Review approval or public availability.

## Known project settings

| Item | Current state |
| --- | --- |
| Xcode project | `Plumb/Plumb.xcodeproj`, `Plumb` scheme |
| Platform | iPhone only, iOS 27.0 minimum |
| Bundle ID | `com.james8464.Plumb` in the project; ownership in App Store Connect unconfirmed |
| Version/build | 1.0 / 1; increment build for each upload |
| Xcode team | `Z29CKRV8C9` configured; paid Program membership and distribution rights unconfirmed |
| Local signing identities | One Apple Development identity is present; no Apple Distribution identity was found on 11 October |
| Connected physical iPhone | iPhone 16 Pro Max is **unavailable** to Xcode on 11 October. The last known pairing record says it was last connected on 1 October and Developer Mode was disabled; confirm both settings on the phone rather than treating cached device data as current |
| Repository | Public GitHub repository, `main` branch |
| Public pages | [Support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html) published via GitHub Pages on 11 October; both returned HTTPS 200 with the supplied publisher/contact details |
| Test status | 69 iOS 27 simulator tests passed on 11 October, including a stalled-frame time-limit regression; a separate manual iPhone 18 Pro Max simulator run inspected setup, Privacy, synthetic capture/results, comparison, rep details, and saved History. The unsigned iPhone Release archive check succeeded; physical validation remains pending |

James can purchase or confirm the Apple Developer Program membership. The team must then verify the Account Holder can enter App Store Connect, that the bundle ID belongs to the team, and that distribution signing works. A configured Xcode team ID alone does not establish these conditions.

## Physical iPhone setup needed for validation

Connect and unlock the iPhone 16 Pro Max with a suitable cable, accept any **Trust This Computer** prompt, then open **Settings → Privacy & Security → Developer Mode** on the iPhone. Turn it on, restart when prompted, and confirm **Enable** with the device passcode after restart. Reopen Xcode's Device Hub and verify the phone changes from unavailable to available before trying a development-signed run. The Developer Mode status above is from a cached, offline pairing record and must be rechecked once connected. [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) and [physical-device run guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) describe these steps. A personal Apple Account can be used for a development run; App Store upload still requires the appropriate distribution access.

## Required before archive/upload

1. Finish the physical iPhone checks and holdout/expert review in [`../validation/squat-v1-protocol.md`](../validation/squat-v1-protocol.md). In particular, check measured results from unsuitable front and three-quarter views; the app does not yet have a validated automatic camera-angle check. Narrow any unvalidated claims in the app and listing. Review actual Foundation Models output on an eligible device; if unavailable, keep the deterministic fallback.
2. **Completed for the current candidate:** James Durup and jamesdurup@icloud.com appear on the published [support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html) pages. The iPhone Privacy link opened the live policy in Safari on the iOS 27 simulator on 11 October. Recheck the pages against the final signed upload and confirm the link on a physical iPhone.
3. Audit the final binary's data flows and complete App Privacy answers. A [source-backed answer draft](app-privacy-answers.md) proposes “Data Not Collected” for the current build; the final answer must match the exact uploaded binary and account configuration. Apple requires a privacy policy URL and app privacy responses for iOS: [App privacy help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
4. Capture truthful screenshots from the implemented iPhone app. A [setup-screen candidate](screenshots/iphone-18-pro-max-setup.jpg) now exists at an accepted iPhone 18 Pro Max size, with [capture provenance](screenshots/README.md). It was taken from the normal simulator app, not a physical camera run. Final result and comparison screenshots remain pending physical-device validation. Do not pass the labeled synthetic demo feed off as a real camera workout. See [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
5. Verify a Release build, signing, first-launch permission, denial/recovery, set capture, retake, second set, comparison, local deletion, background interruption, offline behavior, large text, VoiceOver order, and no placeholder claims. Run [`verify-archive.sh`](verify-archive.sh) against the final `.xcarchive` to check that Debug-only synthetic demo and validation markers are absent. The 11 October unsigned archive contains the expected bundle ID, version, camera permission text, and icon assets; an accidentally bundled team Git guide was removed from the app target. The unsigned archive cannot be uploaded as a distribution build.

## Upload and submission

1. Create the Plumb app record in App Store Connect with the verified bundle ID and version 1.0. Complete category, age rating, availability, pricing, support URL, privacy URL, screenshots, and the copy in [`listing-copy.md`](listing-copy.md). Add a reviewer contact and the notes from that draft.
2. Archive the `Plumb` scheme in Xcode using a distribution signing team, validate the archive, upload it, and wait for build processing. A local unsigned Release build is not an uploaded build. [Apple's upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) explains processing and association by bundle ID/version.
3. Select the processed build on the app version, complete App Privacy, then **Add for Review** and **Submit for Review**. Record the exact state shown by App Store Connect; “Ready for Review” is not “In Review.” See [Apple's submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
4. Record date/time, app version/build, App Store Connect state, and any review message below. Do not claim acceptance until Apple confirms it.

## Submission log

| Date/time (Paris) | Version/build | State | Evidence / owner |
| --- | --- | --- | --- |
| 11 October 2026 | 1.0/1 local project | Not uploaded | Unsigned archive and setup screenshot candidate checked; test-only demo and validation markers excluded from Release binary; public support/privacy URLs verified; distribution signing, account access, physical device, result screenshots, and final validation pending |
