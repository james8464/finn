# Plumb privacy policy

**Published URL:** https://james8464.github.io/hackathon-project/privacy.html

**Effective date:** 13 October 2026. This policy describes the current iPhone release candidate; recheck the final signed upload before App Store submission.

- **Publisher:** James Durup
- **Contact:** jamesdurup@icloud.com

Plumb is an iPhone workout companion for reviewing supported exercises from a side view. It works without an account.

## Camera and workout data

With your permission, Plumb uses the iPhone camera during a set to estimate body position and count camera-visible repetitions. Camera frames are processed on your device. Plumb does not record a movie, save camera frames, or upload them to a Plumb server. The temporary pose trace is held in memory for the current result and cleared when you finish the session or start a new capture.

Plumb saves derived set summaries on your iPhone: session and set identifiers, date, exercise and rubric version, camera side, rep timing, relative range, optional per-rep posture readings, analysis confidence, a selected observation if any, and your response to that observation. These summaries are stored in the app's local Application Support area. They are not automatically sent to us or shared with other users. If you tap **Share summary** after a measured set, the iOS Share Sheet lets you choose where to send a text summary of the rep count and any observation you have not marked irrelevant. When Plumb can compare two compatible sets, the text also states the direction of the camera-measured range change. It contains no video or camera frames.

iOS may include local Application Support data in your device backup, including iCloud Backup if you enable it. Plumb does not operate or access that backup. See Apple's [file-system guidance](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively).

You can open **History** to delete a saved session or choose **Delete all local data**. The latter also removes any damaged-history backup created when you explicitly recover a corrupted local history. These actions remove data from the app on the current device; they do not erase an earlier iPhone backup. Removing the app also removes its local app data under normal iOS behavior.

## Optional Apple Intelligence wording

When available on your device, the app can ask Apple's on-device Foundation Models framework to reword an already measured comparison after you tap **Reword comparison**. It receives only the two derived set measurements, comparison direction, cue category, and referenced rep numbers. Plumb accepts only approved comparison wording with the supplied rep references and shows reviewed fallback wording if generation is unavailable, late, or inconsistent. This feature does not send camera images or raw pose traces to the model and Plumb does not operate an AI server.

## Optional spoken observation

If you tap **Listen to observation**, iOS speaks the measured rep count, the same displayed observation, and its next action through the current audio output. Plumb does not record or save this speech and does not use the microphone. Playback stops when you leave the result, mark the observation irrelevant, or tap **Stop speaking**.

## Accounts, analytics, and sharing

The current release candidate has no account, advertising SDK, third-party analytics, HealthKit integration, cloud sync, or in-app purchase flow. It does not ask for microphone access. Plumb does not record which Share Sheet destination you choose or upload the summary to a Plumb server. If these practices change in a later version, this policy and the App Store privacy answers must be updated before release.

## Your choices and contact

You can deny camera access or change it in iOS Settings; without camera access, live set review is unavailable. You can delete local results in the app. For questions about this policy or data handling, contact jamesdurup@icloud.com.

This policy will be updated when features or data practices change. It covers the app's current implementation, not separately consented research recordings used to validate the product.
