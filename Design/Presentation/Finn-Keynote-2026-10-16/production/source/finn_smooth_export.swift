import SwiftUI
import AppKit
struct Point: Decodable { let x: Double
    let y: Double
    let confidence: Double }

struct Frame: Decodable { let time: Double
    let joints: [String: Point] }

struct SkeletonGeometry {
    struct Joint { let point: CGPoint
        let reliable: Bool }

    struct Bone { let from: CGPoint
        let to: CGPoint
        let reliable: Bool }

    struct AngleLabel { let vertex: CGPoint
        let degrees: Int
        let text: String
        let reliable: Bool }

    var joints: [Joint] = []
    var bones: [Bone] = []
    var angle: AngleLabel?
    var bystanderBones: [Bone] = []
    var bystanderJoints: [CGPoint] = []
    init(_ points: [String: Point]) {
        func place(_ p: Point) -> CGPoint {
            CGPoint(x: p.x * 440, y: 33 + (p.y * 890))
        }
        joints = points.values.map { Joint(point: place($0), reliable: $0.confidence >= 0.3) }
        let links = [
            ("leftShoulder", "rightShoulder"),
            ("leftHip", "rightHip"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            ("leftShoulder", "leftHip"),
            ("rightShoulder", "rightHip"),
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle")
        ]
        for (a, b) in links {
            if let x = points[a], let y = points[b] {
                bones.append(Bone(
                    from: place(x),
                    to: place(y),
                    reliable: min(x.confidence, y.confidence) >= 0.3
                )) }
        }
        if let h = points["leftHip"], let k = points["leftKnee"], let a = points["leftAnkle"] {
            let u = CGPoint(x: h.x - k.x, y: (h.y - k.y) * 2.02247191), v = CGPoint(
                x: a.x - k.x,
                y: (a.y - k.y) * 2.02247191
            )
            let c = (u.x * v.x + u.y * v.y) / (hypot(u.x, u.y) * hypot(v.x, v.y))
            let d = Int((acos(max(-1, min(1, c))) * 180 / .pi).rounded())
            angle = AngleLabel(
                vertex: place(k),
                degrees: d,
                text: "Knee \(d)°",
                reliable: min(h.confidence, k.confidence, a.confidence) >= 0.3
            )
        }
    }
}

struct NativeScreen: View {
    let photo: NSImage
    let points: [String: Point]
    let time: Double
    let status: NSImage
    let stop: NSImage
    let framing: Bool
    var count: Int {
        time >= 3.7 ? 2 : time >= 2.1 ? 1 : 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            Image(nsImage: photo).resizable().frame(width: 440, height: 890).offset(y: 33)
            LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .center, endPoint: .bottom)
            Canvas { ctx, size in SkeletonPainter.draw(
                SkeletonGeometry(points),
                in: &ctx,
                size: size,
                clear: .white,
                labelText: .black,
                lineWidth: 2
            ) }
            Image(nsImage: status).resizable().frame(width: 440, height: 60)
            HStack(spacing: 10) { Image(systemName: "viewfinder")
                Text(framing ? "Checking leg visibility" : "Analyzing live") }.font(.system(
                size: 15,
                weight: .semibold
            )).padding(.horizontal, 14).padding(.vertical, 10).background(
                .black.opacity(0.68),
                in: Capsule()
            )
            .offset(
                x: 24,
                y: 90
            )
            if !framing {
                VStack(spacing: 0) { Text("\(count)").font(.system(
                    size: 64,
                    weight: .semibold,
                    design: .rounded
                )).monospacedDigit()
                Text(count == 1 ? "squat" : "squats").font(.system(size: 17, weight: .semibold)) }.padding(
                    .horizontal,
                    24
                ).padding(.vertical, 8).background(
                    .black.opacity(0.68),
                    in: RoundedRectangle(cornerRadius: 20)
                ).frame(width: 116).offset(x: 300, y: 80)
                Text(String(format: "00:%02d", Int(time))).font(.system(size: 22, weight: .semibold))
                    .monospacedDigit().frame(width: 440).offset(y: 730)
                Image(nsImage: stop).resizable().frame(width: 200, height: 62).offset(x: 120, y: 776)
            } else {
                Text("Stand sideways. Show head to toe.").font(.system(size: 17)).frame(width: 440)
                    .offset(y: 730)
                HStack { Image(systemName: "play.fill")
                    Text("Start set") }.font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                    .frame(
                        width: 200,
                        height: 62
                    ).background(.white, in: Capsule()).offset(x: 120, y: 776)
            }
            Text("Cancel").font(.system(size: 17)).frame(width: 440).offset(y: 862)
        }.foregroundStyle(.white).frame(width: 440, height: 956).clipped().environment(\.colorScheme, .dark)
    }
}

@main struct Export {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let frames = try JSONDecoder().decode(
            [Frame].self,
            from: Data(contentsOf: root.appendingPathComponent("poses.json"))
        )
        let photoDir = root.appendingPathComponent("plates")
        let photos = try FileManager.default
            .contentsOfDirectory(at: photoDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let status = NSImage(contentsOf: root.appendingPathComponent("status.png"))!,
            stop = NSImage(contentsOf: root.appendingPathComponent("stop.png"))!
        for mode in ["live", "setup"] {
            let out = root.appendingPathComponent(mode)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            for (i, url) in photos.enumerated() {
                let t = Double(i) / 24
                let hi = frames.firstIndex { $0.time >= t } ?? frames.count - 1
                let lo = max(0, hi - 1)
                let a = frames[lo], b = frames[hi]
                let q = max(0, min(1, (t - a.time) / max(0.001, b.time - a.time)))
                var points: [String: Point] = [:]
                for (key, v) in a.joints {
                    let w = b.joints[key] ?? v
                    points[key] = Point(
                        x: v.x + (w.x - v.x) * q,
                        y: v.y + (w.y - v.y) * q,
                        confidence: v.confidence + (w.confidence - v.confidence) * q
                    ) }
                let screen = NativeScreen(
                    photo: NSImage(contentsOf: url)!,
                    points: points,
                    time: t,
                    status: status,
                    stop: stop,
                    framing: mode == "setup"
                )
                let renderer = ImageRenderer(content: screen)
                renderer.scale = 1.5
                guard let cg = renderer.cgImage else {
                    fatalError("No frame")
                }
                let bitmap = NSBitmapImageRep(cgImage: cg)
                try bitmap.representation(using: .png, properties: [:])!
                    .write(to: out.appendingPathComponent(String(
                        format: "%04d.png",
                        i + 1
                    )))
            }
        }
    }
}
