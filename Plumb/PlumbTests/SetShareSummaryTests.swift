import Foundation
import Testing
@testable import Plumb

struct SetShareSummaryTests {
    @Test func measuredSummaryIncludesRepCountAndActionWithoutMedia() {
        let analysis = SetAnalysis(
            reps: [RepMetric(number: 1, startTime: 0, endTime: 2, normalizedHipTravel: 0.4)],
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
}
