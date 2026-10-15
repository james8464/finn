import AVFoundation
import SwiftUI

/// the camera picture with the live skeleton on top. Both are drawn in the same box, so the
/// skeleton stays on the body when the picture is mirrored or turned
struct CameraFeedView: View {
    let model: WorkoutSessionModel

    var body: some View {
        GeometryReader { proxy in
            let feed = model.previewFeed
            let rotation = feed?.displayRotationDegrees ?? 0
            let sideways = Int(rotation / 90) % 2 == 1
            let inner = sideways
                ? CGSize(width: proxy.size.height, height: proxy.size.width)
                : proxy.size
            ZStack {
                if let feed {
                    FeedDisplay(feed: feed)
                        .scaleEffect(x: feed.isMirrored ? -1 : 1, y: 1)
                        .accessibilityHidden(true)
                }
                SkeletonOverlay(model: model, mirrored: feed?.isMirrored ?? false)
            }
            .frame(width: inner.width, height: inner.height)
            .rotationEffect(.degrees(rotation))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

/// bones and joints of the tracked person: white when Vision is sure of them, orange when the
/// analysis would ignore them, with the measured angle beside the key joint. Other people are
/// drawn thin and grey
private struct SkeletonOverlay: View {
    let model: WorkoutSessionModel
    let mirrored: Bool

    var body: some View {
        GeometryReader { proxy in
            if let frame = model.livePose, !frame.joints.isEmpty || !(frame.bystanders ?? []).isEmpty {
                let geometry = SkeletonGeometry(frame: frame, exercise: model.captureExercise.definition,
                                                size: proxy.size, mirrored: mirrored)
                Canvas { context, size in
                    draw(geometry, in: &context, size: size)
                }
                .accessibilityElement()
                .accessibilityLabel("Body outline")
                .accessibilityValue(geometry.summary)
                .accessibilityIdentifier("camera.skeleton")
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ geometry: SkeletonGeometry, in context: inout GraphicsContext, size canvas: CGSize) {
        SkeletonPainter.draw(geometry, in: &context, size: canvas, clear: .white, labelText: .black)
    }
}

/// draws a `SkeletonGeometry`: clear bones and joints in `clear`, unclear ones orange and dashed,
/// other people thin and grey, and the angle in a badge beside its joint
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
            let centre = CGPoint(x: min(max(wanted, halfBadge), max(halfBadge, canvas.width - halfBadge)),
                                 y: angle.vertex.y)
            let badge = CGRect(x: centre.x - size.width / 2 - 8, y: centre.y - size.height / 2 - 4,
                               width: size.width + 16, height: size.height + 8)
            context.fill(Path(roundedRect: badge, cornerRadius: badge.height / 2),
                         with: .color(angle.reliable ? clear : weak))
            context.draw(resolved, at: centre)
        }
    }
}

/// shows the frames the analysis receives, and reports the phone's rotation to the feed
private struct FeedDisplay: UIViewRepresentable {
    let feed: PreviewFeed

    func makeUIView(context: Context) -> FeedDisplayView {
        let view = FeedDisplayView()
        view.feed = feed
        return view
    }

    func updateUIView(_ uiView: FeedDisplayView, context: Context) {
        uiView.feed = feed
    }

    static func dismantleUIView(_ uiView: FeedDisplayView, coordinator: ()) {
        uiView.feed = nil
    }
}

final class FeedDisplayView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    private var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private lazy var receiver = synchronizer.sampleBufferReceiver(adding: displayLayer.sampleBufferRenderer)
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []

    var feed: PreviewFeed? {
        didSet {
            guard feed !== oldValue else { return }
            oldValue?.sink.attach(nil)
            connect()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        displayLayer.videoGravity = .resizeAspect
        synchronizer.rate = 1
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        connect()
    }

    private func connect() {
        observations = []
        rotationCoordinator = nil
        guard let feed, window != nil else { return }
        feed.sink.attach(receiver)
        guard let device = feed.device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: displayLayer)
        rotationCoordinator = coordinator
        // updates arrive on the main queue
        let report: (AVCaptureDevice.RotationCoordinator) -> Void = { [weak feed] coordinator in
            MainActor.assumeIsolated {
                feed?.rotationChanged(capture: coordinator.videoRotationAngleForHorizonLevelCapture,
                                      preview: coordinator.videoRotationAngleForHorizonLevelPreview)
            }
        }
        observations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { coordinator, _ in
                report(coordinator)
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { coordinator, _ in
                report(coordinator)
            },
        ]
    }
}
