// Trains Finn's exercise classifier with Create ML on a Mac (Apple silicon, Xcode installed).
//
//   xcrun swift tools/exercise-classifier/train_exercise_classifier.swift <dataset> <output.mlmodel>
//       [--iterations 80] [--frame-rate 15] [--window 30]
//
// <dataset> is the folder written by prepare_clips.py: train/<label>/*.mov and, when a
// participant was held out, validation/<label>/*.mov. The model learns from Vision body-pose
// sequences extracted from the clips, not from the pixels. The frame rate and window must match
// what the app feeds it: Finn samples poses at about 15 frames per second, so the defaults
// give two-second windows. Both values are stored in the model's metadata, which the app reads.

import CoreML
import CreateML
import Foundation

struct Options {
    var dataset: URL
    var output: URL
    var iterations = 80
    var frameRate = 15.0
    var window = 30
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(2)
}

func parseOptions(_ arguments: [String]) -> Options {
    var positional: [String] = []
    var options: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        if argument == "--help" || argument == "-h" {
            print("usage: train_exercise_classifier.swift <dataset> <output.mlmodel> "
                  + "[--iterations 80] [--frame-rate 15] [--window 30]")
            exit(0)
        }
        if argument.hasPrefix("--") {
            guard index + 1 < arguments.count else { fail("\(argument) needs a value") }
            options[argument] = arguments[index + 1]
            index += 2
        } else {
            positional.append(argument)
            index += 1
        }
    }
    guard positional.count == 2 else { fail("expected <dataset> and <output.mlmodel>; see --help") }
    var result = Options(dataset: URL(fileURLWithPath: positional[0]),
                         output: URL(fileURLWithPath: positional[1]))
    for (key, value) in options {
        switch key {
        case "--iterations": result.iterations = Int(value) ?? 0
        case "--frame-rate": result.frameRate = Double(value) ?? 0
        case "--window": result.window = Int(value) ?? 0
        default: fail("unknown option \(key)")
        }
    }
    guard result.iterations > 0, result.frameRate > 0, result.window > 0 else {
        fail("--iterations, --frame-rate and --window must be positive numbers")
    }
    guard result.output.pathExtension == "mlmodel" else { fail("output must end in .mlmodel") }
    return result
}

/// Counts clips per label folder, so an empty or missing class fails before training starts.
func clipCounts(in directory: URL) -> [String: Int] {
    let manager = FileManager.default
    guard let labels = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    else { return [:] }
    var counts: [String: Int] = [:]
    for label in labels where label.hasDirectoryPath {
        let videos = (try? manager.contentsOfDirectory(at: label, includingPropertiesForKeys: nil)) ?? []
        counts[label.lastPathComponent] = videos.filter {
            ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased())
        }.count
    }
    return counts
}

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
let trainURL = options.dataset.appending(path: "train", directoryHint: .isDirectory)
let validationURL = options.dataset.appending(path: "validation", directoryHint: .isDirectory)
let trainCounts = clipCounts(in: trainURL)
guard !trainCounts.isEmpty else { fail("no label folders in \(trainURL.path)") }
if let empty = trainCounts.first(where: { $0.value == 0 }) { fail("\(empty.key) has no training clips") }
let validationCounts = clipCounts(in: validationURL)
let heldOut = !validationCounts.isEmpty

print("Training clips: " + trainCounts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
    .joined(separator: ", "))
if heldOut {
    print("Validation clips (held-out participants): "
          + validationCounts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
            .joined(separator: ", "))
} else {
    print("warning: no validation folder. Create ML will hold out random clips, and clips cut from "
          + "the same recording can land on both sides, so the validation score will look too good.")
}

let parameters = MLActionClassifier.ModelParameters(
    validation: heldOut ? .dataSource(.labeledDirectories(at: validationURL)) : .split(strategy: .automatic),
    maximumIterations: options.iterations,
    predictionWindowSize: options.window,
    augmentationOptions: [.horizontalFlip],
    algorithm: .stgcn,
    targetFrameRate: options.frameRate
)

let started = Date()
print("Extracting poses and training. This can take several minutes per hundred clips.")
let classifier: MLActionClassifier
do {
    classifier = try MLActionClassifier(trainingData: .labeledDirectories(at: trainURL),
                                        parameters: parameters)
} catch {
    fail("training failed: \(error)")
}

let trainingAccuracy = 1 - classifier.trainingMetrics.classificationError
let validationAccuracy = 1 - classifier.validationMetrics.classificationError
let validationLabel = heldOut ? "held-out participants" : "random clips (optimistic)"
print(String(format: "Training accuracy: %.3f", trainingAccuracy))
print(String(format: "Validation accuracy on %@: %.3f", validationLabel, validationAccuracy))
print("Validation confusion (true label × predicted label):")
print(classifier.validationMetrics.confusionDataFrame.description)

let trainedAt = ISO8601DateFormatter().string(from: Date())
let metadata = MLModelMetadata(
    author: "Finn team",
    shortDescription: "Recognizes Finn exercises from Vision body-pose windows. Trained \(trainedAt) "
        + "on \(trainCounts.values.reduce(0, +)) clips; validation accuracy "
        + String(format: "%.3f", validationAccuracy) + " on \(validationLabel). Not a technique judge.",
    version: "1",
    additional: [
        "finn.targetFrameRate": String(options.frameRate),
        "finn.predictionWindow": String(options.window),
        "finn.labels": trainCounts.keys.sorted().joined(separator: ","),
        "finn.trainedAt": trainedAt,
        "finn.trainingClips": trainCounts.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: ","),
        "finn.validation": validationLabel,
        "finn.validationAccuracy": String(format: "%.3f", validationAccuracy),
    ]
)

do {
    try classifier.write(to: options.output, metadata: metadata)
} catch {
    fail("could not write \(options.output.path): \(error)")
}
let report: [String: Any] = [
    "trainedAt": trainedAt,
    "seconds": Int(Date().timeIntervalSince(started)),
    "trainingClips": trainCounts,
    "validationClips": validationCounts,
    "validation": validationLabel,
    "trainingAccuracy": trainingAccuracy,
    "validationAccuracy": validationAccuracy,
    "frameRate": options.frameRate,
    "window": options.window,
    "iterations": options.iterations,
]
let reportURL = options.output.deletingPathExtension().appendingPathExtension("report.json")
if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: reportURL)
}
print("Wrote \(options.output.path) and \(reportURL.lastPathComponent).")
print("To ship it, copy the .mlmodel to Finn/Finn/FinnExerciseClassifier.mlmodel and rebuild.")
