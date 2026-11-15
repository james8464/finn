# Finn — agent guide

Finn is a sport and fitness coach that lives on your iPhone (with Apple Watch). It counts strength reps through the camera and gives at most two evidence-backed observations per set. The goal is to help the user improve their posture, like a real coach, by giving accurate, real-time advice. Coach is a chat with Finn on the on-device Apple Intelligence model. Finn Coach+ is a subscription; without it, one free workout every 14 days. SwiftUI, iOS 27, Xcode 27.

## Vision
These are goals that guide the work, never claims to make in the app, the store listing or the Coach's answers.
- Finn is more than a workout tracker: it is a coach, and it builds a relationship with the user.
- When the user opens Finn, they see clearly what they need to do. Finn is as clear as a real coach, so the user no longer needs one: it says what is good and what is not, creates workouts, makes sure the user follows them, gives recommendations and answers every question.
- The user gets all the information they want easily, with real data about their progress and workouts.
- The Apple Watch makes the experience as immersive as possible: Finn stays simple to use and gives the advice the user needs right on the wrist.
- The user should feel they are getting better, truly supported, and that the app really helps them improve.
- The app is smooth and clean, with Liquid Glass, and never generic or AI-looking. Avoid every sign of AI slop.

## What is true
Code and tests first, then [README.md](README.md) (current status: update it when user-visible behaviour changes), then [the brand system](Design/README.md) for how screens look. Dated documents (`docs/validation/*-2026-10-*`, `docs/maintenance/`, `docs/architecture/`, `planning.md`) are history, not instructions.

## Product rules (never break)
- Workout video stays on the phone and is never saved. Ask for camera and Health access in context.
- Counts and observations come from measured, versioned rules ([exercise rules](docs/validation/exercise-rules-v1.md), [form checks](docs/validation/form-checks-v1.md)). Weak evidence gives a retake reason, not advice.
- Never claim Finn diagnoses injury, proves safe form or replaces a trainer. Coach gives no medical advice and never invents sets or numbers.
- Demo, synthetic and sample data is always labelled and never presented as a live camera result.

## Interface
- Follow [the brand system](Design/README.md) for colour, type and voice. Read it before changing how a screen looks; if a screen and the brand system disagree, the brand system wins.
- Dark-only, whatever the system appearance. Do not add or test a light mode.
- Brand pink is exact sRGB `#FF2D92`. At 100% it is for lines (2 pt max) and small marks (8 pt max on the shorter side) only. Any larger pink surface, button included, is 75% opacity or less; the one exception is the solid fallback for Reduce Transparency and Increase Contrast in the brand system. Do not add a new pink.
- Native navigation and controls, and system text styles.
- Every screen works with Reduce Transparency and Increase Contrast.
- Apple design questions: the Apple design skill or [the local HIG index](docs/design/apple-hig-agent-reference.md), then Apple's own page.

## Strings
Every user-facing string goes in the String Catalogs (`Finn/Finn`, `Finn/FinnWatch`, `Finn/FinnWidgets` `Localizable.xcstrings`) in English (plain `en`, no regional variant) and French, and no other language. Spanish, en-GB and en-US entries still in the catalogs are leftovers: never add to them. The iPhone catalog has ~1,300 entries: search it, don't read it whole.

## Never rename
UserDefaults keys, Codable fields, localization keys, accessibility identifiers, coach ids, StoreKit product IDs. `plumb` mentions in code are migration from the app's former name (old settings, history folder, URL scheme, Watch keys): keep them.

## Tests
Test in English and French only, at the default text size. Never write or run tests at larger text sizes or in Spanish, en-GB or en-US. UI tests that still do are leftovers: don't copy them.

## Commands, fastest first
- Logic tests, no simulator: `zsh tools/test_backend.sh`. About 20 seconds: 260 tests, rebuilt from scratch each run. CI runs it in the `replay` job.
- One test class on a simulator, one run at a time (about 2 min; leave the full UI suite, ~45 min, to CI, which runs it on every pull request):
  ```bash
  xcodebuild test -quiet -project Finn/Finn.xcodeproj -scheme Finn -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:FinnUITests/DashboardUITests CODE_SIGNING_ALLOWED=NO
  ```
- Check a screen: build, install, open the screen with launch arguments, wait about 10 seconds (a black screenshot means the app is still starting), then take a screenshot.
  ```bash
  xcodebuild build -quiet -project Finn/Finn.xcodeproj -scheme Finn -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
  xcrun simctl bootstatus 'iPhone 18 Pro' -b
  xcrun simctl install 'iPhone 18 Pro' .build/DerivedData/Build/Products/Debug-iphonesimulator/Finn.app
  xcrun simctl launch --terminate-running-process 'iPhone 18 Pro' ai.mwm.build.challenge.team.08 -finn-ui-demo -finn-open coach -AppleLanguages '(fr)' -AppleLocale fr_FR
  xcrun simctl io 'iPhone 18 Pro' screenshot /tmp/finn-coach-fr.png
  ```
  Leave out `-AppleLanguages` and `-AppleLocale` for English. `-finn-open` takes `coach`, `progress`, `workout`, `history`, `options`, `privacy`, `awards`, `health` or `camera-primer`. Other launch arguments: `-finn-ui-demo` (labelled sample data, throwaway storage), `-finn-ui-onboarding`, `-finn-ui-paywall`, `-finn-ui-demo-purchase` (stands for a purchase).
- Style: [code style](docs/development/code-style.md). Formatting settings are in `.swiftformat`, but SwiftFormat isn't installed: don't reformat code you didn't change.

## Done means
1. The simulator tests for what you touched pass.
2. Changed screens checked in the simulator in English and French (see "Check a screen").
3. New strings have English and French.
4. README updated if user-visible behaviour changed.
5. Work on a branch from the first edit. Nobody pushes to `main`: changes reach it only through a pull request.
