import AVFoundation
import Foundation
import Testing
@testable import Finn

@MainActor
struct MultiExerciseSessionTests {
    @Test func selectedPushUpIsMeasuredWithPushUpRubricAndSaved() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FinnMultiExercise-\(UUID().uuidString)", directoryHint: .isDirectory)
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
        #expect(analysis.rubricVersion == "push-up-side-v7")
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

    /// Squat is still selected (the default) and the person does push-ups. Recognition measures
    /// them as push-ups; the next set is then framed, counted live and stopped hands-free as a
    /// push-up, instead of as a squat again with a live count stuck at 0.
    @Test func aRecognizedExerciseBecomesTheChoiceForTheNextSet() async throws {
        let source = StubPoseSource()
        let preferences = FinnPreferences(defaults: UserDefaults(suiteName: "FinnCarryOver-\(UUID())")!)
        let model = WorkoutSessionModel(source: source, exerciseClassifier: nil, angleClassifier: nil,
                                        preferences: preferences)
        #expect(model.usesExerciseRecognition)
        #expect(model.selectedExercise == .bodyweightSquat)
        var rng = SyntheticRandom(seed: 505)
        let frames = SyntheticExerciseMotion.sequence(
            label: "push_up", settings: .init(duration: 20...20, maximumYawDegrees: 5, dropRate: 0...0), using: &rng)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in frames { source.emit(frame) }
        await model.endSet()
        guard case .recognized(.pushUp, _) = model.recognition else {
            Issue.record("Expected the push-ups to be recognized, got \(model.recognition)")
            return
        }
        #expect(model.resultExercise == .pushUp)
        #expect(model.selectedExercise == .pushUp)
        await model.startPreview()
        #expect(model.captureExercise == .pushUp)
        await model.cancel()
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

    /// Two push-up sets, the arm Vision followed changing between them (a front view gives either):
    /// the second set is compared with the first, never told it was filmed from the other side.
    @Test func aPushUpSetIsNotToldItsEarlierSetsWereFilmedFromTheOtherSide() async throws {
        let source = StubPoseSource()
        let model = WorkoutSessionModel(source: source)
        model.selectedExercise = .pushUp
        await capture(model, source, pushUps(reps: 6, bend: 80))
        await capture(model, source, pushUps(reps: 6, bend: 60).map(mirrored))
        let sides = model.currentSession?.sets.map(\.bodySide) ?? []
        #expect(sides == [.left, .right])
        #expect(model.comparisonGap != .differentSide)
        #expect(model.comparison?.rangeDirection == .shorter)
    }

    /// Side-view push-ups at 15 fps: a 2 s plank, then 1.6 s reps to the given bend.
    private func pushUps(reps: Int, bend: Double) -> [PoseFrame] {
        var frames: [PoseFrame] = []
        var time = 0.0
        while time < 2 + Double(reps) * 1.6 {
            let phase = time < 2 ? 0 : (time - 2).truncatingRemainder(dividingBy: 1.6) / 1.6
            frames.append(CaptureTraces.pushUpFrame(time: time, elbowBend: bend * (1 - cos(2 * .pi * phase)) / 2,
                                                    wristX: 0.62, wristY: 0.86))
            time += CaptureTraces.step
        }
        return frames
    }

    /// The same pose seen from the other side: left joints become right ones, mirrored in x.
    private func mirrored(_ frame: PoseFrame) -> PoseFrame {
        let pairs: [BodyJoint: BodyJoint] = [.leftWrist: .rightWrist, .leftElbow: .rightElbow,
                                             .leftShoulder: .rightShoulder, .leftHip: .rightHip]
        var joints: [BodyJoint: JointPoint] = [:]
        for (joint, point) in frame.joints {
            joints[pairs[joint] ?? joint] = JointPoint(x: 1 - point.x, y: point.y, confidence: point.confidence)
        }
        return PoseFrame(time: frame.time, subjectCount: frame.subjectCount, joints: joints, athleteTracking: .tracked)
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
        #expect(model.captureExercise == .pushUp)
        let requirement = model.captureExercise.definition.evidence
        let squatFrames = (0..<5).map { squatFrame(time: Double($0) * 0.1, hipY: 0.42) }
        #expect(EvidenceGate.previewStatus(squatFrames, requirement: requirement) == .adjustPosition)
        #expect(EvidenceGate.previewStatus(Array(pushUpTrace(reps: 1).prefix(5)),
                                           requirement: requirement) == .landmarksVisible)
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
        #expect(text.hasPrefix("Finn push-up sets"))
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
