import AVFoundation
import Foundation
import Testing
@testable import Plumb

/// 13 October: a push-up set refused at 79% joint coverage lost all its reps. Between 65 and 80%,
/// Plumb now counts the reps it saw, without advice or comparison, and marks the set partial.
struct PartialVisibilityTests {
    /// Six squats in which Vision misses the knee in one frame out of `everyNth`, as it does when
    /// a joint flickers all through a set.
    static func squats(missingKneeEvery everyNth: Int?, hiddenRep: Int? = nil) -> [PoseFrame] {
        CaptureTraces.squats(reps: 6, from: 0).enumerated().map { index, frame in
            var joints = frame.joints
            let rep = Int(frame.time / 2.0) + 1
            if let everyNth, index % everyNth == 0 { joints[.leftKnee] = nil }
            // Two frames out of three without the knee in this rep: short gaps, but mostly unclear.
            if rep == hiddenRep, index % 3 != 0 { joints[.leftKnee] = nil }
            return PoseFrame(time: frame.time, subjectCount: frame.subjectCount, joints: joints,
                             athleteTracking: frame.athleteTracking)
        }
    }

    @Test func coverageBetweenSixtyFiveAndEightyPercentIsPartlyVisible() throws {
        let frames = Self.squats(missingKneeEvery: 4)
        let evidence = ExerciseKind.bodyweightSquat.definition.evidence
        guard case .reject(.missingJoints) = EvidenceGate.assess(frames, requirement: evidence) else {
            Issue.record("Expected the full rule to refuse a set with the knee in 75% of frames")
            return
        }
        guard case .usable = EvidenceGate.assess(frames, requirement: evidence, allowsPartial: true) else {
            Issue.record("Expected the partial rule to accept it")
            return
        }
        let visibility = try #require(EvidenceGate.partialVisibility(frames, requirement: evidence))
        #expect(visibility.coverage == 74 || visibility.coverage == 75)
        #expect(visibility.weakest == .knee)

        #expect(EvidenceGate.partialVisibility(Self.squats(missingKneeEvery: 2), requirement: evidence) == nil)
        #expect(EvidenceGate.partialVisibility(Self.squats(missingKneeEvery: nil), requirement: evidence) == nil)
    }

    @Test func aPartlyVisibleSetCountsItsRepsAndSaysWhyThereIsNoAdvice() throws {
        let definition = ExerciseKind.bodyweightSquat.definition
        let (outcome, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(
            Self.squats(missingKneeEvery: 4), as: definition, trimsToSet: false)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected the reps to be counted, got \(outcome)")
            return
        }
        #expect(analysis.reps.count == 6)
        let partial = try #require(diagnostics?.partialVisibility)
        #expect(partial.weakest == .knee)
        let note = try #require(diagnostics?.explanation(for: definition, counted: analysis.reps.count))
        #expect(note.contains("couldn’t see your knee"))
        #expect(note.contains("gives no posture advice"))
    }

    /// The knee is lost for most of the sixth rep. The side rubric keeps five clear reps; the hips,
    /// seen all through, show the sixth, so it is counted too, from the hips and without advice.
    /// Until 15 October that rep was left out.
    @Test func aRepWithTheKneeHiddenIsCountedFromTheHips() throws {
        let definition = ExerciseKind.bodyweightSquat.definition
        let frames = Self.squats(missingKneeEvery: 4, hiddenRep: 6)
        let (outcome, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(frames, as: definition, trimsToSet: false)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected the reps to be counted, got \(outcome)")
            return
        }
        #expect(diagnostics?.countedFromHips == true)
        #expect(analysis.reps.count == 6)
        #expect(analysis.reps.map(\.number) == Array(1...6))
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
        #expect(EvidenceGate.partialVisibility(frames, requirement: definition.evidence) != nil)
    }

    /// The knee in only half the frames: no reading from the side, but the hips count the squats.
    @Test func belowSixtyFivePercentTheRepsAreCountedFromTheHips() {
        let frames = Self.squats(missingKneeEvery: 2)
        #expect(EvidenceGate.assess(frames, requirement: .squat, allowsPartial: true).isRejected)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: ExerciseKind.bodyweightSquat.definition)
        else {
            Issue.record("Expected the squats to be counted from the hips")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == ExerciseDefinition.squatTrunk.rubricVersion)
    }
}

@MainActor
struct PartialVisibilitySessionTests {
    @Test func aPartlyVisibleSetIsSavedWithoutAdviceOrComparison() async throws {
        let source = PartialTestSource()
        let defaults = try #require(UserDefaults(suiteName: "PlumbPartial-\(UUID())"))
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbPartial-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = WorkoutSessionModel(source: source,
                                        store: LocalSessionStore(url: directory.appending(path: "sessions.json")),
                                        preferences: PlumbPreferences(defaults: defaults))
        model.recognizesExercise = false

        // A clear set first, then a partly visible one.
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) { source.emit(frame) }
        await model.endSet()
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in PartialVisibilityTests.squats(missingKneeEvery: 4) { source.emit(frame) }
        await model.endSet()

        guard case .measured(let analysis, let cue) = model.result else {
            Issue.record("Expected the partly visible set to be measured, got \(String(describing: model.result))")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(cue == nil)
        #expect(model.movementNote?.contains("couldn’t see your knee") == true)
        #expect(model.comparison == nil)
        #expect(model.comparisonGap == .partlyVisible)
        let saved = try #require(model.currentSession?.sets.last)
        #expect(saved.partlyVisible == true)
        #expect(saved.issues?.contains(.partlyVisible) == true)
        #expect(model.currentSession?.sets.first?.partlyVisible == nil)
    }
}

private final class PartialTestSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) { continuation?.yield(frame) }
}
