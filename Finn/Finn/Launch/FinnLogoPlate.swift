import SwiftUI

/// original filled paths from AppIcon.icon, on the same 1024-point canvas
enum FinnLogoPlate: Shape {
    case crown
    case middle
    case stem

    func path(in rect: CGRect) -> Path {
        path(in: rect, extension: 1)
    }

    /// Extend each plate from its joint, preserving the original cap radii and final silhouette.
    func path(in rect: CGRect, extension progress: CGFloat) -> Path {
        let remaining = 1 - min(1, max(0, progress))
        var path = Path()
        switch self {
        case .crown:
            path.move(to: CGPoint(x: 413, y: 225))
            path.addLine(to: CGPoint(x: 767 - 292 * remaining, y: 225))
            path.addQuadCurve(
                to: CGPoint(x: 779 - 292 * remaining, y: 241),
                control: CGPoint(x: 783 - 292 * remaining, y: 225)
            )
            path.addLine(to: CGPoint(x: 760 - 292 * remaining, y: 329))
            path.addQuadCurve(
                to: CGPoint(x: 741 - 292 * remaining, y: 345),
                control: CGPoint(x: 757 - 292 * remaining, y: 345)
            )
            path.addLine(to: CGPoint(x: 387, y: 345))
            path.addQuadCurve(to: CGPoint(x: 375, y: 329), control: CGPoint(x: 371, y: 345))
            path.addLine(to: CGPoint(x: 394, y: 243))
            path.addQuadCurve(to: CGPoint(x: 413, y: 225), control: CGPoint(x: 398, y: 225))
        case .middle:
            path.move(to: CGPoint(x: 366, y: 455))
            path.addLine(to: CGPoint(x: 648 - 208 * remaining, y: 455))
            path.addQuadCurve(
                to: CGPoint(x: 660 - 208 * remaining, y: 471),
                control: CGPoint(x: 664 - 208 * remaining, y: 455)
            )
            path.addLine(to: CGPoint(x: 641 - 208 * remaining, y: 559))
            path.addQuadCurve(
                to: CGPoint(x: 622 - 208 * remaining, y: 575),
                control: CGPoint(x: 638 - 208 * remaining, y: 575)
            )
            path.addLine(to: CGPoint(x: 340, y: 575))
            path.addQuadCurve(to: CGPoint(x: 328, y: 559), control: CGPoint(x: 324, y: 575))
            path.addLine(to: CGPoint(x: 347, y: 473))
            path.addQuadCurve(to: CGPoint(x: 366, y: 455), control: CGPoint(x: 351, y: 455))
        case .stem:
            path.move(to: CGPoint(x: 409 - 105 * remaining, y: 225 + 484 * remaining))
            path.addLine(to: CGPoint(x: 521 - 105 * remaining, y: 225 + 484 * remaining))
            path.addQuadCurve(
                to: CGPoint(x: 533 - 105 * remaining, y: 241 + 484 * remaining),
                control: CGPoint(x: 537 - 105 * remaining, y: 225 + 484 * remaining)
            )
            path.addLine(to: CGPoint(x: 416, y: 779))
            path.addQuadCurve(to: CGPoint(x: 397, y: 795), control: CGPoint(x: 413, y: 795))
            path.addLine(to: CGPoint(x: 281, y: 795))
            path.addQuadCurve(to: CGPoint(x: 269, y: 779), control: CGPoint(x: 265, y: 795))
            path.addLine(to: CGPoint(x: 386 - 105 * remaining, y: 245 + 484 * remaining))
            path.addQuadCurve(
                to: CGPoint(x: 409 - 105 * remaining, y: 225 + 484 * remaining),
                control: CGPoint(x: 390 - 105 * remaining, y: 225 + 484 * remaining)
            )
        }
        path.closeSubpath()
        let scale = min(rect.width, rect.height) / 1024
        return path.applying(CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(
                translationX: rect.midX - 512 * scale,
                y: rect.midY - 512 * scale
            )))
    }
}
