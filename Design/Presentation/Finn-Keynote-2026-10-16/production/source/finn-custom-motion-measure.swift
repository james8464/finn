import AppKit
import AVFoundation
import CoreVideo
let asset = AVURLAsset(url: URL(fileURLWithPath: "/tmp/finn-custom-motion-native.mp4"))
let track = asset.tracks(withMediaType: .video)[0]
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
reader.startReading()
var marked: [Double] = []
var frameTimes: [Double] = []
while let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) {
    let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    frameTimes.append(time)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
    let row = CVPixelBufferGetBytesPerRow(buffer)
    var pink = 0
    for y in stride(from: height * 2 / 5, to: height * 3 / 5, by: 2) {
        for x in stride(from: width * 2 / 5, to: width * 3 / 5, by: 2) {
            let p = y * row + x * 4
            if bytes[p + 2] > 30 && Int(bytes[p + 2]) > Int(bytes[p + 1]) * 2 && bytes[p] > bytes[p + 1] { pink += 1 }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    if pink > 10 { marked.append(time) }
}
print("frames=\(frameTimes.count) duration=\(frameTimes.last ?? 0)")
if let first = marked.first, let last = marked.last {
    print("logo first=\(first) last=\(last) visible span=\(last-first)")
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    for (i, offset) in [0.05,0.25,0.55,0.8,1.05].enumerated() {
        if let cg = try? generator.copyCGImage(at: CMTime(seconds: first + offset, preferredTimescale: 600), actualTime: nil) {
            let bitmap = NSBitmapImageRep(cgImage: cg)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/finn-custom-native-frame-\(i).png"))
        }
    }
} else { print("No logo frames found") }
