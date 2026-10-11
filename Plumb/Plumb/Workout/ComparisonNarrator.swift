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
        let generated = await withTaskGroup(of: GeneratedRecap?.self) { group in
            group.addTask { [generator] in try? await generator.generate(for: comparison) }
            group.addTask { [timeout] in
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
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
        let lower = text.lowercased()
        guard !text.isEmpty, text.count <= 180,
              generated.evidenceRepNumbers.sorted() == comparison.cueRepNumbers.sorted(),
              !text.contains(where: \.isNumber),
              !["safe", "injury", "pain", "medical", "diagnos", "knee", "hip", "spine", "percent", "degree"]
                .contains(where: lower.contains),
              lower.contains("range") else { return false }
        switch comparison.rangeDirection {
        case .longer: return lower.contains("longer")
        case .shorter: return lower.contains("shorter")
        case .noClearChange: return lower.contains("no clear")
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
            Rewrite only the supplied camera-measured squat-set comparison in one plain sentence.
            Use the word range and preserve its direction exactly. Do not add measurements, body-part
            diagnoses, safety claims, advice, or numbers in the sentence. Return the evidence rep
            numbers exactly as supplied, without adding or removing any.
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
