# Plumb 1.0 App Privacy answers

**Draft checked 15 October 2026 against `main` at d8f1503 (`ai.mwm.build.challenge.team.08`, team 2FN6Y5NHS5) and its reported Release archive. Coach merged later; inspect the final archive before publishing these answers.** Not yet entered in App Store Connect.

## What to click tonight

App Store Connect > Plumb > App Privacy:

1. **Privacy Policy URL:** https://james8464.github.io/hackathon-project/privacy.html
2. **Data collection:** choose **No, we do not collect data from this app**, then **Publish**.

Export compliance, asked when you attach the build: the project declares `ITSAppUsesNonExemptEncryption = NO` for the app, watch and widget targets. Verify the exact signed archive and answer App Store Connect's export question from that build. Plumb does not add its own encryption; the Apple Foundation Models framework may use iOS networking for Private Cloud Compute.

Why the label stays Data Not Collected, feature by feature:

| Feature | Leaves the iPhone? | Label |
| --- | --- | --- |
| Camera, pose points, rep count | No; processed in memory on the device | not collected |
| Set summaries, patterns, earned Awards, first-launch choices, coach conversation | No; held in local app storage or memory, removable with Delete all local data | not collected |
| Health reading (Personalize with Health) and Health writing (Save workouts to Apple Fitness) | No; HealthKit store on the same iPhone, Plumb never reads it back for itself | not collected; the Health & Fitness data type stays unselected |
| Spoken reps | No microphone, no recording | nothing to declare |
| Apple Watch mirror | iPhone to paired watch over Apple's Watch Connectivity, nothing to a server | not collected |
| Reword comparison | On-device Foundation Models only | not collected |
| Coach (now in `main`) | The question, saved set summaries (exercise, reps, date, observation), and selected training goal and experience level go to Apple's Private Cloud Compute through the Foundation Models framework when the device supports Apple Intelligence; Apple states the requests are not stored and are used only for the request; the developer never receives them | not collected under Apple's definition (data transmitted off device is "collected" only when the developer or a partner can access it beyond servicing the request; and "you are not responsible for disclosing data collected by Apple", [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). Disclosed anyway in the privacy policy, section "Coach", and in the review notes |

The privacy manifest (`Plumb/Plumb/PrivacyInfo.xcprivacy`) matches: no tracking, no tracking domains, no collected data types, and required-reason declarations for UserDefaults (CA92.1) and system boot time (35F9.1). The coach adds no required-reason API.

### Coach: what the team must do before the server model can select sets

The Private Cloud Compute model is not open to every app. On 15 October Apple's page [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute) lists three conditions: the developer is enrolled in the App Store Small Business Program, has fewer than 2 million first-time downloads across its apps, and has the Private Cloud Compute entitlement assigned to the account, requested through the form that page links to ([developer forum answer](https://developer.apple.com/forums/thread/829539)). Installs through TestFlight or ad hoc do not count. Until the entitlement is granted to team 2FN6Y5NHS5, the server model reports itself unavailable and the coach falls back to on-device set selection, then to a fixed summary, which is what the code does. The build can be submitted without it. Apple's page says nothing about an extra App Store Connect declaration; the WWDC26 session [319](https://developer.apple.com/videos/play/wwdc2026/319/) says Private Cloud Compute "is designed with end-to-end privacy in mind, ensuring that user data is never stored", that requests "are counted with your user's iCloud account" and that "each user gets a daily limit". The Claude engine in the repository is compiled in Debug only and is absent from the Release binary (checked with `strings` on the archive); a Release build that included it would need a third-party-partner row in this table and a new privacy policy.

## Source audit of 13 October (still valid for the archive of 15 October)

### Proposed App Store Connect selection

Choose **“No, we do not collect data from this app”** for the current Plumb 1.0 build, if the final upload retains the data flows below. Apple defines collection as transmitting data off the device so the developer or a third-party partner can access it beyond servicing a request. Apple says on-device-only processing is not collected for this label. This is an inference from [Apple's App Privacy Details definitions](https://developer.apple.com/app-store/app-privacy-details/) and the current code, not a published App Store answer.

| Data | Current handling | Developer access |
| --- | --- | --- |
| Camera frames | AVFoundation delivers frames to Vision on the iPhone; no movie or frame file is written | None through the app |
| Pose points and analysis | Held in memory for the set; used for rep count and one provisional cue | None through the app |
| Set summaries and feedback | JSON in the app's local Application Support directory; removable in History | None through the app |
| User-initiated summary export | A text summary of the latest measured set and, when available, its compatible two-set range change opens in the system Share Sheet only after the person taps **Share summary**; the person chooses the destination | None through the app |
| Optional recap | Apple's Foundation Models receives structured comparison facts on eligible devices; no Plumb server or third-party model endpoint | None through the app |
| Spoken reps and observation | AVSpeechSynthesizer says the countdown, live rep counts and observations (on by default, Options switch) and reads the on-screen measured cue after a tap, through the system audio route; no microphone input or audio file | None through the app |
| Measured patterns per set | A list of measured patterns (for example "shallowMovements") inside each local set summary, used for the most-frequent-pattern focus | None through the app |
| Validation timing | A local result-screen readout only when Xcode launches with `-plumb-validation`; not saved or uploaded | None through the app |
| Health reading for personalization (optional, off by default) | After the person turns on **Personalize with Health** (Options, or the one-time offer after a first measured set) and allows types on Health's sheet, `HKSampleQueryDescriptor` and `HKStatisticsCollectionQueryDescriptor` read heart rate, resting heart rate, HRV, VO2 max, workouts, active energy, steps, sleep, date of birth, weight and height on the iPhone; the watch reads heart rate through a workout session it discards. Values are used in memory for on-screen tips and are not saved or sent | None through the app |
| Apple Health workout (optional, off by default) | After the person turns on **Save workouts to Apple Fitness** and allows it on Health's sheet, `HKWorkoutBuilder` writes one workout per finished session to the HealthKit store on the iPhone: type, start and end, pauses, indoor flag, set count, measured reps, exercise names. Share (write) permission for the workout type; reading is the separate personalization row above. The local session summary records the save date and Health's workout identifier | None through the app |

The app currently has no account, analytics, advertising, support form, cloud sync, microphone capture, or third-party SDK. A 13 October source search found no `URLSession`, `URLRequest`, Network framework connection, web view, or upload path. The Xcode project has no package dependency; its only entitlements are HealthKit on the iPhone and the watch (`Plumb/Plumb.entitlements`, `Plumb/PlumbWatch.entitlements`, no clinical records), used to write workouts and, when the person opts in, to read the types above. The development-signed Release archive of 13 October, built before HealthKit was added, passed `verify-archive.sh`: it excludes the Debug-only demo, video-file input, and validation paths. This source and binary check cannot establish what a future App Store upload will contain.

#### Why Apple Health workouts are not "collected"

Writing a workout to HealthKit does not change the proposed answer. Apple's definition of *collect* is "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time", and it states that "data that is processed only on device is not 'collected'" ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)). Plumb's workout goes from the app to the Health store on the same iPhone; Plumb has no server and never reads it back, so neither the team nor a third-party partner can access it. If Health syncs it through iCloud, that is Apple's processing under the person's Health settings, and Apple says developers "are not responsible for disclosing data collected by Apple". The **Health & Fitness** data types (which name the HealthKit API) apply only to data the app collects in that sense, so they stay unselected. This must be revisited if Plumb ever reads Health data and sends anything derived from it off the device. The privacy manifest's empty collected-data list stays correct; HealthKit is not a required-reason API.

Apple separately requires every HealthKit app to have a privacy policy, not to use Health data for advertising, and to disclose how it uses Health data ([Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)); the [privacy policy](privacy-policy.md) has an Apple Health section and the app's **Privacy** screen explains it. [App Review Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) forbids writing false or inaccurate data into HealthKit: Plumb writes only the measured set count and reps and a time span derived from set capture times and rep timing, and never estimates calories.

Local Application Support data may enter an iPhone backup if the person enables backup. Plumb neither operates nor accesses that backup; the [privacy policy draft](privacy-policy.md) explains this. Apple's App Privacy guidance says developers are not responsible for disclosing data collected by Apple itself. Confirm this treatment against the final Apple account configuration before publishing the label.

### Required final checks

1. Inspect the exact signed 1.0 upload for added SDKs, network calls, analytics, crash reporting, remote model use, or changed storage. Change the answer if any developer or third-party partner gains off-device access to fitness, camera, usage, or diagnostic data.
2. Verify normal and offline physical-iPhone behavior, including the optional Foundation Models fallback. A simulator source audit does not prove physical-device network behavior.
3. The [public HTTPS privacy-policy URL](https://james8464.github.io/hackathon-project/privacy.html), publisher name (James Durup), and support contact (jamesdurup@icloud.com) were verified on 11 October. Recheck before entering the URL in App Store Connect. Apple requires a privacy policy URL for iOS even when the app selects “Data Not Collected.” See [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
4. Have the authorized App Store Connect role review the product-page preview and publish the answers only after the uploaded build matches this audit. Record the actual published state in [the submission log](app-store-submission.md).

Separately consented research recordings for product validation are outside the app's 1.0 data flow and must follow the [validation protocol](../validation/squat-v1-protocol.md). If Plumb later uploads clips, syncs history, adds support messaging, or adds analytics, re-audit and update the App Privacy answers before release.
