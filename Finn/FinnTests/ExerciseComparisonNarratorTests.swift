import Foundation
import Testing
@testable import Finn

@MainActor
struct ExerciseComparisonNarratorTests {
    @Test func templateUsesEachExerciseVocabulary() async {
        let expected: [(ExerciseKind, RangeDirection, String)] = [
            (.bodyweightSquat, .longer, "Camera-measured range was longer in your second set."),
            (.pushUp, .shorter, "Camera-measured elbow bend was smaller in your second set."),
            (.staticLunge, .longer, "Camera-measured knee bend was greater in your second set."),
            (
                .stiffLegDeadlift,
                .noClearChange,
                "There was no clear camera-measured hip hinge change between sets."
            ),
        ]
        for (exercise, direction, text) in expected {
            let recap = await ComparisonNarrator(generator: RecordingGenerator(available: false))
                .recap(for: facts(exercise, direction))
            #expect(recap.source == .template)
            #expect(recap.text == text)
            #expect(recap.facts.exercise == exercise)
        }
    }

    @Test func validWordingForTheExerciseIsAccepted() async {
        let cases: [(ExerciseKind, RangeDirection, String)] = [
            (.pushUp, .shorter, "Your camera-measured elbow bend was smaller in the second set."),
            (.pushUp, .longer, "Your push-up elbow bend was greater in your second set."),
            (.staticLunge, .shorter, "The camera-measured knee bend was smaller in the second set."),
            (.stiffLegDeadlift, .noClearChange, "There was no clear hip hinge change between your sets."),
        ]
        for (exercise, direction, sentence) in cases {
            let generator = RecordingGenerator(output: GeneratedRecap(
                explanation: sentence, evidenceRepNumbers: [5, 6]
            ))
            let recap = await ComparisonNarrator(generator: generator, timeout: .seconds(30))
                .recap(for: facts(exercise, direction))
            #expect(recap.source == .appleIntelligence, "\(sentence)")
            #expect(recap.text == sentence)
            #expect(generator.receivedExercises == [exercise])
        }
    }

    @Test func wordingFromAnotherExerciseFallsBack() async {
        let mismatched = [
            "Your camera-measured range was smaller in the second set.",
            "Your squat range was shorter in the second set.",
            "Your camera-measured knee bend was smaller in the second set.",
            "Your camera-measured elbow bend was shorter in the second set.",
        ]
        for sentence in mismatched {
            let generator = RecordingGenerator(output: GeneratedRecap(
                explanation: sentence, evidenceRepNumbers: [5, 6]
            ))
            let recap = await ComparisonNarrator(generator: generator, timeout: .seconds(30))
                .recap(for: facts(.pushUp, .shorter))
            #expect(recap.source == .template, "\(sentence)")
        }
    }

    @Test func addedCausesNumbersAndAdviceFallBackForEveryExercise() async {
        for exercise in ExerciseKind.allCases {
            let copy = exercise.definition.copy
            let base = "Your camera-measured \(copy.rangeNoun) was \(copy.lessRange) in the second set"
            for addition in [" because you got tired.", ". Try a steadier pace.", " by 12 degrees."] {
                let sentence = base + addition
                let generator = RecordingGenerator(output: GeneratedRecap(
                    explanation: sentence, evidenceRepNumbers: [5, 6]
                ))
                let recap = await ComparisonNarrator(generator: generator, timeout: .seconds(30))
                    .recap(for: facts(exercise, .shorter))
                #expect(recap.source == .template, "\(exercise): \(sentence)")
            }
        }
    }

    @Test func slowGenerationFallsBackForNewExercises() async {
        let generator = RecordingGenerator(delay: .seconds(1), output: GeneratedRecap(
            explanation: "Your camera-measured hip hinge was smaller in the second set.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator, timeout: .milliseconds(20))
            .recap(for: facts(.stiffLegDeadlift, .shorter))
        #expect(recap.source == .template)
        #expect(recap.text == "Camera-measured hip hinge was smaller in your second set.")
    }

    @Test func acceptedSentencesStayWithinOneExerciseAndCarryNoNumbers() {
        let originalSquat: Set<String> = [
            "Your camera-measured range was shorter in the second set.",
            "Your measured range was shorter in your second set.",
            "Your range was shorter in the second set.",
            "The camera-measured range was shorter in your second set.",
        ]
        let squat = ComparisonNarrator.acceptedSentences(for: facts(.bodyweightSquat, .shorter))
        #expect(originalSquat.isSubset(of: squat))
        for exercise in ExerciseKind.allCases {
            for direction in [RangeDirection.longer, .shorter, .noClearChange] {
                let sentences = ComparisonNarrator.acceptedSentences(for: facts(exercise, direction))
                let others = ExerciseKind.allCases.filter { $0 != exercise }
                    .map { $0.definition.copy.rangeNoun }
                    .filter { $0 != exercise.definition.copy.rangeNoun }
                for sentence in sentences {
                    #expect(sentence.contains(exercise.definition.copy.rangeNoun))
                    #expect(!others.contains { sentence.contains($0) }, "\(sentence)")
                    #expect(sentence.rangeOfCharacter(from: .decimalDigits) == nil)
                }
            }
        }
    }

    private func facts(_ exercise: ExerciseKind, _ direction: RangeDirection) -> Comparison {
        Comparison(
            firstSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            secondSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            firstMedianRange: 80,
            secondMedianRange: 60,
            firstMedianDuration: 1.5,
            secondMedianDuration: 1.6,
            rangeDirection: direction,
            cueRepNumbers: [5, 6],
            cueKind: .rangeDecreased,
            exercise: exercise
        )
    }
}

@MainActor
private final class RecordingGenerator: RecapGenerating {
    let available: Bool
    let delay: Duration
    let output: GeneratedRecap?
    private(set) var receivedExercises: [ExerciseKind] = []

    init(available: Bool = true, delay: Duration = .zero, output: GeneratedRecap? = nil) {
        self.available = available
        self.delay = delay
        self.output = output
    }

    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        receivedExercises.append(comparison.exercise)
        try await Task.sleep(for: delay)
        return output ?? GeneratedRecap(explanation: "", evidenceRepNumbers: [])
    }
}
