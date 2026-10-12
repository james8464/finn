import AVFoundation
import SwiftUI

/// The camera picture with the live skeleton on top. Both are drawn in the same box, so the
/// skeleton stays on the body when the picture is mirrored or turned.
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

/// Bones and joints of the tracked person: white when Vision is sure of them, orange when the
/// analysis would ignore them, with the measured angle beside the key joint.
private struct SkeletonOverlay: View {
    let model: WorkoutSessionModel
    let mirrored: Bool

    var body: some View {
        GeometryReader { proxy in
            if let frame = model.livePose, !frame.joints.isEmpty {
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
        let clear = Color.white
        let weak = Color.orange
        for bone in geometry.bones {
            var path = Path()
            path.move(to: bone.from)
            path.addLine(to: bone.to)
            context.stroke(path, with: .color((bone.reliable ? clear : weak).opacity(bone.reliable ? 0.9 : 0.7)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                              dash: bone.reliable ? [] : [6, 5]))
        }
        for joint in geometry.joints {
            let dot = CGRect(x: joint.point.x - 5, y: joint.point.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: dot), with: .color(joint.reliable ? clear : weak))
            context.stroke(Path(ellipseIn: dot), with: .color(.black.opacity(0.5)), lineWidth: 1)
        }
        if let angle = geometry.angle {
            let text = Text(angle.text)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(angle.reliable ? Color.black : Color.white)
            let resolved = context.resolve(text)
            let size = resolved.measure(in: CGSize(width: 200, height: 40))
            // Right of the joint, or left of it near the right edge.
            let offset = 14 + size.width / 2
            let fitsRight = angle.vertex.x + offset + size.width / 2 + 8 <= canvas.width
            let center = CGPoint(x: angle.vertex.x + (fitsRight ? offset : -offset), y: angle.vertex.y)
            let badge = CGRect(x: center.x - size.width / 2 - 8, y: center.y - size.height / 2 - 4,
                               width: size.width + 16, height: size.height + 8)
            context.fill(Path(roundedRect: badge, cornerRadius: badge.height / 2),
                         with: .color(angle.reliable ? clear : weak))
            context.draw(resolved, at: center)
        }
    }
}

/// Shows the frames the analysis receives, and reports the phone's rotation to the feed.
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
        feed.sink.attach(displayLayer.sampleBufferRenderer)
        guard let device = feed.device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: displayLayer)
        rotationCoordinator = coordinator
        // Updates arrive on the main queue.
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
