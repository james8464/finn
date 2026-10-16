import AppKit
import AVFoundation
let asset = AVURLAsset(url: URL(fileURLWithPath: "/tmp/finn-launch-motion.mp4"))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
for (i, seconds) in [0.6,0.8,1.0,1.2,1.4,1.8,2.6,3.5].enumerated() {
    if let image = try? generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil) {
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/finn-motion-frame-\(i).png"))
    }
}
