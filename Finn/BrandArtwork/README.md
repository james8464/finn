# Finn artwork

The production app icon is the editable [`AppIcon.icon`](../Finn/AppIcon.icon) document, shared by the iPhone and Watch targets. Open it in **Xcode 27’s Icon Composer**; the older standalone Composer cannot read its refraction settings.

Three original vector plates form a forward-leaning F. Small corner radii and a charcoal base give it a firmer training identity. Silver carries the silhouette; the short crossbar uses Finn’s exact `#FF2D92` pink. The Watch background stays above black so the circular boundary remains visible.

Each plate has its own Liquid Glass group. Inside highlights, 8% refraction strength, 4% depth and restrained translucency preserve crisp edges. SVGs contain filled paths only: the system supplies masking, highlights and shadows. Explicit monochrome fills preserve the silhouette in clear and tinted appearances.

- `AppIconPreview.png`: full-size native Composer export.
- `AppIconAppearances.png`: default, dark, clear light/dark, tinted light/dark and Watch exports. Tint colours are examples; the system honours the user’s chosen tint.
- `AppIconPreview.svg`: flat geometry reference, without system effects or a baked corner mask.
- `FinnMark.svg` and `FinnMark-Reversed.svg`: flat, transparent versions of the same three plates for app branding on light and dark surfaces.

Reviewed the native previews at full size, iPhone Home Screen/Settings sizes and 40-point Watch size, including design generations 26 and 27. The final Xcode 27 simulator build passed for iPhone, the embedded Watch app and widgets; both app bundles reference the compiled `AppIcon`. No icon compilation warnings were reported. The initial full build emitted only the widget target’s existing App Intents metadata-extraction notice.

The direction follows [Apple’s app-icon HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons) and [Icon Composer guidance](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer). [Logo-shape research](https://ira.lib.polyu.edu.hk/handle/10397/64985) informed the move away from capsules; associations depend on context and are not a usability guarantee.

The unused character study was removed from the active artwork folder. Git history preserves that exploration.

## Opening motion

The F draws itself: its stem rises (0–0.34 s), the upper arm extends (0.26–0.58 s), then the pink bar extends (0.38–0.68 s). Rounded ends retain their shape as each plate grows. Quintic interpolation gives each movement zero velocity and acceleration at both ends. The finished geometry matches the icon exactly, at roughly 80 × 87 points.

James requested a one-second presentation: draw, hold until 0.8 seconds, then fade over 0.2 seconds. `FinnStartupView` loads saved sessions and badges concurrently, off the main thread, and mounts navigation underneath. If storage takes longer, the settled mark stays until content is ready. Health and network requests do not hold startup. Returning from the background preserves navigation and does not repeat the animation. Reduce Motion uses the finished mark and fade. VoiceOver receives one loading label; covered content is inaccessible until revealed.

`FinnLogoMotionFrame` renders vectors at the display’s animation cadence. `LaunchMotion.mp4` is a 120-frame, one-second export from that same renderer; `LaunchMotion.png` shows selected frames. These are review artifacts, not bundled playback assets.

The app opts into [higher ProMotion refresh rates](https://developer.apple.com/documentation/bundleresources/information-property-list/cadisableminimumframedurationonphone); iOS still chooses the actual cadence for the device and power state.

The system launch screen is plain black. Motion runs in SwiftUI after launch; see Apple’s [launching](https://developer.apple.com/design/human-interface-guidelines/launching), [loading](https://developer.apple.com/design/human-interface-guidelines/loading) and [motion](https://developer.apple.com/design/human-interface-guidelines/motion) guidance. Launch a Debug build with `-finn-launch-preview` for a Replay button using the production timing; add `-finn-launch-reduce-motion` for its static variant. Native navigation mounts without an insertion animation before the logo fades away.

Release verification caught blank tab content caused by a debug-only header inside an unconditional `safeAreaInset`. Keep the entire modifier inside `#if DEBUG`. The corrected Release build was installed and checked across two cold launches on an iPhone 16 Pro Max, with saved sessions and badges intact. Startup tests cover prepared history, corrupt-file recovery, badge restoration and navigation after launch/backgrounding.
