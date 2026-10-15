import SwiftUI
import Testing
import UIKit
@testable import Finn

struct PaletteAccessibilityTests {
    @MainActor @Test
    func brandPinkKeepsTextContrastOnBothSurfaces() {
        let pink = UIColor(DashboardStyle.accent)
        #expect(contrast(.black, pink) >= 4.5)
        // The lightest tone in the stable dark tab selection and Home surfaces.
        #expect(contrast(pink, UIColor(white: 0.12, alpha: 1)) >= 4.5)
        #expect(contrast(UIColor(DashboardStyle.secondary), UIColor(white: 0.12, alpha: 1)) >= 4.5)
        #expect(contrast(UIColor(HomeStyle.supportingText), UIColor(HomeStyle.card)) >= 4.5)
    }

    @MainActor private func contrast(_ foreground: UIColor, _ background: UIColor) -> Double {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        func components(_ color: UIColor) -> (Double, Double, Double, Double) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.resolvedColor(with: dark).getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }
        let (r, g, b, a) = components(foreground)
        let (br, bg, bb, _) = components(background)
        func luminance(_ rgb: [Double]) -> Double {
            let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return zip(linear, [0.2126, 0.7152, 0.0722]).map(*).reduce(0, +)
        }
        let front = luminance([r * a + br * (1 - a), g * a + bg * (1 - a), b * a + bb * (1 - a)])
        let back = luminance([br, bg, bb])
        return (max(front, back) + 0.05) / (min(front, back) + 0.05)
    }
}
