import CoreML
import Foundation

/// What the optional exercise classifier concluded about a captured set.
nonisolated enum ExerciseRecognition: Equatable {
    /// Recognition is switched off, or this build has no trained model.
    case notAttempted
    /// Enough confident windows agreed on one supported exercise.
    case recognized(ExerciseKind, agreement: Double)
    /// The windows disagreed, were not confident, or favored "other" or "none".
    case uncertain
}

/// Which recognizer the app uses, in order of preference.
nonisolated enum RecognitionMethod: Equatable {
    /// A Create ML action classifier on Vision keypoint sequences.
    case keypointModel
    /// A trained classifier on joint-angle window features.
    case angleModel
    /// Hand-written rules on the same joint-angle features; needs no trained model.
    case angleRules
    case unavailable
}

nonisolated struct ClassifierPrediction: Equatable, Sendable {
    let label: String
    let confidence: Double
}

/// Classifies one window of Vision body keypoints. Each frame is the 54 values of
/// `VNHumanBodyPoseObservation.keypointsMultiArray()` ([1, 3, 18], flattened in order).
nonisolated protocol ExerciseClassifying: AnyObject {
    var windowLength: Int { get }
    /// Pose frames per second the model was trained on.
    var frameRate: Double { get }
    func classify(window: [[Float]]) throws -> ClassifierPrediction
}

/// Turns per-window predictions into one decision for the set. It only names an exercise when
/// most windows confidently agree; otherwise Plumb keeps the exercise the person chose.
nonisolated enum ExerciseRecognizer {
    static let keypointCount = 54
    static let minimumWindowConfidence = 0.8
    static let minimumAgreement = 0.6
    static let maximumWindows = 40

    static func recognize(_ frames: [PoseFrame],
                          using classifier: any ExerciseClassifying) -> ExerciseRecognition {
        let length = classifier.windowLength
        let poses = resample(frames, rate: classifier.frameRate)
        guard length > 0, poses.count >= length else { return .uncertain }

        var starts = Array(stride(from: 0, through: poses.count - length, by: max(1, length / 2)))
        if starts.count > maximumWindows {
            let step = Double(starts.count - 1) / Double(maximumWindows - 1)
            starts = (0..<maximumWindows).map { starts[Int((Double($0) * step).rounded())] }
        }

        let predictions = starts.compactMap {
            try? classifier.classify(window: Array(poses[$0..<($0 + length)]))
        }
        return decide(predictions)
    }

    /// One decision from per-window predictions: a supported exercise only when at least
    /// `minimumAgreement` of the classified windows name it with `minimumWindowConfidence`.
    static func decide(_ predictions: [ClassifierPrediction]) -> ExerciseRecognition {
        var votes: [String: Int] = [:]
        for prediction in predictions where prediction.confidence >= minimumWindowConfidence {
            votes[prediction.label, default: 0] += 1
        }
        let ranked = votes.sorted { $0.value > $1.value }
        guard !predictions.isEmpty, let winner = ranked.first,
              ranked.dropFirst().first?.value != winner.value else { return .uncertain }
        let agreement = Double(winner.value) / Double(predictions.count)
        guard agreement >= minimumAgreement,
              let definition = ExerciseDefinition.definition(forClassifierLabel: winner.key) else {
            return .uncertain
        }
        return .recognized(definition.kind, agreement: agreement)
    }

    /// Takes the pose nearest each tick at `rate` Hz so windows match the training frame rate.
    /// A tick with no pose within one tick is zero-filled, as for a frame without a person.
    static func resample(_ frames: [PoseFrame], rate: Double) -> [[Float]] {
        guard let first = frames.first, let last = frames.last, rate > 0 else { return [] }
        let empty = [Float](repeating: 0, count: keypointCount)
        let tickCount = Int(((last.time - first.time) * rate).rounded(.down)) + 1
        var result: [[Float]] = []
        result.reserveCapacity(tickCount)
        var index = 0
        for tick in 0..<tickCount {
            let time = first.time + Double(tick) / rate
            while index + 1 < frames.count,
                  abs(frames[index + 1].time - time) <= abs(frames[index].time - time) {
                index += 1
            }
            let frame = frames[index]
            if abs(frame.time - time) <= 1 / rate, let keypoints = frame.keypoints,
               keypoints.count == keypointCount {
                result.append(keypoints)
            } else {
                result.append(empty)
            }
        }
        return result
    }
}

nonisolated enum ExerciseClassifierError: Error, Equatable {
    case unsupportedModel(String)
    case wrongWindow
    case noProbabilities
}

/// Runs a Create ML action classifier on the iPhone. The app ships without one until the team
/// trains it with tools/exercise-classifier; then `PlumbExerciseClassifier.mlmodel` is added to
/// the app target and Xcode compiles it into the bundle.
nonisolated final class CoreMLExerciseClassifier: ExerciseClassifying, @unchecked Sendable {
    static let bundledModelName = "PlumbExerciseClassifier"
    /// Create ML's default when a model carries no Plumb frame-rate metadata.
    static let createMLDefaultFrameRate = 30.0

    let windowLength: Int
    let frameRate: Double
    private let model: MLModel
    private let inputName: String
    private let inputShape: [NSNumber]
    private let dataType: MLMultiArrayDataType
    private let probabilitiesName: String

    init(model: MLModel) throws {
        let description = model.modelDescription
        guard let input = description.inputDescriptionsByName.values.first(where: { $0.type == .multiArray }),
              let constraint = input.multiArrayConstraint else {
            throw ExerciseClassifierError.unsupportedModel("no pose array input")
        }
        let shape = constraint.shape.map(\.intValue)
        guard shape.count == 3, shape[0] > 0, shape[1] == 3, shape[2] == 18 else {
            throw ExerciseClassifierError.unsupportedModel("pose input shape \(shape) is not [window, 3, 18]")
        }
        let probabilities = description.predictedProbabilitiesName
            ?? description.outputDescriptionsByName.values.first { $0.type == .dictionary }?.name
        guard let probabilities else { throw ExerciseClassifierError.noProbabilities }
        let metadata = description.metadata[.creatorDefinedKey] as? [String: String]

        self.model = model
        self.inputName = input.name
        self.inputShape = constraint.shape
        self.dataType = constraint.dataType
        self.probabilitiesName = probabilities
        self.windowLength = shape[0]
        self.frameRate = metadata?["plumb.targetFrameRate"].flatMap(Double.init)
            ?? Self.createMLDefaultFrameRate
    }

    /// The trained model compiled into the app, or nil when none ships with this build.
    static func bundled(in bundle: Bundle = .main) -> CoreMLExerciseClassifier? {
        guard let url = bundle.url(forResource: bundledModelName, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else { return nil }
        return try? CoreMLExerciseClassifier(model: model)
    }

    func classify(window: [[Float]]) throws -> ClassifierPrediction {
        guard window.count == windowLength,
              window.allSatisfy({ $0.count == ExerciseRecognizer.keypointCount }) else {
            throw ExerciseClassifierError.wrongWindow
        }
        let poses = try MLMultiArray(shape: inputShape, dataType: dataType)
        for (frameIndex, keypoints) in window.enumerated() {
            for (valueIndex, value) in keypoints.enumerated() {
                poses[frameIndex * ExerciseRecognizer.keypointCount + valueIndex] = NSNumber(value: value)
            }
        }
        let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(multiArray: poses)])
        let output = try model.prediction(from: input)
        guard let probabilities = output.featureValue(for: probabilitiesName)?.dictionaryValue,
              let best = probabilities.max(by: { $0.value.doubleValue < $1.value.doubleValue }) else {
            throw ExerciseClassifierError.noProbabilities
        }
        return ClassifierPrediction(label: "\(best.key)", confidence: best.value.doubleValue)
    }
}
