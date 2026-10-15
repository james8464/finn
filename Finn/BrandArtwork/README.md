# Finn artwork

The production app icon is the editable [`AppIcon.icon`](../Finn/AppIcon.icon) document, shared by the iPhone and Watch targets. Open it in **Xcode 27’s Icon Composer**; the older standalone Composer cannot read its refraction settings.

Three original vector plates form a forward-leaning F. Small corner radii and a charcoal base give it a firmer training identity. Silver carries the silhouette; the short crossbar uses Finn’s exact `#FF2D92` pink. The Watch background stays above black so the circular boundary remains visible.

Each plate has its own Liquid Glass group. Inside highlights, 8% refraction strength, 4% depth and restrained translucency preserve crisp edges. SVGs contain filled paths only: the system supplies masking, highlights and shadows. Explicit monochrome fills preserve the silhouette in clear and tinted appearances.

- `AppIconPreview.png`: full-size native Composer export.
- `AppIconAppearances.png`: default, dark, clear light/dark, tinted light/dark and Watch exports. Tint colours are examples; the system honours the user’s chosen tint.
- `AppIconPreview.svg`: flat geometry reference, without system effects or a baked corner mask.
- `FinnMark.svg` and `FinnMark-Reversed.svg`: existing flat marks used separately from the app icon.

Reviewed the native previews at full size, iPhone Home Screen/Settings sizes and 40-point Watch size, including design generations 26 and 27. Build verification is recorded below.

The direction follows [Apple’s app-icon HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons) and [Icon Composer guidance](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer). [Logo-shape research](https://ira.lib.polyu.edu.hk/handle/10397/64985) informed the move away from capsules; associations depend on context and are not a usability guarantee.
