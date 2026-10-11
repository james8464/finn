import Foundation
import Testing
@testable import Plumb

@MainActor
struct ComparisonNarratorTests {
    @Test func unavailableModelUsesReviewedTemplate() async {
        let generator = StubRecapGenerator(available: false)
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
        #expect(recap.facts == comparison())
        #expect(recap.text.contains("shorter"))
    }

    @Test func invalidReferenceUsesTemplate() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your measured range was shorter in the second set.",
            evidenceRepNumbers: [99]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
        #expect(recap.facts == comparison())
    }

    @Test func unsupportedClaimUsesTemplate() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your knees are safer now and you improved by 23%.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
    }

    @Test func negatedDirectionUsesTemplate() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your range was not shorter in the second set.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
    }

    @Test func conflictingDirectionUsesTemplate() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your range was longer, then shorter in the second set.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
    }

    @Test func extraCoachingAdviceUsesTemplate() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your range was shorter in the second set. Try a steadier pace.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .template)
    }

    @Test func noClearChangeCannotAlsoClaimLongerRange() async {
        let facts = Comparison(firstSetID: UUID(), secondSetID: UUID(),
                               firstMedianRange: 0.4, secondMedianRange: 0.41,
                               firstMedianDuration: 1.5, secondMedianDuration: 1.6,
                               rangeDirection: .noClearChange, cueRepNumbers: [], cueKind: nil)
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "There was no clear range change between sets, but range was longer in the second set.",
            evidenceRepNumbers: []
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: facts)
        #expect(recap.source == .template)
    }

    @Test func timeoutUsesTemplate() async {
        let generator = StubRecapGenerator(delay: .seconds(1), output: GeneratedRecap(
            explanation: "Your measured range was shorter in the second set.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator, timeout: .milliseconds(20))
            .recap(for: comparison())
        #expect(recap.source == .template)
        #expect(recap.facts == comparison())
    }

    @Test func timeoutDoesNotWaitForGeneratorThatIgnoresCancellation() async {
        let clock = ContinuousClock()
        let started = clock.now
        let recap = await ComparisonNarrator(generator: NonCooperativeGenerator(),
                                             timeout: .milliseconds(20))
            .recap(for: comparison())
        #expect(recap.source == .template)
        #expect(started.duration(to: clock.now) < .milliseconds(300))
    }

    @Test func validGeneratedRecapKeepsDeterministicFacts() async {
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your camera-measured range was shorter in the second set.",
            evidenceRepNumbers: [5, 6]
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: comparison())
        #expect(recap.source == .appleIntelligence)
        #expect(recap.evidenceRepNumbers == [5, 6])
        #expect(recap.facts == comparison())
    }

    @Test func validLongerRecapKeepsDeterministicFacts() async {
        let facts = Comparison(firstSetID: UUID(), secondSetID: UUID(),
                               firstMedianRange: 0.3, secondMedianRange: 0.4,
                               firstMedianDuration: 1.5, secondMedianDuration: 1.6,
                               rangeDirection: .longer, cueRepNumbers: [], cueKind: nil)
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "Your camera-measured range was longer in the second set.",
            evidenceRepNumbers: []
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: facts)
        #expect(recap.source == .appleIntelligence)
        #expect(recap.facts == facts)
    }

    @Test func validNoClearChangeRecapKeepsDeterministicFacts() async {
        let facts = Comparison(firstSetID: UUID(), secondSetID: UUID(),
                               firstMedianRange: 0.4, secondMedianRange: 0.41,
                               firstMedianDuration: 1.5, secondMedianDuration: 1.6,
                               rangeDirection: .noClearChange, cueRepNumbers: [], cueKind: nil)
        let generator = StubRecapGenerator(output: GeneratedRecap(
            explanation: "There was no clear camera-measured range change between sets.",
            evidenceRepNumbers: []
        ))
        let recap = await ComparisonNarrator(generator: generator).recap(for: facts)
        #expect(recap.source == .appleIntelligence)
        #expect(recap.facts == facts)
    }

    private func comparison() -> Comparison {
        Comparison(firstSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                   secondSetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                   firstMedianRange: 0.4, secondMedianRange: 0.3,
                   firstMedianDuration: 1.5, secondMedianDuration: 1.6,
                   rangeDirection: .shorter, cueRepNumbers: [5, 6], cueKind: .rangeDecreased)
    }
}

@MainActor
private final class NonCooperativeGenerator: RecapGenerating {
    let available = true

    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        await Task.detached {
            try? await Task.sleep(for: .milliseconds(600))
            return GeneratedRecap(explanation: "Your range was shorter.",
                                  evidenceRepNumbers: [5, 6])
        }.value
    }
}

@MainActor
private final class StubRecapGenerator: RecapGenerating {
    let available: Bool
    let delay: Duration
    let output: GeneratedRecap?

    init(available: Bool = true, delay: Duration = .zero, output: GeneratedRecap? = nil) {
        self.available = available
        self.delay = delay
        self.output = output
    }

    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        try await Task.sleep(for: delay)
        return output ?? GeneratedRecap(explanation: "", evidenceRepNumbers: [])
    }
}
