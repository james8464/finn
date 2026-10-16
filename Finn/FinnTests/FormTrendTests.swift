import Foundation
import Testing
@testable import Finn

struct FormTrendTests {
    private let session = UUID()

    private func set(
        _ measurements: [FormMeasurement]?,
        exercise: ExerciseKind = .bodyweightSquat,
        side: BodySide = .left,
        partlyVisible: Bool? = nil
    ) -> SetSummary {
        let reps = (1 ... 6).map { RepMetric(
            number: $0,
            startTime: Double($0),
            endTime: Double($0) + 0.5,
            relativeRange: 0.4
        ) }
        return SetSummary(
            id: UUID(),
            sessionID: session,
            capturedAt: .now,
            bodySide: side,
            analysis: SetAnalysis(
                reps: reps,
                confidence: 0.9,
                rubricVersion: "squat-side-v7"
            ),
            cue: nil,
            cueResponse: .unanswered,
            exercise: exercise,
            formMeasurements: measurements,
            partlyVisible: partlyVisible
        )
    }

    private func depth(_ faulty: Int, judged: Int = 6) -> FormMeasurement {
        FormMeasurement(
            check: .squatDepth,
            judged: judged,
            faulty: faulty,
            typical: 35
        )
    }

    private func chest(_ faulty: Int) -> FormMeasurement {
        FormMeasurement(check: .squatChestDrop, judged: 6, faulty: faulty, typical: 30)
    }

    @Test func comparesFaultFrequencyOnlyWhenBothSetsWereMeasured() {
        let changes = FormTrend.compare(set([depth(5)]), set([depth(1)]))
        #expect(changes.count == 1)
        #expect(changes.first?.check == .squatDepth)
        #expect(changes.first?.direction == .improved)
        #expect(changes.first?.earlier.faulty == 5)
        #expect(changes.first?.later.faulty == 1)
    }

    @Test func detectsWorseningWithoutCallingJitterProgress() {
        #expect(FormTrend.compare(set([depth(1)]), set([depth(5)])).first?.direction == .worsened)
        #expect(FormTrend.compare(set([depth(3)]), set([depth(2)])).isEmpty)
    }

    @Test func refusesIncompatibleOrPartlyVisibleSets() {
        let earlier = set([depth(5)])
        #expect(FormTrend.compare(earlier, set([depth(0)], exercise: .pushUp)).isEmpty)
        #expect(FormTrend.compare(earlier, set([depth(0)], side: .right)).isEmpty)
        #expect(FormTrend.compare(earlier, set([depth(0)], partlyVisible: true)).isEmpty)
        #expect(FormTrend.compare(set(nil), set([depth(0)])).isEmpty)
        #expect(FormTrend.compare(earlier, set([depth(0, judged: 2)])).isEmpty)
    }

    @Test func oldSavedSetWithoutMeasurementsStillDecodes() throws {
        let original = try JSONEncoder().encode(set(nil))
        let decoded = try JSONDecoder().decode(SetSummary.self, from: original)
        #expect(decoded.formMeasurements == nil)
    }

    @Test func findsEarlierCompatibleSetPastAnIncompatibleOne() {
        let compatible = set([depth(5)])
        let newerDifferentSide = set([depth(5)], side: .right)
        let latest = set([depth(1)])
        #expect(FormTrend.compareLatest(
            to: latest,
            among: [newerDifferentSide, compatible]
        )
        .map(\.check) == [.squatDepth])
    }

    @Test func comparesEachCheckWithItsOwnLatestEligibleSet() {
        let depthSet = set([depth(5)])
        let chestSet = set([chest(5)])
        let latest = set([depth(1), chest(1)])
        let changes = FormTrend.compareLatest(to: latest, among: [chestSet, depthSet])
        #expect(Set(changes.map(\.check)) == Set([.squatDepth, .squatChestDrop]))
    }
}
