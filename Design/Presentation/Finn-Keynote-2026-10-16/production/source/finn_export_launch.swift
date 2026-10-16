import SwiftUI
import AppKit
@main struct ExportLaunch {
    @MainActor static func main() {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for i in 0 ..< 48 {
            let time = Double(i) / 24
            let content = ZStack {
                Color.black
                FinnLogoMotionFrame(elapsed: min(time, 0.8), reducesMotion: false).frame(
                    width: 156,
                    height: 156
                )
            }.frame(width: 402, height: 874)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            guard let cg = renderer.cgImage else {
                fatalError("No launch frame")
            }
            let bitmap = NSBitmapImageRep(cgImage: cg)
            try! bitmap.representation(using: .png, properties: [:])!
                .write(to: output.appendingPathComponent(String(
                    format: "%04d.png",
                    i + 1
                )))
        }
    }
}
