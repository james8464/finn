<h1 align="center">Plumb</h1>

<p align="center"><strong>Find your line.</strong></p>

<p align="center">A private technique companion for deliberate movement.</p>

<p align="center">
  <a href="#the-experience">The experience</a> ·
  <a href="#inside-the-build">Inside the build</a> ·
  <a href="#where-it-stands">Where it stands</a> ·
  <a href="#get-started">Get started</a>
</p>

<p align="center">
  <img src="Design/Plumb%20Brand%20Theme%20preview.png" alt="Plumb's monochrome P mark and Find your line brand statement." width="100%">
</p>

---

## The experience

### Better form, one set at a time.

Set your iPhone where it can see your movement. Plumb counts reps and, when the view supports it, gives you **one specific observation** to try on the next set. Your video is processed on the phone and is not saved.

**Choose a movement.** Start a squat, push-up, lunge, stiff-leg deadlift, pull-up, or bar muscle-up set.

**Move naturally.** A live count, framing guidance, and a pose overlay help you stay with the set. Spoken counts and short observations are optional.

**Learn from the next set.** Review the measured count, a supported cue or an honest retake reason, then compare compatible sets in your local history.

---

## Inside the build

### An iPhone-first workout flow

The camera flow supports manual and hands-free sets. Form checks use exercise-specific rules and withhold posture advice when the view or tracking is too weak. A partial set can still keep its rep count.

### A home for your progress

Home brings recent sessions and the next workout together. Coach can summarize up to two relevant saved sets using their recorded counts and observations. Posture, Weights, Awards, and Plumb+ destinations are still placeholders.

### The Apple ecosystem, thoughtfully used

An Apple Watch companion mirrors set progress and supports wrist taps and start/stop messages. Optional Apple Health features, Siri Shortcuts, a last-set widget, and a Live Activity are implemented. Their real-device experience still needs validation.

[Explore the design →](Design/README.md) · [Read the build details →](docs/project-status.md)

---

## Where it stands

**Prototype · 15 October 2026**

Swift logic, simulator flows, and generated-video replays have automated coverage. A development build has launched on an iPhone 16 Pro Max and opened the live camera. Plumb has **not yet completed a real-person set test or independent expert review** of rep counts and coaching cues.

Plumb is a fitness aid. It does not diagnose injury risk, establish safe form, or replace a trainer. Demo and recorded input must be identified as such.

[Read the validation report →](docs/validation/automated-checks-2026-10-15.md) · [See the test protocol →](docs/validation/squat-v1-protocol.md)

---

## Get started

Open [Plumb/Plumb.xcodeproj](Plumb/Plumb.xcodeproj) in Xcode, select the **Plumb** scheme and a simulator or connected iPhone, then build and run. Device signing requires access to the MWM Apple Developer team and provisioning for the app's capabilities.

[Documentation →](docs/README.md) · [Product plan →](planning.md) · [Git workflow →](Plumb/GIT%20guide.md)

---

<p align="center">Built for the October 2026 Build Challenge by James, Klaus, Theophile, and Guilhem.</p>
