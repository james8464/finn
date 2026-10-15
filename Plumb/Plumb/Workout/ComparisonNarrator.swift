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

    /// reviewed wording used whenever generation is unavailable, slow, or invalid
    private func template(for comparison: Comparison) -> Recap {
        let copy = comparison.exercise.definition.copy
        let text: String
        switch comparison.rangeDirection {
        case .longer: text = String(localized: "Camera-measured \(copy.rangeNoun) was \(copy.moreRange) in your second set.")
        case .shorter: text = String(localized: "Camera-measured \(copy.rangeNoun) was \(copy.lessRange) in your second set.")
        case .noClearChange: text = String(localized: "There was no clear camera-measured \(copy.rangeNoun) change between sets.")
        }
        return Recap(text: text, evidenceRepNumbers: comparison.cueRepNumbers,
                     source: .template, facts: comparison)
    }

    /// accepts only sentences from a closed set built from the exercise's own vocabulary, so the
    /// model can choose wording but cannot add a cause, a number, advice, or another exercise
    static func acceptedSentences(for comparison: Comparison) -> Set<String> {
        let copy = comparison.exercise.definition.copy
        let noun = copy.rangeNoun
        switch comparison.rangeDirection {
        case .longer, .shorter:
            let direction = comparison.rangeDirection == .longer ? copy.moreRange : copy.lessRange
            let subjects = ["Your camera-measured \(noun)", "Your measured \(noun)", "Your \(noun)",
                            "The camera-measured \(noun)", "Your \(copy.shareNoun) \(noun)"]
            let endings = ["the second set.", "your second set."]
            return Set(subjects.flatMap { subject in
                endings.map { ending in "\(subject) was \(direction) in \(ending)" }
            })
        case .noClearChange:
            return ["There was no clear camera-measured \(noun) change between sets.",
                    "There was no clear \(noun) change between sets.",
                    "There was no clear camera-measured \(noun) change between your sets.",
                    "There was no clear \(noun) change between your sets."]
        }
    }

    private func isValid(_ generated: GeneratedRecap, for comparison: Comparison) -> Bool {
        let text = generated.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard generated.evidenceRepNumbers.sorted() == comparison.cueRepNumbers.sorted() else {
            return false
        }
        return Self.acceptedSentences(for: comparison).contains(text)
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
        // the instructions and the accepted sentences are English; other languages keep the template
        guard SpokenLanguage.appLanguage == "en" else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        let definition = comparison.exercise.definition
        let copy = definition.copy
        let instructions = """
            Choose one plain sentence about the supplied camera-measured comparison. For \(copy.moreRange) or
            \(copy.lessRange), use "Your camera-measured \(copy.rangeNoun) was \(copy.moreRange)/\(copy.lessRange) in the second set." with
            the supplied direction. For no clear change, use "There was no clear camera-measured
            \(copy.rangeNoun) change between sets." Do not add causes, measurements, body-part diagnoses,
            safety claims, advice, or numbers. Return the evidence rep numbers exactly as supplied.
            """
        let direction: String
        switch comparison.rangeDirection {
        case .longer: direction = copy.moreRange
        case .shorter: direction = copy.lessRange
        case .noClearChange: direction = comparison.rangeDirection.rawValue
        }
        let measure: String
        switch definition.rangeUnit {
        case .bodyLengthFraction: measure = "relative range"
        case .degrees: measure = "\(copy.rangeNoun) in degrees from the starting position"
        }
        let prompt = """
            Exercise: \(copy.name), side view.
            Direction: \(direction).
            First \(measure): \(comparison.firstMedianRange).
            Second \(measure): \(comparison.secondMedianRange).
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
