# Plumb 1.0 App Privacy answers — source-backed draft

**Audited against the 11 October 2026 iPhone source and unsigned archive. Not entered or published in App Store Connect.** Recheck the exact signed upload before the Account Holder, Admin, or App Manager saves and publishes these answers.

## Proposed App Store Connect selection

Choose **“No, we do not collect data from this app”** for the current Plumb 1.0 build, if the final upload retains the data flows below. Apple defines collection as transmitting data off the device so the developer or a third-party partner can access it beyond servicing a request. Apple says on-device-only processing is not collected for this label. This is an inference from [Apple's App Privacy Details definitions](https://developer.apple.com/app-store/app-privacy-details/) and the current code, not a published App Store answer.

| Data | Current handling | Developer access |
| --- | --- | --- |
| Camera frames | AVFoundation delivers frames to Vision on the iPhone; no movie or frame file is written | None through the app |
| Pose points and analysis | Held in memory for the set; used for rep count and one provisional cue | None through the app |
| Set summaries and feedback | JSON in the app's local Application Support directory; removable in History | None through the app |
| Optional recap | Apple's Foundation Models receives structured comparison facts on eligible devices; no Plumb server or third-party model endpoint | None through the app |
| Validation timing | A local result-screen readout only when Xcode launches with `-plumb-validation`; not saved or uploaded | None through the app |

The app currently has no account, analytics, advertising, support form, cloud sync, HealthKit, microphone capture, or third-party SDK. A source search found no `URLSession`, `URLRequest`, Network framework connection, web view, or upload path. The Xcode project has no package dependency or data-sharing entitlement. The unsigned archive contains the app binary and Apple asset catalog without a bundled data-collection SDK.

Local Application Support data may enter an iPhone backup if the person enables backup. Plumb neither operates nor accesses that backup; the [privacy policy draft](privacy-policy.md) explains this. Apple's App Privacy guidance says developers are not responsible for disclosing data collected by Apple itself. Confirm this treatment against the final Apple account configuration before publishing the label.

## Required final checks

1. Inspect the exact signed 1.0 upload for added SDKs, network calls, analytics, crash reporting, remote model use, or changed storage. Change the answer if any developer or third-party partner gains off-device access to fitness, camera, usage, or diagnostic data.
2. Verify normal and offline physical-iPhone behavior, including the optional Foundation Models fallback. A simulator source audit does not prove physical-device network behavior.
3. The [public HTTPS privacy-policy URL](https://james8464.github.io/hackathon-project/privacy.html), publisher name (James Durup), and support contact (jamesdurup@icloud.com) were verified on 11 October. Recheck before entering the URL in App Store Connect. Apple requires a privacy policy URL for iOS even when the app selects “Data Not Collected.” See [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
4. Have the authorized App Store Connect role review the product-page preview and publish the answers only after the uploaded build matches this audit. Record the actual published state in [the submission log](app-store-submission.md).

Separately consented research recordings for product validation are outside the app's 1.0 data flow and must follow the [validation protocol](../validation/squat-v1-protocol.md). If Plumb later uploads clips, syncs history, adds support messaging, or adds analytics, re-audit and update the App Privacy answers before release.
