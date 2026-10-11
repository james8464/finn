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
| Connected physical iPhone | iPhone 16 Pro Max appears in Xcode's device list but was **unavailable** on 11 October |
| Repository | Public GitHub repository, `main` branch |
| Test status | 54 iOS 27 simulator tests passed; unsigned iPhone Release build and archive succeeded; physical validation pending |

James can purchase or confirm the Apple Developer Program membership. The team must then verify the Account Holder can enter App Store Connect, that the bundle ID belongs to the team, and that distribution signing works. A configured Xcode team ID alone does not establish these conditions.

## Required before archive/upload

1. Finish the physical iPhone checks and holdout/expert review in [`../validation/squat-v1-protocol.md`](../validation/squat-v1-protocol.md). Narrow any unvalidated claims in the app and listing. Review actual Foundation Models output on an eligible device; if unavailable, keep the deterministic fallback.
2. Confirm the publisher name and public support email. Host and check public **HTTPS** support and privacy policy pages based on [`support.md`](support.md) and [`privacy-policy.md`](privacy-policy.md). The Markdown drafts alone are not App Store URLs.
3. Audit the final binary's data flows and complete App Privacy answers. The current code has no app server, third-party SDK, account, analytics, or cloud sync, but the final answer must match the exact uploaded build. Apple requires a privacy policy URL and app privacy responses for iOS: [App privacy help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).
4. Capture truthful screenshots from the implemented iPhone app. A [setup-screen candidate](screenshots/iphone-18-pro-max-setup.jpg) now exists at an accepted iPhone 18 Pro Max size, with [capture provenance](screenshots/README.md). It was taken from the normal simulator app, not a physical camera run. Final result and comparison screenshots remain pending physical-device validation. Do not pass the labeled synthetic demo feed off as a real camera workout. See [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
5. Verify a Release build, signing, first-launch permission, denial/recovery, set capture, retake, second set, comparison, local deletion, background interruption, offline behavior, large text, VoiceOver order, and no placeholder claims. The 11 October unsigned archive contains the expected bundle ID, version, camera permission text, and icon assets; an accidentally bundled team Git guide was removed from the app target. The unsigned archive cannot be uploaded as a distribution build.

## Upload and submission

1. Create the Plumb app record in App Store Connect with the verified bundle ID and version 1.0. Complete category, age rating, availability, pricing, support URL, privacy URL, screenshots, and the copy in [`listing-copy.md`](listing-copy.md). Add a reviewer contact and the notes from that draft.
2. Archive the `Plumb` scheme in Xcode using a distribution signing team, validate the archive, upload it, and wait for build processing. A local unsigned Release build is not an uploaded build. [Apple's upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) explains processing and association by bundle ID/version.
3. Select the processed build on the app version, complete App Privacy, then **Add for Review** and **Submit for Review**. Record the exact state shown by App Store Connect; “Ready for Review” is not “In Review.” See [Apple's submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
4. Record date/time, app version/build, App Store Connect state, and any review message below. Do not claim acceptance until Apple confirms it.

## Submission log

| Date/time (Paris) | Version/build | State | Evidence / owner |
| --- | --- | --- | --- |
| 11 October 2026 | 1.0/1 local project | Not uploaded | Unsigned archive and setup screenshot candidate checked; distribution signing, account access, physical device, public URLs, result screenshots, and final validation pending |
