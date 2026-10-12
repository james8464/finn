import AVFoundation
import Foundation
import Testing
@testable import Plumb

@MainActor
struct MultiExerciseSessionTests {
    @Test func selectedPushUpIsMeasuredWithPushUpRubricAndSaved() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbMultiExercise-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        model.selectedExercise = .pushUp

        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in pushUpTrace(reps: 6) { source.emit(frame) }
        await model.endSet()

        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected a measured push-up set, got \(String(describing: model.result))")
            return
        }
        #expect(analysis.rubricVersion == "push-up-side-v4")
        #expect(analysis.reps.count == 6)
        #expect(model.resultExercise == .pushUp)
        #expect(try store.load().first?.sets.first?.exercise == .pushUp)
    }

    @Test func captureKeepsTheExerciseItStartedWith() async throws {
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source)
        model.selectedExercise = .stiffLegDeadlift
        await model.startPreview()
        await model.beginSet(countdown: 0)
        model.selectedExercise = .bodyweightSquat
        for frame in hingeTrace(reps: 5) { source.emit(frame) }
        await model.endSet()
        #expect(model.resultExercise == .stiffLegDeadlift)
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected a measured hinge set")
            return
        }
        #expect(analysis.reps.count == 5)
    }

    @Test func comparisonUsesThePreviousSetOfTheSameExercise() async throws {
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source)

        model.selectedExercise = .bodyweightSquat
        await capture(model, source, squatTrace(amplitude: 0.20))
        model.selectedExercise = .pushUp
        await capture(model, source, pushUpTrace(reps: 6))
        #expect(model.comparison == nil)
        #expect(model.comparisonGap == .differentExercise)

        model.selectedExercise = .bodyweightSquat
        await capture(model, source, squatTrace(amplitude: 0.13))
        let comparison = try #require(model.comparison)
        #expect(comparison.exercise == .bodyweightSquat)
        #expect(comparison.rangeDirection == .shorter)
        #expect(comparison.firstSetID == model.currentSession?.sets.first?.id)
        #expect(model.comparisonGap == nil)
    }

    @Test func noRepsMessageNamesTheSelectedExercise() async throws {
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source)
        model.selectedExercise = .staticLunge
        await capture(model, source, lungeTrace(reps: 6, bend: 0))
        #expect({
            if case .insufficientView(let message) = model.result {
                return message.hasPrefix(ExerciseDefinition.staticLunge.copy.noCompleteReps)
            }
            return false
        }())
    }

    @Test func framingCheckUsesTheSelectedExerciseJoints() async throws {
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source)
        model.selectedExercise = .pushUp
        await model.startPreview()
        for index in 0..<5 { source.emit(squatFrame(time: Double(index) * 0.1, hipY: 0.42)) }
        for _ in 0..<30 where model.framingStatus == .checking {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.framingStatus == .adjustPosition)
        for frame in pushUpTrace(reps: 1).prefix(5) { source.emit(frame) }
        for _ in 0..<30 where model.framingStatus != .landmarksVisible {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.framingStatus == .landmarksVisible)
        await model.cancel()
    }

    @Test func comparisonAndShareTextUseExerciseVocabulary() {
        let session = UUID()
        let first = summary(session: session, exercise: .pushUp, range: 80)
        let second = summary(session: session, exercise: .pushUp, range: 60)
        let comparison = SetComparison.compare(first, second)
        #expect(comparison?.rangeDirection == .shorter)
        #expect(comparison?.exercise == .pushUp)
        #expect(SetComparison.compare(first, summary(session: session, exercise: .bodyweightSquat,
                                                     range: 0.4)) == nil)

        let text = SetShareSummary.text(for: second.analysis, cue: nil, cueDismissed: false,
                                        comparison: comparison, exercise: .pushUp)
        #expect(text.hasPrefix("Plumb push-up sets"))
        #expect(text.contains("Camera-measured elbow bend was smaller in set 2."))
        #expect(!text.localizedCaseInsensitiveContains("squat"))
        #expect(SetShareSummary.statement(for: .longer, exercise: .bodyweightSquat)
                == "Camera-measured range was longer in set 2.")
    }

    private func capture(_ model: WorkoutSessionModel, _ source: StubPoseSource,
                         _ frames: [PoseFrame]) async {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in frames { source.emit(frame) }
        await model.endSet()
    }

    private func squatTrace(amplitude: Double) -> [PoseFrame] {
        (0...120).map { index in
            squatFrame(time: Double(index) * 0.1,
                       hipY: 0.42 + amplitude * (1 - cos(2 * .pi * Double(index % 20) / 20)) / 2)
        }
    }

    private func summary(session: UUID, exercise: ExerciseKind, range: Double) -> SetSummary {
        let reps = (1...6).map {
            RepMetric(number: $0, startTime: Double($0) * 2, endTime: Double($0) * 2 + 1.5,
                      relativeRange: range)
        }
        return SetSummary(id: UUID(), sessionID: session, capturedAt: .now, bodySide: .left,
                          analysis: SetAnalysis(reps: reps, confidence: 0.9,
                                                rubricVersion: exercise.definition.rubricVersion),
                          cue: nil, cueResponse: .unanswered, exercise: exercise)
    }
}

@MainActor
private final class StubPoseSource: PoseStreaming {
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
