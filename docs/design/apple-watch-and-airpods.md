# Apple Watch companion and AirPods

_15 October 2026. Watch rhythm requires a physical paired Watch test before release._

The iPhone camera measures every rep and form observation. No accessory is required. AirPods or
other headphones can play the iPhone's spoken count and observations. The Apple Watch app now has
two jobs during a set: show one brief coaching message and, if chosen, give a pacing tap.

## Watch experience

- The Watch shows a small setup, countdown, live, or finished state. During capture, the coaching
  sentence is the main content. Its dark screen and lime accent match the iPhone. Native text and
  controls support larger type and VoiceOver.
- The iPhone writes coaching lines from accepted live events: faster reps, shorter range, repeated
  form faults, and measured rep milestones. It praises steady pace and range only when the latest
  side-on view supports a range comparison. Otherwise it uses neutral encouragement. The Watch
  never infers technique from motion on its own.
- Rhythm is off by default. The person chooses one gentle tap every 2, 3, 4, or 5 seconds
  (3 by default). It is a pacing guide, not a form judgement. The iPhone's Haptics Off setting
  silences it. Rhythm starts when camera capture begins and stops when capture ends.
- Turning rhythm on asks HealthKit for permission to share a temporary Watch workout. The
  permission explanation appears in Watch settings. The Watch requests no heart-rate read access
  for rhythm. It discards the temporary workout; the iPhone controls Fitness saving. If permission
  is refused, rhythm stays off and coaching messages still work.
- The Watch does not count reps, read heart rate, start or stop sets, save history, or offer a rest
  timer. There are no complications or notifications in this release.

## Connection and timing

`WatchMessages.swift` contains the property-list protocol shared by the iPhone and Watch targets.
Version 2 adds a set ID, the phone's resolved language and haptics preference, and a coaching line.
Version 1 messages still decode. The phone sends quiet updates every five seconds during capture.
The Watch uses a monotonic local clock, skips missed beats, and stops tapping after 15 seconds
without fresh phone state or when the phone disconnects. A new live state resumes from a new beat.
No video, pose points, or heart-rate history is transferred or stored on the Watch.

The interface and coaching text support English UK, English US, French, and Spanish. The iPhone
sends its resolved app language with the message, so Watch labels and phone-authored coaching use
the same language.

## Verification and release gate

Unit tests cover protocol compatibility, coaching evidence, set identity, heartbeat, permission
policy, master haptics, missed beats, and stale connections. Build both targets and exercise paired
iPhone and Watch simulators in all four languages, with larger text and VoiceOver. A physical paired
Watch must confirm wrist-down taps, permission denial, connection recovery, and battery behaviour
before rhythm is released. A simulator or successful build cannot establish wrist-down behavior.

Apple's [watchOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
and [workout session documentation](https://developer.apple.com/documentation/healthkit/running-workout-sessions)
inform the glanceable screen and background workout approach.
