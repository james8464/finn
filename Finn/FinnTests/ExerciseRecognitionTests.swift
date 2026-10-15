import AVFoundation
import CoreML
import Foundation
import Testing
@testable import Finn

struct ExerciseRecognizerTests {
    @Test func confidentAgreementNamesTheExercise() {
        let classifier = ScriptedClassifier { _ in ("push_up", 0.95) }
        #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 6), using: classifier)
                == .recognized(.pushUp, agreement: 1))
    }

    @Test func lowConfidenceWindowsDoNotVote() {
        // Five windows; only two are confident, below the 60% agreement needed.
        let classifier = ScriptedClassifier { index in index.isMultiple(of: 3) ? ("squat", 0.9) : ("squat", 0.5) }
        #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 6), using: classifier) == .uncertain)
        #expect(classifier.calls == 5)
    }

    @Test func otherAndNoneNeverSelectAnAnalyzer() {
        for label in ["other", "none", "jumping_jack"] {
            let classifier = ScriptedClassifier { _ in (label, 0.99) }
            #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 6), using: classifier) == .uncertain)
        }
    }

    @Test func tiedVotesAreUncertain() {
        let classifier = ScriptedClassifier { index in
            index < 2 ? ("squat", 0.9) : index < 4 ? ("push_up", 0.9) : ("squat", 0.3)
        }
        #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 6), using: classifier) == .uncertain)
    }

    @Test func tooShortOrFailingInputIsUncertain() {
        let classifier = ScriptedClassifier { _ in ("squat", 0.99) }
        #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 1), using: classifier) == .uncertain)
        #expect(ExerciseRecognizer.recognize([], using: classifier) == .uncertain)
        let failing = ScriptedClassifier(fails: true) { _ in ("squat", 0.99) }
        #expect(ExerciseRecognizer.recognize(keypointFrames(seconds: 6), using: failing) == .uncertain)
    }

    @Test func longSetsAreSampledWithBoundedWindows() {
        let classifier = ScriptedClassifier { _ in ("squat", 0.99) }
        _ = ExerciseRecognizer.recognize(keypointFrames(seconds: 120), using: classifier)
        #expect(classifier.calls == ExerciseRecognizer.maximumWindows)
        #expect(classifier.windowSizes.allSatisfy { $0 == classifier.windowLength })
    }

    @Test func resamplingPicksNearestPoseAndZeroFillsGaps() {
        let marked: (Float) -> [Float] = { [Float](repeating: $0, count: 54) }
        let frames = [
            PoseFrame(time: 0.00, subjectCount: 1, joints: [:], keypoints: marked(1)),
            PoseFrame(time: 0.06, subjectCount: 1, joints: [:], keypoints: marked(2)),
            PoseFrame(time: 0.13, subjectCount: 1, joints: [:], keypoints: marked(3)),
            PoseFrame(time: 0.60, subjectCount: 1, joints: [:], keypoints: marked(4)),
        ]
        let poses = ExerciseRecognizer.resample(frames, rate: 10)
        #expect(poses.count == 7)
        #expect(poses.map { $0[0] } == [1, 3, 3, 0, 0, 4, 4])
    }

    private func keypointFrames(seconds: Double) -> [PoseFrame] {
        stride(from: 0.0, through: seconds, by: 1 / 15).map {
            PoseFrame(time: $0, subjectCount: 1, joints: [:],
                      keypoints: [Float](repeating: 0.5, count: 54))
        }
    }
}

/// Core ML checks against a constant-output fixture built by tools/exercise-classifier/
/// make_test_fixture.py. The fixture was never trained; it only has a Create ML action
/// classifier's interface and always answers push_up with probability 0.92.
struct CoreMLExerciseClassifierTests {
    @Test func readsWindowAndFrameRateFromTheModel() throws {
        let classifier = try fixture()
        #expect(classifier.windowLength == 30)
        #expect(classifier.frameRate == 15)
    }

    @Test func runsPredictionAndReadsProbabilities() throws {
        let classifier = try fixture()
        let prediction = try classifier.classify(window: Array(repeating: [Float](repeating: 0.2, count: 54),
                                                               count: 30))
        #expect(prediction.label == "push_up")
        #expect(abs(prediction.confidence - 0.92) < 0.001)
    }

    @Test func rejectsWindowsOfTheWrongSize() throws {
        let classifier = try fixture()
        #expect(throws: ExerciseClassifierError.wrongWindow) {
            try classifier.classify(window: Array(repeating: [Float](repeating: 0, count: 54), count: 12))
        }
        #expect(throws: ExerciseClassifierError.wrongWindow) {
            try classifier.classify(window: Array(repeating: [Float](repeating: 0, count: 40), count: 30))
        }
    }

    @Test func recognizerUsesTheCoreMLModelEndToEnd() throws {
        let frames = stride(from: 0.0, through: 5, by: 1.0 / 15).map {
            PoseFrame(time: $0, subjectCount: 1, joints: [:], keypoints: [Float](repeating: 0.4, count: 54))
        }
        #expect(ExerciseRecognizer.recognize(frames, using: try fixture()) == .recognized(.pushUp, agreement: 1))
    }

    @Test func bundledModelLoadsWhenTheTeamAddsOne() {
        // No trained model ships until the team adds Finn/Finn/FinnExerciseClassifier.mlmodel.
        guard let classifier = CoreMLExerciseClassifier.bundled() else { return }
        #expect(classifier.windowLength > 0)
        #expect(classifier.frameRate > 0)
    }

    private func fixture() throws -> CoreMLExerciseClassifier {
        let url = try #require(Bundle(for: FixtureBundleToken.self)
            .url(forResource: "ConstantPushUpClassifierFixture", withExtension: "mlmodelc"))
        return try CoreMLExerciseClassifier(model: MLModel(contentsOf: url))
    }
}

@MainActor
struct RecognitionSessionTests {
    @Test func recognizedExerciseReplacesTheChoice() async throws {
        let (model, source) = makeModel(classifier: ScriptedClassifier { _ in ("push_up", 0.95) },
                                        recognizes: true)
        model.selectedExercise = .bodyweightSquat
        await capture(model, source, pushUpTrace(reps: 6))
        #expect(model.recognition == .recognized(.pushUp, agreement: 1))
        #expect(model.resultExercise == .pushUp)
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected a measured push-up set")
            return
        }
        #expect(analysis.rubricVersion == "push-up-side-v7")
        #expect(model.currentSession?.sets.last?.exercise == .pushUp)
    }

    @Test func uncertainRecognitionFallsBackToTheChoice() async throws {
        let (model, source) = makeModel(classifier: ScriptedClassifier { _ in ("other", 0.95) },
                                        recognizes: true)
        model.selectedExercise = .pushUp
        await capture(model, source, pushUpTrace(reps: 6))
        #expect(model.recognition == .uncertain)
        #expect(model.resultExercise == .pushUp)
    }

    @Test func switchedOffOrMissingModelUsesTheChoiceWithoutTrying() async throws {
        let classifier = ScriptedClassifier { _ in ("squat", 0.99) }
        let (model, source) = makeModel(classifier: classifier, recognizes: false)
        model.selectedExercise = .pushUp
        await capture(model, source, pushUpTrace(reps: 6))
        #expect(model.recognition == .notAttempted)
        #expect(model.resultExercise == .pushUp)
        #expect(classifier.calls == 0)

        let (unequipped, unequippedSource) = makeModel(classifier: nil, recognizes: true, rules: false)
        #expect(!unequipped.usesExerciseRecognition)
        #expect(unequipped.recognitionMethod == .unavailable)
        unequipped.selectedExercise = .pushUp
        await capture(unequipped, unequippedSource, pushUpTrace(reps: 6))
        #expect(unequipped.recognition == .notAttempted)
    }

    @Test func rulesAreOnByDefaultAndTheTrainedModelIsOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnRecognitionPrefs-\(UUID().uuidString)"))
        let preferences = FinnPreferences(defaults: defaults)
        let first = WorkoutSessionModel(source: RecognitionPoseSource(),
                                        exerciseClassifier: ScriptedClassifier { _ in ("squat", 0.99) },
                                        preferences: preferences)
        #expect(first.recognizesExercise)
        #expect(!first.usesTrainedModel)
        #expect(first.recognitionMethod == .angleRules)
        first.recognizesExercise = false
        first.usesTrainedModel = true
        #expect(first.recognitionMethod == .keypointModel)
        let second = WorkoutSessionModel(source: RecognitionPoseSource(), exerciseClassifier: nil,
                                         preferences: preferences)
        #expect(!second.recognizesExercise)
        #expect(second.usesTrainedModel)
        // Without a model in the build, the rules still run.
        #expect(second.recognitionMethod == .angleRules)
    }

    private func makeModel(classifier: ScriptedClassifier?, recognizes: Bool,
                           rules: Bool = true) -> (WorkoutSessionModel, RecognitionPoseSource) {
        let defaults = UserDefaults(suiteName: "FinnRecognition-\(UUID().uuidString)")!
        let preferences = FinnPreferences(defaults: defaults)
        preferences.recognizesExercise = recognizes
        preferences.usesTrainedModel = classifier != nil
        let source = RecognitionPoseSource()
        return (WorkoutSessionModel(source: source, exerciseClassifier: classifier, angleClassifier: nil,
                                    ruleClassifier: rules ? AngleRuleClassifier() : nil,
                                    preferences: preferences), source)
    }

    private func capture(_ model: WorkoutSessionModel, _ source: RecognitionPoseSource,
                         _ frames: [PoseFrame]) async {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in frames { source.emit(frame) }
        await model.endSet()
    }
}

private final class FixtureBundleToken {}

/// Returns scripted predictions by window index; records each call.
nonisolated private final class ScriptedClassifier: ExerciseClassifying, @unchecked Sendable {
    let windowLength = 30
    let frameRate = 15.0
    private let fails: Bool
    private let script: (Int) -> (String, Double)
    private(set) var calls = 0
    private(set) var windowSizes: [Int] = []

    init(fails: Bool = false, script: @escaping (Int) -> (String, Double)) {
        self.fails = fails
        self.script = script
    }

    func classify(window: [[Float]]) throws -> ClassifierPrediction {
        defer { calls += 1 }
        windowSizes.append(window.count)
        if fails { throw ExerciseClassifierError.noProbabilities }
        let (label, confidence) = script(calls)
        return ClassifierPrediction(label: label, confidence: confidence)
    }
}

@MainActor
private final class RecognitionPoseSource: PoseStreaming {
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
