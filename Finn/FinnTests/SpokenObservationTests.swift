import Foundation
import Testing
@testable import Finn

struct SpokenObservationTests {
    @Test func readsMeasuredEvidenceAndExistingCueOnly() {
        let reps = (1...6).map {
            RepMetric(number: $0, startTime: Double($0), endTime: Double($0) + 1,
                      normalisedHipTravel: 0.4)
        }
        let analysis = SetAnalysis(reps: reps, confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        let cue = Cue(kind: .rangeDecreased, repNumbers: [5, 6],
                      earlierMedian: 0.5, laterMedian: 0.4,
                      observation: "Your range became shorter in the last two reps.",
                      nextAction: "Try a pace you can keep consistent.")

        #expect(SpokenObservation.text(for: analysis, cue: cue) ==
                "6 measured reps. Your range became shorter in the last two reps. Try a pace you can keep consistent.")
    }

    @Test func noSupportedCueHasNoSpeech() {
        let analysis = SetAnalysis(reps: [], confidence: 0.9,
                                   rubricVersion: SquatRubric.version)
        #expect(SpokenObservation.text(for: analysis, cue: nil) == nil)
    }
}
