# Apple Watch and AirPods during a set

_13 October 2026. Status: unit-tested (messages, roles, set mirroring) and compiled in Xcode for the iPhone and watch simulators; not yet run on a physical Apple Watch or with AirPods._

**In the build since 13 October.** The `PlumbWatch` target is a single-target SwiftUI watch app (watchOS 10 or later, bundle `com.james8464.Plumb.watchkitapp`, companion of `com.james8464.Plumb`), embedded in the iPhone app under `Watch/`. That makes `WatchBridge.isWatchAppBundled` true, so the iPhone activates WatchConnectivity. It compiles the `Plumb/PlumbWatch` folder plus `Workout/WatchMessages.swift` and `AppIcon.icon` through a synchronized-folder membership exception; `AppIcon.icon` now lists watchOS among its platforms. Building the `Plumb` scheme also builds the watch app, so Xcode and CI need the watchOS platform. A team that signs with its own bundle prefix changes the watch's bundle identifier and `WKCompanionAppBundleIdentifier` together.

Théophile asked to define, per exercise, whether Plumb needs an Apple Watch and/or AirPods; to check whether each is connected; to run that device's loop when it is; and, ideally, to give near-real-time feedback on the wrist during a set ("faster", "slower") so the person works the muscle better.

**What exists now:** neither device is needed for any exercise. Both only deliver what the iPhone camera measured, closer to the person, who stands a few steps from the phone. Neither adds a measurement yet, so neither changes the analysis or the observation after the set.

## Per-exercise roles

Defined in `Plumb/Plumb/Workout/Accessories.swift` (`AccessoryRoles`), tested in `AccessoriesTests.swift`.

| Exercise | AirPods or headphones | Apple Watch |
| --- | --- | --- |
| Squat | Hear the countdown, each rep and live observations | See the rep count, feel a tap on each rep and a distinct tap for a live observation, start and stop the set from the wrist |
| Static lunge | Same | Same |
| Stiff-leg deadlift | Same | Same |
| Push-up | Same | See the rep count and feel the taps only: the hands are planted on the floor, so the set starts and stops from the iPhone or hands-free |

Required: no, for every exercise and both devices. The live observations are the ones the iPhone already measures during a set (`LiveSetEvent`): a rep clearly faster than the person's first reps, and a rep with a clearly shorter range. There is no "slower" cue and no tempo target; adding one means adding a measured, tested rule to `LiveSetMonitor` first, and then the watch shows it with no protocol change.

On push-ups (the only arm exercise today), the wrist tap is the near-real-time feedback: the person feels each counted rep and a different tap when a rep is faster or shorter than their first ones, without looking.

## Setup screen line

`AccessoryGuide.setupLines` gives at most one line per device, below the setup steps. Nothing is shown when neither is around.

- Headphones as the audio output: "Headphones connected: you will hear each rep." (or a hint to turn on Say reps aloud). The audio route tells Bluetooth or wired headphones, not the model, so the line says headphones rather than AirPods.
- Watch paired, Plumb not installed: "Apple Watch: install Plumb on your watch to see reps on your wrist."
- Installed, not open: "Apple Watch: open Plumb on your watch to see reps and start sets from your wrist." (push-ups: "...feel a tap on each one.")
- Open and reachable: "Apple Watch connected: ..." and a small "Apple Watch connected" label on the camera screen.

## How it runs

- **iPhone camera** measures the set as before. `WorkoutSessionModel` is unchanged.
- **`WatchSync`** (pure, compiled and tested on Linux) follows the model with Observation and builds one `WatchState` per change of what the watch shows. It derives the tap by comparing with the previous state: set start, each new rep, a new live observation (outranks the rep it came with), set end. It also applies wrist commands: Start set only while framing, Stop set only while the set runs, never for push-ups. A wrist start uses the hands-free countdown.
- **`WatchBridge`** (WatchConnectivity) carries states: `sendMessage` when the watch app is reachable, otherwise `updateApplicationContext` with the latest state only (nothing queues up, no `transferUserInfo`). When the watch becomes reachable or the session activates, it resends the current screen without a tap.
- **`AccessoryMonitor`** reads `AVAudioSession.sharedInstance().currentRoute.outputs` for Bluetooth A2DP, LE, HFP and wired headphone ports (AirPlay excluded) and listens to `routeChangeNotification`. It never activates or reconfigures the app's audio session; spoken reps keep using `LiveAnnouncer`, which plays through the current route.
- **Watch app** (`Plumb/PlumbWatch`): `WatchLink` receives states, keeps only a newer one (`sentAt`), plays taps only for live messages (a saved application context never taps), ignores a saved state older than 10 minutes, and sends Start set and Stop set. `WatchSetView` shows the exercise, stage ("Get in position", countdown, "Set running", "Reviewing", the result line), a large rep count and the latest observation.

Wiring: only the live camera path connects accessories (`ContentView(connectsAccessories: true)` in `PlumbApp`). Demo and video input, used by UI tests, stay off the watch unless the Debug launch argument `-plumb-watch-demo` is passed; the watch then shows DEMO INPUT.

## Message protocol

`Plumb/Plumb/Workout/WatchMessages.swift`, compiled by both targets (the watch target includes this one file through a synchronized-folder membership exception). Property-list dictionaries, keys below; nil values are left out. Tested by `WatchMessagesTests.swift`, including a round trip through `PropertyListSerialization`.

iPhone to watch, `type = "state"`, `v = 1`:

| Key | Type | Meaning |
| --- | --- | --- |
| `stage` | String | `ready`, `framing`, `countdown`, `capturing`, `analyzing`, `result` |
| `countdown` | Int | Seconds left, 0 outside the countdown |
| `exercise` | String | Exercise name, such as "Squat" |
| `reps` | Int | Reps counted during the set; reps measured on the result |
| `caption` | String, optional | Latest live observation, such as "Rep 5 was faster than your first reps" |
| `haptic` | String | `none`, `rep` (.click), `observation` (.directionUp), `start` (.start), `end` (.stop) |
| `summary` | String, optional | Result line, such as "6 reps measured." plus the observation |
| `wristControls` | Bool | Offer Start set and Stop set (false for push-ups) |
| `handsFree` | Bool | The set starts and ends by itself |
| `demoInput` | Bool | Demo or recorded input, never a person filmed live |
| `sentAt` | Double | Seconds since 1970; the watch keeps the newest |

Watch to iPhone, `type = "command"`, `v = 1`, `command`: `startSet` or `stopSet`.

## How to test

On simulators (no workout needed):

1. In Xcode, run the `Plumb` scheme on an iPhone simulator that has a paired Apple Watch simulator, with launch arguments `-plumb-ui-demo -plumb-watch-demo`.
2. Run the `PlumbWatch` scheme on the paired watch simulator and keep it open.
3. On the iPhone: Start a set. The watch shows "Get in position" and DEMO INPUT. Tap Start set on the watch, check the countdown, the rep count rising, the result line, and that Stop set ends the set. Choose Push-up and check that the watch hides the buttons.

On devices:

1. Install from Xcode on an iPhone paired with an Apple Watch; Plumb installs on the watch with it (or from the Watch app).
2. Setup screen without Plumb open on the watch: the "open Plumb on your watch" line. Open it: the line changes and the camera screen shows "Apple Watch connected".
3. Do a squat set with the watch on: one tap per rep, a different tap when a rep is faster or shorter than the first ones (try speeding up after rep 4), start and stop from the wrist.
4. Push-ups in a plank: taps on each rep, no buttons on the watch.
5. Connect AirPods, then disconnect them: the setup line appears and disappears; the countdown and reps are heard in the AirPods.
6. Lower the wrist during a set and note whether taps still arrive (see below).

## Not done

- **No wrist-motion measurement.** The watch's accelerometer and gyroscope are not read; reps, tempo and range come only from the iPhone camera. Using wrist motion (for example a tempo check on push-ups) needs a measured rule and validation first.
- **Heart rate only, and only with Personalize with Health.** Since 13 October the watch runs a HealthKit workout session (functional strength training, `workout-processing` background mode) while the iPhone camera is open, if the person turned on Personalize with Health on the iPhone (`WatchState.measuresHeartRate`). It shows the heart rate and sends each reading to the iPhone (`WatchHeartRate` message), then discards the workout when the camera closes: the iPhone saves the session to Fitness itself when asked. No calories or ring tracking from the watch. Not yet run on a physical watch.
- **Screen and taps with the wrist down.** WatchKit plays haptics only while the watch app is active, and the iPhone sends live messages only while the watch app is reachable. `WKExtendedRuntimeSession` was not added: it needs a watch Info.plist background mode (`WKBackgroundModes`, physical therapy) that generated Info.plist settings do not cover, and its effect on reachability needs a device test. Until then, the latest state waits in the application context.
- **No AirPods head tracking** (`CMHeadphoneMotionManager`); AirPods only play the spoken count.
- **Not run on a physical watch yet.** The watch app compiles for the watch simulator and is embedded in the iPhone build; pairing, reachability and taps still need a device test.
- **Privacy pages.** Before a release that includes the watch app, add an Apple Watch paragraph to the public privacy policy (rep count, stage and observation text go to the person's own watch; no video or pose points). The App Privacy answer stays "not collected": nothing reaches the developer.
