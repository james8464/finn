import AVFoundation
import Observation

/// what the camera screen shows: the very frames the pose analysis receives, so the skeleton
/// drawn over them lines up whatever the phone's orientation
///
/// Frames reach the analysis already turned upright relative to gravity (the capture connection
/// applies `videoRotationAngleForHorizonLevelCapture`), so Vision always sees a standing person
/// standing. The interface stays in portrait; when the phone is turned sideways, the screen
/// rotates the picture by `displayRotationDegrees` so it looks level to the person holding it
@MainActor @Observable
final class PreviewFeed {
    /// the front camera is shown like a mirror. The analysis keeps the unmirrored frame, and the
    /// skeleton is flipped with the picture
    let isMirrored: Bool
    /// extra clockwise rotation for the picture and its skeleton, a multiple of 90°
    private(set) var displayRotationDegrees = 0.0
    /// the camera whose rotation the screen follows; nil for a video file
    @ObservationIgnored let device: AVCaptureDevice?
    @ObservationIgnored nonisolated let sink: PreviewFrameSink
    /// receives the capture rotation so frames reach the analysis upright
    @ObservationIgnored var onCaptureRotation: (@MainActor (Double) -> Void)?

    init(isMirrored: Bool, device: AVCaptureDevice?, sink: PreviewFrameSink = PreviewFrameSink()) {
        self.isMirrored = isMirrored
        self.device = device
        self.sink = sink
    }

    /// called with the rotation coordinator's angles whenever the phone turns
    func rotationChanged(capture: Double, preview: Double) {
        onCaptureRotation?(capture)
        displayRotationDegrees = Self.displayRotation(
            capture: capture,
            preview: preview,
            mirrored: isMirrored
        )
    }

    /// the rotation still needed on screen for a frame already rotated by `capture` degrees,
    /// rounded to a quarter turn and kept in 0..<360
    ///
    /// The coordinator's preview angle is meant for a capture preview layer, which mirrors the front
    /// camera after turning it. This screen mirrors the upright frame first and turns it after, so a
    /// mirrored feed turns the other way. Both cameras then get the same turn for the same phone
    /// position, as they should for an upright frame; before, the front camera was drawn upside
    /// down whenever the phone stood on its side
    nonisolated static func displayRotation(
        capture: Double,
        preview: Double,
        mirrored: Bool = false
    ) -> Double {
        let turn = mirrored ? capture - preview : preview - capture
        let quarterTurns = Int((turn / 90).rounded())
        return Double(((quarterTurns % 4) + 4) % 4 * 90)
    }
}

/// passes frames from the capture queue to the on-screen renderer
nonisolated final class PreviewFrameSink: @unchecked Sendable {
    private let lock = NSLock()
    private var receiver: AVSampleBufferVideoRenderer.Receiver?

    func attach(_ receiver: AVSampleBufferVideoRenderer.Receiver?) {
        lock.lock()
        defer { lock.unlock() }
        self.receiver?.flush()
        self.receiver = receiver
    }

    @discardableResult
    func enqueue(_ sampleBuffer: CMSampleBuffer) -> AVSampleBufferVideoRenderer.Receiver.EnqueueResult? {
        lock.lock()
        defer { lock.unlock() }
        guard
            let receiver, CMSampleBufferDataIsReady(sampleBuffer),
            let copy = try? CMSampleBuffer(copying: sampleBuffer) else {
            return nil
        }
        // own the presentation metadata; pose analysis still reads the original capture buffer
        if
            let attachments = CMSampleBufferGetSampleAttachmentsArray(copy, createIfNecessary: true),
            CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(
                CFArrayGetValueAtIndex(attachments, 0),
                to: CFMutableDictionary.self
            )
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately)
                    .toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        let ready = CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(unsafeBuffer: copy)
        let result = receiver.enqueueImmediately(ready)
        switch result {
        case .cancelledDueToFlushRequiredToResume,
             .cancelledDueToError:
            receiver.flush()
            return receiver.enqueueImmediately(ready)
        default:
            return result
        }
    }
}
