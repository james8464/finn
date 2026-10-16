import Foundation
import Testing
@testable import Finn

/// Vision poses recorded on a Mac from the repository's generated videos (tools/replay/fixtures),
/// replayed through the analysis without a simulator. Skipped when the fixtures are not on disk.
nonisolated struct FixtureReplayTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "tools/replay/fixtures")

    private static var available: Bool {
        FileManager.default.fileExists(atPath: fixtures.appending(path: "squat-six-reps-poses.json").path)
    }

    private func poses(_ name: String) throws -> [PoseFrame] {
        try JSONDecoder().decode([PoseFrame].self, from: Data(contentsOf: Self.fixtures.appending(path: name)))
    }

    /// The recording loses the athlete for three frames right after the sixth rep. The set window
    /// used to end at that rep's top and drop it.
    @Test(.enabled(if: available)) func sixClearSquatsAreSixReps() throws {
        let frames = try poses("squat-six-reps-poses.json")
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) else {
            Issue.record("Expected the six-rep recording to be measured")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    /// Covered feet never reach the side rubric, which reads the hip against the ankle: no depth in
    /// leg lengths and no posture advice. The hips still show each squat (since 15 October).
    @Test(.enabled(if: available)) func coveredFeetAreCountedFromTheHipsWithoutAdvice() throws {
        let frames = try poses("squat-feet-hidden-poses.json")
        #expect(EvidenceGate.assess(SetWindow.active(frames, requirement: .squat), requirement: .squat).isRejected)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) else {
            Issue.record("Covered feet: the squats are counted from the hips")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == ExerciseDefinition.squatTrunk.rubricVersion)
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
    }
}
