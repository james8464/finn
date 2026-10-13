# Plumb App Store listing copy — draft

This draft describes the current four-exercise iPhone build. Review every claim against a physical iPhone and the final signed build before publication.

- **Name:** Plumb
- **Subtitle:** See your next set clearly
- **Primary category:** Health & Fitness
- **Keywords (draft):** workout,exercise,rep,training,fitness,movement
- **Support URL:** https://james8464.github.io/hackathon-project/support.html
- **Privacy policy URL:** https://james8464.github.io/hackathon-project/privacy.html

## Description

Find your line, one set at a time.

Plumb uses your iPhone camera to review a bodyweight squat, push-up, static lunge, or stiff-leg deadlift from the side. Set your phone where the movement is visible, complete a set, and see the repetitions Plumb could measure. When the view supports it, Plumb highlights one specific pattern and the reps behind it. Try another set to compare the same camera-measured range.

If evidence does not support an observation, Plumb asks for a better view or says that no clear pattern was found. It does not certify perfect overall form.

Your workout video is not saved. Derived set summaries are stored locally in Plumb, and you can delete them in the app. When an observation is available, you can choose to hear it through your iPhone or paired headphones. On eligible devices, Apple Intelligence can help phrase a measured comparison; reviewed wording is always available when it cannot.

If you choose, Plumb saves each finished session to Apple Health as a strength training workout, with its time, sets, and measured reps, so it shows in the Fitness app alongside your other workouts. Plumb only writes these workouts, never calories or heart rate, and reads nothing from Health.

Plumb observes one camera angle. It cannot assess every part of your movement, diagnose an injury, or guarantee safe technique. It asks for a retake when required joints or complete repetitions are missing. It cannot yet verify that every camera position is suitable for a side-view measurement.

## What's new, version 1.0

Four side-view strength exercises, evidence-linked observations, retake guidance, optional spoken results, local session history, set-to-set comparison, and optional saving of finished sessions as workouts in Apple Health and the Fitness app.

## App Review notes — draft

No account is required. The app requests Camera permission when the person taps **Set up camera**. Choose one of the four listed exercises and place the iPhone upright with a full side view of the person. The set result appears after **Stop set**; a short or poor view returns a retake prompt. Video is processed locally and is not saved. A measured observation can be read aloud after a tap on **Listen to observation**; no microphone permission is requested or audio recorded. Saved sessions can be deleted individually or all at once from **History**. **Reword comparison** uses Apple's on-device Foundation Models only if available; otherwise it uses a reviewed local template. No paid feature is in this build. Reviewers can use the app without a demo account.

**HealthKit (write-only, optional).** Plumb uses HealthKit for one fitness purpose: saving a finished Plumb session as a workout so it appears in the Health and Fitness apps. To review it: open **Options**, turn on **Save workouts to Apple Fitness**, and allow Workouts on the Health sheet. Complete a measured set, then tap **Done** on the result: the first screen says **Saved to Fitness**, the session in **History** is marked saved, and the workout (Functional Strength Training) appears in Health > Browse > Activity > Workouts and in Fitness. Plumb requests share (write) permission for the workout type only and reads no Health data. Each workout holds the session's start and end time (breaks over five minutes recorded as pauses), indoor, and Plumb's set count, measured reps, and exercise names. Plumb writes no energy, heart rate, or other estimated values, and never uses Health data for advertising or shares it. The workout stays in Health on the device; Plumb has no server. The **Privacy** screen and the privacy policy describe this. The read-access purpose string is present only because App Store Connect's upload validation has asked HealthKit apps for it; Plumb never requests read access.
