import AVFoundation
import CoreVideo
import Testing
@testable import Finn

struct PreviewFeedTests {
    @MainActor @Test
    func readyFramesRenderAfterAttachAndStopAfterDetach() throws {
        let layer = AVSampleBufferDisplayLayer()
        let synchronizer = AVSampleBufferRenderSynchronizer()
        synchronizer.rate = 1
        let receiver = synchronizer.sampleBufferReceiver(adding: layer.sampleBufferRenderer)
        let sink = PreviewFrameSink()
        let sample = try Self.sample()

        try withExtendedLifetime(synchronizer) {
            if case .some = sink.enqueue(sample) { Issue.record("An unattached sink accepted a frame") }
            sink.attach(receiver)
            guard case .enqueued? = sink.enqueue(sample) else {
                Issue.record("The receiver rejected a ready preview frame")
                return
            }
            // Rendering must not change the capture buffer's presentation metadata.
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false),
               CFArrayGetCount(attachments) > 0 {
                let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self)
                #expect(!CFDictionaryContainsKey(dictionary,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()))
            }
            sink.attach(nil)
            if case .some = sink.enqueue(sample) { Issue.record("A detached sink accepted a frame") }
            sink.attach(receiver)
            guard case .enqueued? = sink.enqueue(try Self.sample()) else {
                Issue.record("The receiver did not resume after reattachment")
                return
            }
            sink.attach(nil)
        }
    }

    private static func sample() throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixelBuffer) == kCVReturnSuccess)
        let pixels = try #require(pixelBuffer)
        var format: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: pixels, formatDescriptionOut: &format) == noErr)
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        #expect(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels,
            formatDescription: try #require(format), sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer) == noErr)
        return try #require(sampleBuffer)
    }
}
