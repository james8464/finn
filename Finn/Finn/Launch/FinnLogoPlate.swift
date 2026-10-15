import SwiftUI

/// original filled paths from AppIcon.icon, on the same 1024-point canvas
enum FinnLogoPlate: Shape {
    case crown, middle, stem

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch self {
        case .crown:
            path.move(to: CGPoint(x: 413, y: 225))
            path.addLine(to: CGPoint(x: 767, y: 225))
            path.addQuadCurve(to: CGPoint(x: 779, y: 241), control: CGPoint(x: 783, y: 225))
            path.addLine(to: CGPoint(x: 760, y: 329))
            path.addQuadCurve(to: CGPoint(x: 741, y: 345), control: CGPoint(x: 757, y: 345))
            path.addLine(to: CGPoint(x: 387, y: 345))
            path.addQuadCurve(to: CGPoint(x: 375, y: 329), control: CGPoint(x: 371, y: 345))
            path.addLine(to: CGPoint(x: 394, y: 243))
            path.addQuadCurve(to: CGPoint(x: 413, y: 225), control: CGPoint(x: 398, y: 225))
        case .middle:
            path.move(to: CGPoint(x: 366, y: 455))
            path.addLine(to: CGPoint(x: 648, y: 455))
            path.addQuadCurve(to: CGPoint(x: 660, y: 471), control: CGPoint(x: 664, y: 455))
            path.addLine(to: CGPoint(x: 641, y: 559))
            path.addQuadCurve(to: CGPoint(x: 622, y: 575), control: CGPoint(x: 638, y: 575))
            path.addLine(to: CGPoint(x: 340, y: 575))
            path.addQuadCurve(to: CGPoint(x: 328, y: 559), control: CGPoint(x: 324, y: 575))
            path.addLine(to: CGPoint(x: 347, y: 473))
            path.addQuadCurve(to: CGPoint(x: 366, y: 455), control: CGPoint(x: 351, y: 455))
        case .stem:
            path.move(to: CGPoint(x: 409, y: 225))
            path.addLine(to: CGPoint(x: 521, y: 225))
            path.addQuadCurve(to: CGPoint(x: 533, y: 241), control: CGPoint(x: 537, y: 225))
            path.addLine(to: CGPoint(x: 416, y: 779))
            path.addQuadCurve(to: CGPoint(x: 397, y: 795), control: CGPoint(x: 413, y: 795))
            path.addLine(to: CGPoint(x: 281, y: 795))
            path.addQuadCurve(to: CGPoint(x: 269, y: 779), control: CGPoint(x: 265, y: 795))
            path.addLine(to: CGPoint(x: 386, y: 245))
            path.addQuadCurve(to: CGPoint(x: 409, y: 225), control: CGPoint(x: 390, y: 225))
        }
        path.closeSubpath()
        let scale = min(rect.width, rect.height) / 1024
        return path.applying(CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: rect.midX - 512 * scale,
                                             y: rect.midY - 512 * scale)))
    }
}
