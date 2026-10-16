import SwiftUI

/// A deterministic vector frame, shared by live playback and artwork exports.
struct FinnLogoMotionFrame: View {
    let elapsed: TimeInterval
    var reducesMotion = false

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let stem = progress(start: 0, duration: 0.34)
            let crown = progress(start: 0.26, duration: 0.32)
            let middle = progress(start: 0.38, duration: 0.30)

            // The arms grow from behind the spine; each rounded end keeps its shape.
            context.opacity = crown
            context.fill(
                FinnLogoPlate.crown.path(in: rect, extension: crown),
                with: .color(Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255))
            )
            context.opacity = middle
            context.fill(
                FinnLogoPlate.middle.path(in: rect, extension: middle),
                with: .color(Color(red: 1, green: 45 / 255, blue: 146 / 255))
            )
            context.opacity = progress(start: 0, duration: 0.10)
            context.fill(
                FinnLogoPlate.stem.path(in: rect, extension: stem),
                with: .color(Color(red: 198 / 255, green: 204 / 255, blue: 213 / 255))
            )
        }
        .accessibilityHidden(true)
    }

    private func progress(start: TimeInterval, duration: TimeInterval) -> Double {
        guard !reducesMotion else {
            return 1
        }
        let t = min(1, max(0, (elapsed - start) / duration))
        // Quintic interpolation starts and ends with zero velocity and acceleration.
        return t * t * t * (t * (6 * t - 15) + 10)
    }
}
