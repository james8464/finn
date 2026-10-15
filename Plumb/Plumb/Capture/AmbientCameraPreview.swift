import AVFoundation
import SwiftUI

/// The room behind the first screen, blurred: Plumb shows the camera it is about to use instead of
/// a stock picture. Its session stops before the measuring source takes the camera, and never runs
/// until the person has allowed the camera.
@MainActor
@Observable
final class AmbientCamera {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "plumb.ambient-camera")
    private var configured = false
    private(set) var isRunning = false

    var captureSession: AVCaptureSession { session }

    static var isAuthorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    func start() {
        guard Self.isAuthorized, !isRunning else { return }
        isRunning = true
        let session = self.session
        let needsSetup = !configured
        configured = true
        queue.async {
            if needsSetup {
                session.beginConfiguration()
                session.sessionPreset = .medium
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                   let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
            }
            session.startRunning()
        }
    }

    /// Returns once the camera is free for the measuring source.
    func stop() async {
        guard isRunning else { return }
        isRunning = false
        let session = self.session
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                session.stopRunning()
                continuation.resume()
            }
        }
    }
}

/// The ambient camera, softened: a material over the picture, then a wash of the background color.
struct AmbientCameraBackdrop: View {
    let camera: AmbientCamera
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if camera.isRunning && !reduceTransparency {
                AmbientCameraLayer(session: camera.captureSession)
                    .blur(radius: 18)
                    .overlay(.regularMaterial)
                    .overlay(Color(uiColor: .systemBackground).opacity(0.32))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct AmbientCameraLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> AmbientPreviewView {
        let view = AmbientPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: AmbientPreviewView, context: Context) {
        if uiView.previewLayer.session !== session { uiView.previewLayer.session = session }
    }
}

final class AmbientPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
