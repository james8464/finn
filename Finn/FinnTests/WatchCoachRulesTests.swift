import Foundation
import Testing
@testable import Finn

nonisolated struct WatchCoachRulesTests {
    private let definition = ExerciseKind.bodyweightSquat.definition

    @Test func praiseNeedsMeasuredConsistency() {
        let steady = reps([2, 2.1, 2.05, 2.0, 2.1], ranges: [0.3, 0.31, 0.3, 0.3, 0.31])
        let erratic = reps([2, 2.1, 1.0, 3.5, 2.1], ranges: [0.3, 0.31, 0.12, 0.3, 0.31])
        let praise = WatchCoachRules.line(
            for: .repCounted(5),
            reps: steady,
            definition: definition,
            canCompareRange: true
        )
        let neutral = WatchCoachRules.line(for: .repCounted(5), reps: erratic, definition: definition)
        let uncertainView = WatchCoachRules.line(
            for: .repCounted(5),
            reps: steady,
            definition: definition,
            canCompareRange: false
        )
        #expect(praise?.contains("steady") == true)
        #expect(neutral?.contains("steady") == false)
        #expect(neutral?.contains("Five") == true)
        #expect(uncertainView?.contains("steady") == false)
    }

    @Test func techniqueMessagesComeFromActualLiveEvents() {
        let measured = reps([2, 2, 1.1, 1], ranges: [0.3, 0.3, 0.2, 0.1])
        #expect(WatchCoachRules.line(
            for: .fasterThanFirstReps(rep: 4),
            reps: measured,
            definition: definition
        )?.contains("quicker") == true)
        #expect(WatchCoachRules.line(
            for: .shorterThanFirstReps(rep: 4),
            reps: measured,
            definition: definition
        )?.contains("shorter") == true)
        #expect(WatchCoachRules.line(
            for: .repCountRevised(3),
            reps: measured,
            definition: definition
        ) == nil)
        #expect(WatchCoachRules.line(
            for: .repCounted(4),
            reps: measured,
            definition: definition
        ) == nil)
    }

    private func reps(_ durations: [Double], ranges: [Double]) -> [RepMetric] {
        zip(durations, ranges).enumerated().map { offset, pair in
            RepMetric(
                number: offset + 1,
                startTime: Double(offset) * 4,
                endTime: Double(offset) * 4 + pair.0,
                relativeRange: pair.1
            )
        }
    }
}
