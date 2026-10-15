# Home dashboard · 14 October 2026

Implemented in `Plumb/Plumb/Home/DashboardView.swift`, integrated with the existing session model in `ContentView.swift`. The supplied `plumbhome2.png` is the layout reference. The existing `PressableStyle`, spring animation, exercise illustrations and workout flow are reused. Reduce Motion disables button scaling and tab transitions; Reduce Transparency uses opaque card surfaces. Accessibility text sizes use one column for widgets. The scroll area reserves space for the bottom tabs.

Navigation:

The revised tab bar follows the second supplied reference: Home, Posture, Coach, Workout, with a running figure for Posture and a person with sparkles for Coach. Its capsule is 72 points tall at standard text size, with 12-point horizontal margins. Removing the previous 8-point bottom padding lowers the bar without entering the home-indicator safe area. The active capsule uses native SwiftUI Liquid Glass over a translucent material shell; labels stay above the glass to remain crisp. A shared `glassEffectID` inside `GlassEffectContainer` moves the selected capsule with a 0.28-second spring; tab content switches immediately. Reduce Motion disables the selection animation and Reduce Transparency replaces glass with opaque surfaces.

The interaction follows [Emil Design Engineering](https://www.ui-skills.com/skills/emilkowalski/emil-design-eng)'s guidance on short, interruptible transitions and immediate press feedback, adapted to [Apple's native Liquid Glass APIs](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

| Control | Destination |
| --- | --- |
| Home | Dashboard |
| Coach / Posture tabs | Named “Not made yet” page |
| Workout | Existing exercise selection, animated figure and camera setup |
| Last workout | Latest saved session, or an empty state |
| Posture / Weights / Awards | Named “Not made yet” page |
| Sessions | Existing local History |
| Account figure | Account settings with Options, History and Privacy links |
| Plumb+ | “Not made yet” page |

Duration uses `FitnessWorkout.make(from:)`, including its existing rest accounting. No posture score or load is invented. Debug launch argument `-plumb-dashboard-preview` displays the reference values with a visible “DESIGN PREVIEW · SAMPLE DATA” label; it does not write sample history. Account sign-in, subscriptions, scoring and load tracking remain unimplemented.

The project-bound decorative asset is `Plumb/Plumb/Assets.xcassets/HomeBackdrop.imageset/home-backdrop.png`. It was created with the built-in imagegen tool from the supplied reference, then copied into the asset catalog. The photograph is decorative artwork, not footage from a measured workout. Generation prompt:

> Use case: precise-object-edit. Asset type: portrait background image for native fitness app. Edit target: provided screenshot. Remove ALL interface overlays, text, cards, numbers, charts, status bar, tab bar, icons and duplicated lower promotional inset. Reconstruct only the continuous background photograph: an athletic adult man seen from behind, dark curly hair near the upper center, black sleeveless training shirt, standing in a dark gym, amber golden rim lighting from upper right, hazy diagonal sunbeams, black and warm brown palette. Preserve the original cinematic composition and very dark exposure. Single full-bleed portrait photograph, no text, no UI, no border. This is decorative background artwork.

`DashboardUITests` covers the tabs, every widget, settings links, large-text navigation, and a completed demo set opening from Last workout. Existing workout UI tests now enter the Workout tab before exercising their original flows.

Validation: the Debug iPhone simulator build succeeded. All three dashboard UI tests and the existing exercise-picker UI test passed (four tests, zero failures) on the iPhone 18 Pro simulator with iOS 27. Physical-device verification remains outstanding.

After the Liquid Glass tab-bar revision, the full dashboard navigation test and the large-text navigation test passed again (two tests, zero failures).
