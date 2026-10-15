# Welcome, demo and coach choice

Implemented on `design/visuals-tabs`, 15 October 2026, after merging `origin/main` through `f0aed61` (Guilhem's Coach, badges, onboarding, form-check and detection updates).

The supplied sketches define the sequence: Plumb / Find your line, an app demo, Choose your coach, then Home. The new screens reuse the Home photograph, white typography and lime accent. The generated photograph is inside a native SwiftUI camera card; headings, counters, buttons, plans and advice are real accessible views.

- Welcome → camera demo → example advice → offer choice → Home.
- Skip goes directly to the offer choice. Back preserves the chosen offer. Completion persists across launches; Options can replay the full welcome without resetting existing personalization preferences.
- Free: advice and workout tracking. Plumb+: a coach you can talk to, Apple Watch and AirPods. Monthly €9.99; annual €99 (€8.25/month), about 17.4% below €119.88 for twelve monthly payments, displayed as 17%.
- **Offer preview only:** no charge, subscription, trial, auto-renewal, entitlement or feature gate. The footer says “Plan preview · no payment today.” `coachPlanChoice` is a local design preference. A real checkout requires App Store Connect products, StoreKit verification/restoration and a separate entitlement policy. The older freemium proposal is not the pricing authority for this requested design.
- Home's solid lime **Try Plumb** card intentionally differs from the glass metric cards. Its main action opens the real Workout setup immediately. A separate “Watch the demo” action opens the two demo moments, supports close and replay, then opens Workout setup through “Try my first set.” Camera permission still belongs to Start a set.
- Demo presentation has no workout model or store. It cannot affect measured history, badges, Health, widgets or Watch. The athlete, six reps and advice are illustrative, not analysis of the generated photograph.
- Scrollable pages, fixed primary actions, scaled headings, accessibility labels and selection traits support large text and VoiceOver. Offer columns stack at accessibility sizes. Transitions respect Reduce Motion.

## Asset provenance

Generated using the built-in `image_gen` tool. Project asset: `Plumb/Plumb/Assets.xcassets/DemoAthlete.imageset/demo-athlete.png`.

Prompt:

> Use case: photorealistic-natural. Asset type: background photograph inside a fictional iPhone fitness app's onboarding demonstration. Primary request: a full-body adult athletic man performing a bodyweight squat, seen exactly from the side, facing right, in a quiet premium gym. He wears a plain charcoal t-shirt, black shorts, off-white sneakers. Warm amber sidelight, dark brown concrete wall, rubber gym floor, understated cinematic editorial photography. Portrait 2:3 composition, the whole man including head and feet comfortably inside the central 70 percent with empty margins above and below for interface overlays. Bent knees, hips back, arms out forward at shoulder height. Realistic anatomy, natural skin, no equipment blocking him. No text, no lettering, no interface, no logos, no watermarks, no joint overlays. This is illustrative synthetic imagery for a visibly labelled demonstration, not evidence of exercise analysis.

## Validation

Validated on 15 October 2026 with Xcode 27.0 / iOS 27.0, iPhone 18 Pro simulator: Debug build succeeded; 8 profile tests, 3 existing dashboard tests, 4 welcome-flow tests and 1 capture-tour test passed (16 distinct tests). The final layout pass reran all 4 welcome-flow tests and the capture tour. Screenshots were inspected for welcome, capture demo, advice, offers and Home; both prices and the complete example advice fit the standard-size screen. Physical-device and actual billing checks are outside this preview.

`WelcomeFlowUITests` covers the complete free path, backwards navigation, persisted completion, demo close/replay, return to Workout, unchanged empty history, monthly/annual selection and large text. `OnboardingTourUITests` captures the revised tour when `TEST_RUNNER_PLUMB_CAPTURE_DIR` is set. Existing dashboard tests cover the merged destinations and workout flow.

For a fresh development preview, launch with `-plumb-ui-demo -plumb-ui-onboarding`. A unique `-plumb-ui-preferences-suite <name>` makes preferences persist across debug launches for lifecycle tests. Normal demo launches retain their isolated preferences and skip onboarding, so existing camera tests continue to reach their targets.
