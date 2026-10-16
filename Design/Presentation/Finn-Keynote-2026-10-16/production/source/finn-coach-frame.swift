import AVFoundation
import AppKit
let url = URL(fileURLWithPath: "/tmp/finn-backend-ui-attachments/62161401-CABF-43E1-8DB9-BFEF0C343654.mp4")
let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
generator.appliesPreferredTrackTransform = true
let frame = try generator.copyCGImage(at: CMTime(seconds: 26, preferredTimescale: 600), actualTime: nil)
let bitmap = NSBitmapImageRep(cgImage: frame)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/finn-coach-failure.png"))
