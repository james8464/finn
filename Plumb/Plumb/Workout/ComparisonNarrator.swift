import Foundation
import FoundationModels

nonisolated enum RecapSource: Equatable {
    case template
    case appleIntelligence
}

nonisolated struct GeneratedRecap: Sendable {
    let explanation: String
    let evidenceRepNumbers: [Int]
}

nonisolated struct Recap: Equatable {
    let text: String
    let evidenceRepNumbers: [Int]
    let source: RecapSource
    let facts: Comparison
}

@MainActor
protocol RecapGenerating: AnyObject {
    var available: Bool { get }
    func generate(for comparison: Comparison) async throws -> GeneratedRecap
}

@MainActor
final class ComparisonNarrator {
    private let generator: any RecapGenerating
    private let timeout: Duration

    init(generator: any RecapGenerating, timeout: Duration = .seconds(3)) {
        self.generator = generator
        self.timeout = timeout
    }

    convenience init(timeout: Duration = .seconds(3)) {
        self.init(generator: AppleRecapGenerator(), timeout: timeout)
    }

    func recap(for comparison: Comparison) async -> Recap {
        guard generator.available else { return template(for: comparison) }
        let stream = AsyncStream<GeneratedRecap?>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let generation = Task { @MainActor [generator] in
                continuation.yield(try? await generator.generate(for: comparison))
                continuation.finish()
            }
            let timer = Task.detached { [timeout] in
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                continuation.yield(nil)
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                generation.cancel()
                timer.cancel()
            }
        }
        var iterator = stream.makeAsyncIterator()
        let generated = await iterator.next() ?? nil
        guard let generated, isValid(generated, for: comparison) else {
            return template(for: comparison)
        }
        return Recap(text: generated.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                     evidenceRepNumbers: generated.evidenceRepNumbers,
                     source: .appleIntelligence, facts: comparison)
    }

    private func template(for comparison: Comparison) -> Recap {
        let text: String
        switch comparison.rangeDirection {
        case .longer: text = "Camera-measured range was longer in your second set."
        case .shorter: text = "Camera-measured range was shorter in your second set."
        case .noClearChange: text = "There was no clear camera-measured range change between sets."
        }
        return Recap(text: text, evidenceRepNumbers: comparison.cueRepNumbers,
                     source: .template, facts: comparison)
    }

    private func isValid(_ generated: GeneratedRecap, for comparison: Comparison) -> Bool {
        let text = generated.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard generated.evidenceRepNumbers.sorted() == comparison.cueRepNumbers.sorted() else {
            return false
        }
        switch comparison.rangeDirection {
        case .longer, .shorter:
            let direction = comparison.rangeDirection == .longer ? "longer" : "shorter"
            let subjects = ["Your camera-measured range", "Your measured range", "Your range",
                            "The camera-measured range"]
            let endings = ["the second set.", "your second set."]
            return subjects.contains { subject in
                endings.contains { ending in text == "\(subject) was \(direction) in \(ending)" }
            }
        case .noClearChange:
            return ["There was no clear camera-measured range change between sets.",
                    "There was no clear range change between sets.",
                    "There was no clear camera-measured range change between your sets.",
                    "There was no clear range change between your sets."].contains(text)
        }
    }
}

@Generable
private struct AppleGeneratedRecap {
    var explanation: String
    var evidenceRepNumbers: [Int]
}

@MainActor
private final class AppleRecapGenerator: RecapGenerating {
    var available: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        let instructions = """
            Choose one plain sentence about the supplied camera-measured comparison. For longer or
            shorter, use "Your camera-measured range was longer/shorter in the second set." with
            the supplied direction. For no clear change, use "There was no clear camera-measured
            range change between sets." Do not add causes, measurements, body-part diagnoses,
            safety claims, advice, or numbers. Return the evidence rep numbers exactly as supplied.
            """
        let prompt = """
            Direction: \(comparison.rangeDirection.rawValue).
            First relative range: \(comparison.firstMedianRange).
            Second relative range: \(comparison.secondMedianRange).
            First median rep duration: \(comparison.firstMedianDuration) seconds.
            Second median rep duration: \(comparison.secondMedianDuration) seconds.
            Cue category: \(comparison.cueKind?.rawValue ?? "none").
            Evidence rep numbers: \(comparison.cueRepNumbers).
            """
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: AppleGeneratedRecap.self)
        return GeneratedRecap(explanation: response.content.explanation,
                              evidenceRepNumbers: response.content.evidenceRepNumbers)
    }
}
