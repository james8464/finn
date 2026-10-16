import AVFoundation
import CoreML
import Foundation
import Testing
@testable import Finn

/// The rules are checked on synthetic side-view sequences. The generator and the rules were
/// written by the same person, so passing here is necessary, not evidence of real accuracy.
struct AngleRuleRecognitionTests {
    private let exercises: [(String, ExerciseKind)] = [
        ("squat", .bodyweightSquat), ("push_up", .pushUp),
        ("static_lunge", .staticLunge), ("stiff_leg_deadlift", .stiffLegDeadlift),
    ]

    @Test func rulesNameEachExerciseOnSyntheticSets() {
        var rng = SyntheticRandom(seed: 101)
        for (label, kind) in exercises {
            let hits = (0..<30).filter { _ in
                let frames = SyntheticExerciseMotion.sequence(label: label, using: &rng)
                if case .recognized(kind, _) = AngleRecognizer.recognize(frames, using: AngleRuleClassifier()) {
                    return true
                }
                return false
            }.count
            #expect(hits >= 27, "\(label): \(hits) of 30")
        }
    }

    @Test func rulesStayUncertainForOtherMovementAndStillness() {
        var rng = SyntheticRandom(seed: 202)
        for label in ["other", "none"] {
            let uncertain = (0..<30).filter { _ in
                let frames = SyntheticExerciseMotion.sequence(label: label, using: &rng)
                return AngleRecognizer.recognize(frames, using: AngleRuleClassifier()) == .uncertain
            }.count
            #expect(uncertain >= 27, "\(label): \(uncertain) of 30")
        }
    }

    @Test func squatWithoutTheFarAnkleIsNotGuessed() {
        var rng = SyntheticRandom(seed: 303)
        let full = SyntheticExerciseMotion.sequence(label: "squat", using: &rng)
        let farAnkle: BodyJoint = PoseWindowFeatureExtractor.trackedSide(in: full) == .left
            ? .rightAnkle : .leftAnkle
        let frames = full.map { frame in
            PoseFrame(time: frame.time, subjectCount: 1, joints: frame.joints.filter { $0.key != farAnkle },
                      aspectRatio: frame.aspectRatio)
        }
        // With one ankle left, the stance is unknown and a squat cannot be told from a lunge.
        let features = PoseWindowFeatureExtractor.windows(frames).compactMap(PoseWindowFeatureExtractor.features)
        #expect(features.allSatisfy { $0.stance == -1 })
        #expect(AngleRecognizer.recognize(frames, using: AngleRuleClassifier()) == .uncertain)
    }

    @Test func featuresNeedTheTrunkAndLegs() {
        var rng = SyntheticRandom(seed: 404)
        let frames = SyntheticExerciseMotion.sequence(label: "push_up", using: &rng)
        let windows = PoseWindowFeatureExtractor.windows(frames)
        #expect(windows.count >= 4)
        let armsOnly = windows[0].map { frame in
            PoseFrame(time: frame.time, subjectCount: 1, joints: frame.joints.filter {
                [.leftShoulder, .leftElbow, .leftWrist, .rightShoulder, .rightElbow, .rightWrist].contains($0.key)
            })
        }
        #expect(PoseWindowFeatureExtractor.features(armsOnly) == nil)
        #expect(PoseWindowFeatureExtractor.windows(Array(frames.prefix(10))).isEmpty)
    }

    @Test func angleModelLoaderRejectsAKeypointModel() throws {
        let url = try #require(Bundle(for: AngleFixtureToken.self)
            .url(forResource: "ConstantPushUpClassifierFixture", withExtension: "mlmodelc"))
        #expect(throws: ExerciseClassifierError.self) {
            try CoreMLAngleClassifier(model: MLModel(contentsOf: url))
        }
    }

    /// Runs only once the team adds a trained FinnAngleClassifier.mlmodel to the app target.
    @Test func bundledAngleModelRecognizesSyntheticSetsWhenPresent() {
        guard let model = CoreMLAngleClassifier.bundled() else { return }
        var rng = SyntheticRandom(seed: 606)
        for (label, kind) in exercises {
            let frames = SyntheticExerciseMotion.sequence(label: label, using: &rng)
            guard case .recognized(kind, _) = AngleRecognizer.recognize(frames, using: model) else {
                Issue.record("The bundled angle model missed a synthetic \(label)")
                continue
            }
        }
        let still = SyntheticExerciseMotion.sequence(label: "none", using: &rng)
        #expect(AngleRecognizer.recognize(still, using: model) == .uncertain)
    }
}

@MainActor
struct AngleRuleSessionTests {
    @Test func rulesRecognizeWhenNoModelShips() async throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnRules-\(UUID().uuidString)"))
        let preferences = FinnPreferences(defaults: defaults)
        preferences.recognizesExercise = true
        let source = RuleSessionSource()
        let model = WorkoutSessionModel(source: source, exerciseClassifier: nil, angleClassifier: nil,
                                        preferences: preferences)
        #expect(model.recognitionMethod == .angleRules)
        #expect(model.usesExerciseRecognition)
        model.selectedExercise = .bodyweightSquat
        var rng = SyntheticRandom(seed: 505)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in SyntheticExerciseMotion.sequence(label: "push_up", using: &rng) { source.emit(frame) }
        await model.endSet()
        guard case .recognized(.pushUp, _) = model.recognition else {
            Issue.record("Expected the rules to recognize a push-up, got \(model.recognition)")
            return
        }
        #expect(model.resultExercise == .pushUp)
    }
}

private final class AngleFixtureToken {}

@MainActor
private final class RuleSessionSource: PoseStreaming {
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
