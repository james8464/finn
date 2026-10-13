import Foundation
import Testing
@testable import Plumb

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
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: .squat) else {
            Issue.record("Expected the six-rep recording to be measured")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    @Test(.enabled(if: available)) func coveredFeetAreStillRefused() throws {
        let frames = try poses("squat-feet-hidden-poses.json")
        guard case .insufficientView = ExerciseAnalyzer.analyze(frames, as: .squat) else {
            Issue.record("Covered feet must be refused")
            return
        }
    }
}
