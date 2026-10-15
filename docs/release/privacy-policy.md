# Plumb privacy policy

**Published URL:** https://james8464.github.io/hackathon-project/privacy.html

**Effective date:** 15 October 2026. This policy describes the current iPhone release candidate; recheck the final signed upload before App Store submission.

- **Publisher:** James Durup
- **Contact:** jamesdurup@icloud.com

Plumb is an iPhone workout companion for reviewing supported exercises from a side view. It works without an account.

## Camera and workout data

With your permission, Plumb uses the iPhone camera during a set to estimate body position and count camera-visible repetitions. Camera frames are processed on your device. Plumb does not record a movie, save camera frames, or upload them to a Plumb server. The temporary pose trace is held in memory for the current result and cleared when you finish the session or start a new capture.

Plumb saves derived set summaries on your iPhone: session and set identifiers, date, exercise and rubric version, camera side, rep timing, relative range, optional per-rep posture readings, analysis confidence, a selected observation if any, your response to that observation, and, if you save workouts to Apple Health, when the session was saved and Health's identifier for that workout. These summaries are stored in the app's local Application Support area. They are not automatically sent to us or shared with other users. If you tap **Share summary** after a measured set, the iOS Share Sheet lets you choose where to send a text summary of the rep count and any observation you have not marked irrelevant. When Plumb can compare two compatible sets, the text also states the direction of the camera-measured range change. It contains no video or camera frames.

Your first-launch choices (training goal, experience level, favorite exercises and spoken feedback setting) are saved as preferences on this iPhone. Earned Awards are saved locally from measured set summaries. An Award with no flagged pattern means only that Plumb's current checks found no supported pattern; it does not certify perfect or safe form.

iOS may include local Application Support data in your device backup, including iCloud Backup if you enable it. Plumb does not operate or access that backup. See Apple's [file-system guidance](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively).

You can open **History** to delete a saved session or choose **Delete all local data**. The latter removes saved sessions, Awards, first-launch choices, app preferences and any damaged-history backup created when you explicitly recover a corrupted local history. These actions remove data from the app on the current device; they do not erase an earlier iPhone backup or revoke permissions held by iOS. Removing the app also removes its local app data under normal iOS behavior.

## Optional Apple Intelligence wording

When available on your device, the app can ask Apple's on-device Foundation Models framework to reword an already measured comparison after you tap **Reword comparison**. It receives only the two derived set measurements, comparison direction, cue category, and referenced rep numbers. Plumb accepts only approved comparison wording with the supplied rep references and shows reviewed fallback wording if generation is unavailable, late, or inconsistent. This feature does not send camera images or raw pose traces to the model and Plumb does not operate an AI server.

## Coach (optional, Apple Intelligence)

When you ask the coach a question, Plumb gives Apple's Foundation Models framework the question, recent saved set summaries (exercise, reps, date and observations), and your selected training goal and experience level if you provided them at first launch. Favorite exercises and spoken feedback preferences are not included. No image, video or pose point is included. On an iPhone that supports Apple Intelligence and has a connection, Apple's server model selects relevant saved sets through [Private Cloud Compute](https://security.apple.com/documentation/private-cloud-compute/), Apple's service designed so that requests are not stored and cannot be read by Apple staff; requests are counted against your iCloud account and may be subject to a daily limit set by Apple. Otherwise the on-device model selects the sets. If neither is available or a selection is invalid, Plumb shows a fixed response. Plumb always writes the displayed response from saved measurements; model-written coaching prose is never shown. Plumb has no server and uses no third-party model provider. Your conversation with the coach stays on your iPhone and is deleted with your other local data.

## Spoken reps and observations

Unless you turn off **Say reps aloud** in Options, iOS speaks the countdown, each counted rep, a short live observation when a rep is clearly faster or shorter than your first reps, the set's outcome, and, when hands-free framing cannot see what it needs, which joint is unclear. If you tap **Listen to observation**, iOS speaks the measured rep count, the same displayed observation, and its next action. Speech goes through the current audio output, such as AirPods. Plumb does not record or save this speech and does not use the microphone. Playback of an observation stops when you leave the result, mark the observation irrelevant, or tap **Stop speaking**.

## Hands-free sets and your most frequent pattern

With hands-free on (the default, changeable in Options), the app starts a set once you hold still in position and ends it when you walk away or stop moving, using the same on-device pose analysis. Each saved set summary also lists which measured patterns the set showed (for example movements too shallow to count), so the app can show your most frequent one before the next set. These are derived facts in the same local summaries, deleted with them.

## Apple Health and the Fitness app (optional)

**Save workouts to Apple Fitness** in Options is off until you turn it on. When you turn it on, iOS asks whether Plumb may save workouts to Apple Health; this option reads no Health data (reading is the separate Personalize with Health option below). Once you allow it, each time you finish a session with at least one measured set (**Done** after a set, **Finish session** on the first screen, or a new set more than 30 minutes after the previous one), Plumb writes one workout to Health on your iPhone: functional strength training, indoor, its start and end time (from the first measured rep to the end of the last set, with breaks over five minutes recorded as pauses), and three Plumb values: the number of measured sets, the measured reps, and the exercise names. Plumb never writes calories, heart rate, video, pose points, or observations to Health. Plumb remembers in its local summary that the session was saved, so it does not save it twice.

Health then holds the workout under your Health settings and Apple's privacy policy, not Plumb's: it appears in Health and the Fitness app, iOS may count it toward your Activity rings, and Health may sync it to your other devices through iCloud if you use that. Nothing leaves your iPhone through Plumb, and we cannot see these workouts. Deleting history in Plumb does not remove workouts already saved to Health; delete them in the Health app. You can stop future saves by turning the option off, and withdraw Plumb's permission in Health settings at any time. Data from demo or recorded input is never saved to Health. Plumb does not use Health data for advertising or share it with anyone.

## Personalize with Health (optional)

**Personalize with Health** is off until you turn it on, in Options or when Plumb asks once after your first measured set ("Make Plumb more personal?", with **Yes, personalize** and **Later**). When you turn it on, iOS asks, type by type, whether Plumb may read: heart rate, resting heart rate, heart rate variability, VO2 max, workouts, active energy, steps, sleep, date of birth, weight and height. You can allow some types and refuse others; Plumb cannot tell which ones you refused and simply works with what it can read. Options lists each type with what it is used for.

Plumb reads these values on your iPhone each time the first screen shows, and uses them only to adapt its advice: a lighter session after a short night, a heavy day or a resting heart rate above your weekly average; a longer rest between sets when you seem less recovered; the load of a push-up or squat from your weight; squat depth in centimeters from your height; how hard a set was from your heart rate and an age-based estimate of your maximum. Each tip names the data it rests on. These are coaching suggestions, not medical advice or a diagnosis. Plumb does not save what it reads: only the tips on screen use it, and they are not stored in your set summaries.

With an Apple Watch, Plumb runs a strength workout session on the watch while the iPhone camera is open, only when this option is on, to read your heart rate. The watch shows it and sends it to your iPhone, where it appears in the set's result. Plumb discards that watch workout when the camera closes, so Fitness does not show the session twice; the iPhone saves the session only if you turned on Save workouts to Apple Fitness.

Nothing Plumb reads from Health leaves your devices through Plumb, and we cannot see it. Plumb does not use Health data for advertising, share it with anyone, or use it for any purpose other than these tips. Turn the option off in Options at any time, and withdraw permissions in Health settings. Demo and recorded input never read Health.

## Accounts, analytics, and sharing

The current release candidate has no account, advertising SDK, third-party analytics, cloud sync, or in-app purchase flow. Its HealthKit uses are the optional workout saving and the optional Personalize with Health reading above, both on your devices only. It does not ask for microphone access. The only data that leaves your iPhone through Plumb is a coach request handled by Apple, described above. Plumb does not record which Share Sheet destination you choose or upload the summary to a Plumb server. If these practices change in a later version, this policy and the App Store privacy answers must be updated before release.

## Your choices and contact

You can deny camera access or change it in iOS Settings; without camera access, live set review is unavailable. You can delete local results in the app. For questions about this policy or data handling, contact jamesdurup@icloud.com.

This policy will be updated when features or data practices change. It covers the app's current implementation, not separately consented research recordings used to validate the product.
