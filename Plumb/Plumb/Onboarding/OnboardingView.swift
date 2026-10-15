import SwiftUI

/// The placement drawing: an iPhone standing at hip height on the left, the person a few steps away
/// on the right, a dotted line between them at hip height, and the camera's field of view.
struct PlacementScene: View {
    let kind: ExerciseKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 1 : 0.55 + 0.45 * (1 + sin(2 * .pi * seconds / 1.8)) / 2
            ZStack(alignment: .bottom) {
                Canvas { context, size in
                    draw(in: &context, size: size, pulse: pulse)
                }
                HStack(alignment: .bottom) {
                    Spacer()
                    // The figure's own floor (about 16 pt above its frame) sits on the scene's floor.
                    ExerciseFigureView(kind: kind)
                        .frame(width: 150, height: 160)
                        .padding(.trailing, 12)
                        .padding(.bottom, 18)
                }
            }
            .padding(14)
            .background(
                LinearGradient(colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .environment(\.colorScheme, .dark)
        }
        .accessibilityElement()
        .accessibilityLabel("Drawing: the iPhone stands at hip height a few steps from the person, filming from the side.")
        .accessibilityAddTraits(.isImage)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, pulse: Double) {
        let floorY = size.height - 34
        let white = Color.white

        // The floor.
        var floor = Path()
        floor.move(to: CGPoint(x: 10, y: floorY))
        floor.addLine(to: CGPoint(x: size.width - 10, y: floorY))
        context.stroke(floor, with: .color(white.opacity(0.18)), lineWidth: 1)

        // The iPhone, standing upright, its height about a hip.
        let phoneHeight: CGFloat = 54
        let phone = CGRect(x: 26, y: floorY - phoneHeight, width: 26, height: phoneHeight)
        let body = RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: phone)
        context.fill(body, with: .color(white.opacity(0.12)))
        context.stroke(body, with: .color(white), lineWidth: 2)
        // The camera, blinking softly.
        let lens = CGPoint(x: phone.maxX - 1, y: phone.minY + 10)
        let ring = Path(ellipseIn: CGRect(x: lens.x - 5, y: lens.y - 5, width: 10, height: 10))
        context.fill(ring, with: .color(white.opacity(0.25 + 0.6 * pulse)))

        // The field of view, towards the person.
        var cone = Path()
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: 22))
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: floorY - 4))
        context.stroke(cone, with: .color(white.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

        // The hip line, from the lens across the floor: "at hip height".
        var hipLine = Path()
        hipLine.move(to: CGPoint(x: phone.maxX + 8, y: lens.y))
        hipLine.addLine(to: CGPoint(x: size.width - 150, y: lens.y))
        context.stroke(hipLine, with: .color(white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))

        // The distance, written under the floor.
        let text = Text("2 to 3 m").font(.caption.weight(.semibold)).foregroundStyle(white.opacity(0.8))
        context.draw(context.resolve(text), at: CGPoint(x: (phone.maxX + size.width - 150) / 2, y: floorY + 16))
        var arrow = Path()
        arrow.move(to: CGPoint(x: phone.maxX + 6, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 - 34, y: floorY + 16))
        arrow.move(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 + 34, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: size.width - 150, y: floorY + 16))
        context.stroke(arrow, with: .color(white.opacity(0.4)), lineWidth: 1)

        // "Side view" label at the top left.
        let label = Text("Side view · hip height").font(.footnote.weight(.semibold)).foregroundStyle(white)
        context.draw(context.resolve(label), at: CGPoint(x: 14, y: 12), anchor: .topLeading)
    }
}
