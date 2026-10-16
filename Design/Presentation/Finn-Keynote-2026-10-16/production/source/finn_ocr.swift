import AppKit
import Vision
for path in CommandLine.arguments.dropFirst() {
    guard
        let image = NSImage(contentsOfFile: path), let cg = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
        continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try? VNImageRequestHandler(cgImage: cg).perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    let hits = lines
        .filter {
            $0.localizedCaseInsensitiveContains("plumb") || $0.localizedCaseInsensitiveContains("plunb") }
    if !hits.isEmpty {
        print(path + ": " + hits.joined(separator: " | "))
    }
}
