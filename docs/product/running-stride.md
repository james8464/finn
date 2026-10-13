# Running stride: what Plumb could measure

_13 October 2026. A feasibility note for Théophile's question ("would it work for running, for the stride?"). Nothing here is built._

## Short answer

Yes, in two different ways, and they are better together than either alone:

1. **Apple Watch, any run.** watchOS already records running form during a run with the Workout app: cadence (from steps), stride length, vertical oscillation, ground contact time, running power and speed. They are stored in HealthKit (`HKQuantityType` `runningStrideLength`, `runningVerticalOscillation`, `runningGroundContactTime`, `runningPower`, `runningSpeed`, `stepCount`). Plumb could read them after a run, with the person's Health permission, and compare a run with their own previous runs, the same way it compares sets. No new sensor work, works outdoors.
2. **iPhone camera, treadmill only.** A phone on a tripod beside a treadmill sees the runner from the side for minutes. With the same Vision 2D pose as today, Plumb can measure:
   - **Cadence** (steps per minute) from the alternating ankle or knee cycle. Robust: it averages many steps.
   - **Vertical bounce** of the hip, relative to leg length, the same normalization as the squat.
   - **Where the foot lands** relative to the hip at first contact (overstriding), as a share of leg length. This one is harder, see below.
   - **Trunk lean** from shoulder and hip.

   Outdoors, a fixed phone sees a runner for under a second: not enough.

## What is hard

- **Frame rate.** Plumb analyzes 15 frames per second. A foot moves about 20 cm between two such frames at running speed, so the moment of first contact is uncertain by about one frame. Cadence is fine; foot-landing position needs 60 fps capture for running, with Vision on every second or third frame, and a check of heat (the capture pipeline now lowers its rate under system pressure).
- **Occlusion.** Treadmill rails and the far leg hide the ankle part of each stride. The evidence gate would need a running rubric: coverage per stride, not per frame.
- **Motion blur** indoors at running speed lowers joint confidence on the feet.
- **Validation.** "Overstriding" thresholds vary between sources and between runners. As for the other exercises, Plumb should compare a runner with their own runs first, and only show a universal threshold after a specialist reviews it.

## Suggested order, after the App Store submission

1. Read the Watch's running metrics from HealthKit after a run and show trends (one or two days; needs the HealthKit entitlement, a usage string, and a privacy policy update).
2. Treadmill cadence and bounce from the camera, as a new definition with a cyclic signal instead of reps (about three days with tests on filmed treadmill runs).
3. Foot landing at 60 fps, only after 2 is validated on real runners.
