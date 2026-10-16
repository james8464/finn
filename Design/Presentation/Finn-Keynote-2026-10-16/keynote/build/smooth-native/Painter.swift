import SwiftUI
enum SkeletonPainter {
    static func draw(_ geometry: SkeletonGeometry, in context: inout GraphicsContext, size canvas: CGSize,
                     clear: Color, labelText: Color, lineWidth: CGFloat = 3) {
        let weak = Color.orange
        let ignored = Color.gray.opacity(0.55)
        for bone in geometry.bystanderBones {
            var path = Path()
            path.move(to: bone.from)
            path.addLine(to: bone.to)
            context.stroke(path, with: .color(ignored), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        for point in geometry.bystanderJoints {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                         with: .color(ignored))
        }
        for bone in geometry.bones {
            var path = Path()
            path.move(to: bone.from)
            path.addLine(to: bone.to)
            context.stroke(path, with: .color((bone.reliable ? clear : weak).opacity(bone.reliable ? 0.9 : 0.7)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                              dash: bone.reliable ? [] : [6, 5]))
        }
        let radius = lineWidth + 2
        for joint in geometry.joints {
            let dot = CGRect(x: joint.point.x - radius, y: joint.point.y - radius, width: 2 * radius, height: 2 * radius)
            context.fill(Path(ellipseIn: dot), with: .color(joint.reliable ? clear : weak))
            context.stroke(Path(ellipseIn: dot), with: .color(.black.opacity(0.5)), lineWidth: 1)
        }
        if let angle = geometry.angle {
            let text = Text(angle.text)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(angle.reliable ? labelText : Color.white)
            let resolved = context.resolve(text)
            let size = resolved.measure(in: CGSize(width: 200, height: 40))
            // right of the joint, or left of it near the right edge, and always inside the canvas
            let offset = 14 + size.width / 2
            let fitsRight = angle.vertex.x + offset + size.width / 2 + 8 <= canvas.width
            let halfBadge = size.width / 2 + 8
            let wanted = angle.vertex.x + (fitsRight ? offset : -offset)
            let center = CGPoint(x: min(max(wanted, halfBadge), max(halfBadge, canvas.width - halfBadge)),
                                 y: angle.vertex.y)
            let badge = CGRect(x: center.x - size.width / 2 - 8, y: center.y - size.height / 2 - 4,
                               width: size.width + 16, height: size.height + 8)
            context.fill(Path(roundedRect: badge, cornerRadius: badge.height / 2),
                         with: .color(angle.reliable ? clear : weak))
            context.draw(resolved, at: center)
        }
    }
}

