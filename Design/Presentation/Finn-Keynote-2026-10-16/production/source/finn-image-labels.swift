import AppKit
import Vision
for path in CommandLine.arguments.dropFirst() {
    guard let image = NSImage(contentsOfFile: path), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    do {
        try VNImageRequestHandler(cgImage: cg).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        print(URL(fileURLWithPath: path).lastPathComponent, cg.width, cg.height, lines.prefix(14).joined(separator: " | "))
    } catch { print("OCR ERROR", path, error) }
}
