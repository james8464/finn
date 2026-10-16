import CoreML
import Foundation

/// Classifies one window of joint-angle features into a classifier label
/// (`squat`, `push_up`, `static_lunge`, `stiff_leg_deadlift`, `other`, or `none`).
nonisolated protocol AngleWindowClassifying: AnyObject {
    func classify(_ features: PoseWindowFeatures) throws -> ClassifierPrediction
}

/// Recognises the exercise from Vision's 2D joint angles with hand-written rules: which joint
/// bends (elbow, knee, hip), by how much, and how the torso is tilted (horizontal for a push-up,
/// upright for a squat or lunge, tipping forward for a stiff-leg deadlift). It needs no training
/// data. Its thresholds are starting values checked on synthetic and public side-view clips only.
nonisolated final class AngleRuleClassifier: AngleWindowClassifying {
    static let abstain = "unknown"

    init() {}

    func classify(_ features: PoseWindowFeatures) throws -> ClassifierPrediction {
        guard let label = Self.label(for: features) else {
            return ClassifierPrediction(label: Self.abstain, confidence: 0)
        }
        return ClassifierPrediction(label: label, confidence: 1)
    }

    static func label(for features: PoseWindowFeatures) -> String? {
        AngleRules.label(for: features)
    }
}

/// Runs an angle-window classifier over a set and votes like the keypoint classifier does.
nonisolated enum AngleRecognizer {
    static func recognise(_ frames: [PoseFrame],
                          using classifier: any AngleWindowClassifying) -> ExerciseRecognition {
        var windows = PoseWindowFeatureExtractor.windows(frames)
        if windows.count > ExerciseRecognizer.maximumWindows {
            let step = Double(windows.count - 1) / Double(ExerciseRecognizer.maximumWindows - 1)
            windows = (0..<ExerciseRecognizer.maximumWindows).map {
                windows[Int((Double($0) * step).rounded())]
            }
        }
        let predictions = windows.compactMap { window -> ClassifierPrediction? in
            guard let features = PoseWindowFeatureExtractor.features(window) else { return nil }
            return try? classifier.classify(features)
        }
        return ExerciseRecognizer.decide(mergingHangingWindows(predictions))
    }

    /// A muscle-up starts with a pull, so many of its windows look like a pull-up. Pull-up and
    /// muscle-up windows vote together as one family; the set is a muscle-up when at least a
    /// quarter of that family's windows saw the shoulders pass above the hands.
    static func mergingHangingWindows(_ predictions: [ClassifierPrediction]) -> [ClassifierPrediction] {
        let family = predictions.filter { $0.label == "pull_up" || $0.label == "muscle_up" }
        guard !family.isEmpty else { return predictions }
        let muscleUps = family.filter { $0.label == "muscle_up" }.count
        let label = Double(muscleUps) >= 0.25 * Double(family.count) ? "muscle_up" : "pull_up"
        return predictions.map { prediction in
            prediction.label == "pull_up" || prediction.label == "muscle_up"
                ? ClassifierPrediction(label: label, confidence: prediction.confidence) : prediction
        }
    }
}

/// A Core ML classifier trained on `PoseWindowFeatures` (tools/exercise-classifier/angle-model).
/// The app looks for `FinnAngleClassifier.mlmodel` in its target; none ships by default.
nonisolated final class CoreMLAngleClassifier: AngleWindowClassifying, @unchecked Sendable {
    static let bundledModelName = "FinnAngleClassifier"

    private let model: MLModel
    private let inputNames: Set<String>
    private let probabilitiesName: String

    init(model: MLModel) throws {
        let description = model.modelDescription
        let inputs = Set(description.inputDescriptionsByName.keys)
        guard !inputs.isEmpty, inputs.isSubset(of: Set(PoseWindowFeatures.featureNames)) else {
            throw ExerciseClassifierError.unsupportedModel("inputs \(inputs.sorted()) are not angle features")
        }
        let probabilities = description.predictedProbabilitiesName
            ?? description.outputDescriptionsByName.values.first { $0.type == .dictionary }?.name
        guard let probabilities else { throw ExerciseClassifierError.noProbabilities }
        self.model = model
        self.inputNames = inputs
        self.probabilitiesName = probabilities
    }

    static func bundled(in bundle: Bundle = .main) -> CoreMLAngleClassifier? {
        guard let url = bundle.url(forResource: bundledModelName, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else { return nil }
        return try? CoreMLAngleClassifier(model: model)
    }

    func classify(_ features: PoseWindowFeatures) throws -> ClassifierPrediction {
        let values = features.values.filter { inputNames.contains($0.key) }
        let input = try MLDictionaryFeatureProvider(dictionary: values.mapValues { $0 as NSNumber })
        let output = try model.prediction(from: input)
        guard let probabilities = output.featureValue(for: probabilitiesName)?.dictionaryValue,
              let best = probabilities.max(by: { $0.value.doubleValue < $1.value.doubleValue }) else {
            throw ExerciseClassifierError.noProbabilities
        }
        return ClassifierPrediction(label: "\(best.key)", confidence: best.value.doubleValue)
    }
}
