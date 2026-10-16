# Form checks v1: squat, push-up, lunge, stiff-leg deadlift

_15 October 2026._ Code: `Finn/Finn/Workout/FormChecks.swift` (checks and thresholds) and
`Finn/Finn/Workout/BodySegments.swift` (segments and angles every check reads).

## What each check reads

Every check reads the side the camera sees best, at the bottom of each rep: the median over the
deepest frame and up to two frames on each side of it. A joint needs a confidence of 0.5 (0.3 for the
push-up body line, see below). A check gives advice only when its fault shows on at least 2 reps and
on at least a quarter of the reps it could read. When it can read fewer than 2 reps, or fewer than
half the set, the result says which joint it could not see. On a view Vision 3D measures more than
30° from side-on, the checks stay silent (push-ups, which are counted from any view, say why).
Push-ups counted from the shoulders get no form check.

| Exercise | Check | Fault when | Live cue |
| --- | --- | --- | --- |
| Push-up | Hips sagging | hip more than 0.2 torso lengths below the shoulder-to-ankle line (to the knee if the ankle is unclear) | Lift your hips |
| Push-up | Hips piked | hip more than 0.2 torso lengths above that line | Lower your hips |
| Push-up | Depth | elbow above 120° at the bottom | Go lower |
| Squat | Chest dropping | torso leaning more than 45° beyond the shins | Chest up |
| Squat | Depth | thigh more than 30° above level (read only when the thigh looks at least 70% of its standing length: shorter, the view is not side-on) | Sit lower |
| Static lunge | Torso | torso more than 25° from upright | Stay tall |
| Static lunge | Front knee | front knee above 115° (front leg: the thigh leaning at least 45° from vertical) | Go lower |
| Stiff-leg deadlift | Knees | knees bent more than 30° | Straighter knees |
| Stiff-leg deadlift | Hinge | torso less than 50° from upright | Hips further back |

Nothing is checked that only a front view shows (knees caving in, elbows flaring).

## Threshold check on labeled videos

Data: the side-view videos of the Mendeley set "A Multi-View Raw Video Dataset of Seven Fitness
Exercises with Good/Bad Form Labels" (doi:10.17632/kgbb3yn47p.2, CC BY 4.0), squat and push-up only,
with the Vision 2D poses extracted on 12 October. The videos and poses stay outside this repository;
only these counts are kept here. The set does not say what makes a "bad" set bad, so a bad set the
checks miss may have a fault they do not look for.

Each set ran through the production analyzer (set window, evidence gate, rep count) and then the form
checks, with no 3D view check (the poses have no 3D estimate). "Read" is the number of measured sets
where the check could read enough reps.

| Check | Bad sets flagged | Good sets flagged |
| --- | --- | --- |
| Squat depth | 6 of 14 read | 0 of 15 read |
| Squat chest dropping | 0 of 13 read | 1 of 13 read |
| Push-up hips sagging | 3 of 10 read | 1 of 10 read |
| Push-up hips piked | 1 of 10 read | 0 of 10 read |
| Push-up depth | 4 of 14 read | 1 of 15 read |
| Any squat check | 6 of 23 measured | 1 of 21 measured |
| Any push-up check | 6 of 23 measured | 2 of 23 measured |

How the limits were picked, on the same data (so these numbers are not a held-out test):

- Squat depth at 20° flagged 8 of 15 good sets; at 30° with the quarter-of-reps rule, none.
- The chest-drop check never caught a bad squat here: the dataset's bad squats do not show it. Its
  45° limit is set high so that it rarely accuses a good set; it needs real-person validation.
- Push-up hips: Vision gives a body lying level low hip confidence (the near hip reached 0.5 in 13% of
  frames, 0.3 in 62%), so the body line accepts 0.3 and uses the knee when the ankle is unclear. At
  0.5 it could read 2 sets of each label.
- Push-up depth at 110° accused 4 of 15 good sets; 120° accuses 1.

Lunge and stiff-leg deadlift thresholds come from common coaching cues only: the labeled set has
neither exercise. They are covered by synthetic tests, not by real people.

## Rep counts unchanged

The checks do not touch the rep count. Théophile's six sets of 14 October (local poses, not in this
repository) give the same results before and after this change, final count and live count alike:
sets 2 and 5 count 10 of 10, set 4 counts 6 of 7, and sets 1, 3 and 6 are refused for wrist movement
(35 to 49% of the frame), as on `main`.

## Back rounding from Vision 3D: tried, not shipped

Vision 3D body pose (`VNDetectHumanBodyPose3DRequest`, already run for the camera-angle check) gives
a point mid-spine, so the angle at it between the center of the shoulders and the root could stand
for a rounding back on a hinge. The labeled set has no stiff-leg deadlift; its closest hinge is the
"back" exercise, a bent-over row. On its 33 side-view sets with enough hinged frames (17 good,
16 bad), read every third frame on a Mac:

- The angle mostly follows the torso lean: about 173° standing, 147° at 50° of lean, for good and bad
  sets alike. Vision's 3D model seems to bend its spine with the lean whatever the back does.
- In the hinged frames (torso 45 to 80° from upright), the median angle is 145.5 to 156.4° on good
  sets and 146.3 to 153.7° on bad sets: no separation.
- Only the lowest tenth of readings hints at a difference: 4 bad sets fall below 144°, no good set,
  with a margin under 1°.

That is not reliable enough to tell someone their back rounds, so Finn gives no back advice. The
measurement is easy to add to `PoseFrameAnalyzer` if real deadlift sets labeled by a coach show a
clearer gap.

## Still to do

- Try the checks and the live cues on a physical iPhone, with a coach watching, for each exercise.
- Collect labeled lunge and stiff-leg deadlift sets.
- Hold out new labeled squat and push-up sets: these limits were tuned on the only labeled set.
