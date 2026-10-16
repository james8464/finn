import Foundation
import Testing
@testable import Finn

struct SetShareSummaryTests {
    @Test func measuredSummaryIncludesRepCountAndActionWithoutMedia() {
        let analysis = SetAnalysis(
            reps: [RepMetric(number: 1, startTime: 0, endTime: 2, normalisedHipTravel: 0.4)],
            confidence: 0.9,
            rubricVersion: SquatRubric.version
        )
        let cue = Cue(kind: .rangeDecreased, repNumbers: [1], earlierMedian: 0.5,
                      laterMedian: 0.4, observation: "Range became shorter.",
                      nextAction: "Keep a steady pace.")

        let text = SetShareSummary.text(for: analysis, cue: cue, cueDismissed: false)

        #expect(text.contains("1 measured rep"))
        #expect(text.contains("Range became shorter."))
        #expect(text.contains("Keep a steady pace."))
        #expect(text.contains("No video is included."))
        #expect(text.contains("not a full technique assessment"))
    }

    @Test func dismissedObservationIsNotShared() {
        let analysis = SetAnalysis(reps: [], confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        let cue = Cue(kind: .rangeDecreased, repNumbers: [1], earlierMedian: 0.5,
                      laterMedian: 0.4, observation: "Range became shorter.",
                      nextAction: "Keep a steady pace.")

        let text = SetShareSummary.text(for: analysis, cue: cue, cueDismissed: true)

        #expect(!text.contains(cue.observation))
        #expect(!text.contains(cue.nextAction))
        #expect(text.contains("No observation shared"))
    }

    @Test func comparableSetsShareMeasuredChangeWithoutClaimingImprovement() {
        let analysis = SetAnalysis(reps: [], confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        let comparison = Comparison(
            firstSetID: UUID(), secondSetID: UUID(),
            firstMedianRange: 0.39, secondMedianRange: 0.47,
            firstMedianDuration: 1.6, secondMedianDuration: 1.8,
            rangeDirection: .longer, cueRepNumbers: [], cueKind: nil
        )

        let text = SetShareSummary.text(for: analysis, cue: nil, cueDismissed: false,
                                        comparison: comparison)

        #expect(text.contains("Camera-measured range was longer in set 2."))
        #expect(text.contains("Latest set: 0 measured reps"))
        #expect(text.contains("one camera-visible measure"))
        #expect(!text.localizedCaseInsensitiveContains("improved"))
        #expect(text.contains("No video is included."))
    }

    @Test func noClearChangeDoesNotBecomeAPositiveClaim() {
        let analysis = SetAnalysis(reps: [], confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        let comparison = Comparison(
            firstSetID: UUID(), secondSetID: UUID(),
            firstMedianRange: 0.40, secondMedianRange: 0.41,
            firstMedianDuration: 1.6, secondMedianDuration: 1.6,
            rangeDirection: .noClearChange, cueRepNumbers: [], cueKind: nil
        )

        let text = SetShareSummary.text(for: analysis, cue: nil, cueDismissed: false,
                                        comparison: comparison)

        #expect(text.contains("No clear measured range change between sets."))
        #expect(!text.localizedCaseInsensitiveContains("better"))
    }

    @Test func shorterRangeIsSharedAsMeasurementNotSafetyJudgment() {
        let analysis = SetAnalysis(reps: [], confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        let comparison = Comparison(
            firstSetID: UUID(), secondSetID: UUID(),
            firstMedianRange: 0.50, secondMedianRange: 0.38,
            firstMedianDuration: 1.6, secondMedianDuration: 1.7,
            rangeDirection: .shorter, cueRepNumbers: [], cueKind: nil
        )

        let text = SetShareSummary.text(for: analysis, cue: nil, cueDismissed: false,
                                        comparison: comparison)

        #expect(text.contains("Camera-measured range was shorter in set 2."))
        #expect(!text.localizedCaseInsensitiveContains("unsafe"))
    }
}
