// Trains Finn's joint-angle exercise classifier with Create ML and reports held-out accuracy.
//
//   train-angle-classifier <poses folder> <output folder> [--synthetic-per-class 250]
//
// Training rows are PoseWindowFeatures (the app's own code, compiled in by build.sh) computed
// from two sources: pose JSON files written by extract-poses from real videos, and synthetic
// side-view sequences from SyntheticExerciseMotion. Real videos are split by participant, so no
// held-out person appears in training. The rule-based recognizer is scored on the same sets.

import CoreML
import CreateML
import Foundation
import TabularData

struct PoseRecording: Codable {
    let source: String
    let exercise: String
    let label: String
    let subject: String
    let frames: [PoseFrame]
}

struct Recording {
    let id: String
    let label: String
    let origin: String      // "real" or "synthetic"
    let test: Bool
    let windows: [PoseWindowFeatures]
}

let exerciseLabels: Set = ["squat", "push_up", "static_lunge", "stiff_leg_deadlift"]
let allLabels = SyntheticExerciseMotion.labels

// MARK: Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
var syntheticPerClass = 250
if let index = arguments.firstIndex(of: "--synthetic-per-class"), index + 1 < arguments.count {
    syntheticPerClass = Int(arguments[index + 1]) ?? syntheticPerClass
    arguments.removeSubrange(index...(index + 1))
}
guard arguments.count == 2 else {
    print("usage: train-angle-classifier <poses folder> <output folder> [--synthetic-per-class N]")
    exit(2)
}
let posesFolder = URL(fileURLWithPath: arguments[0])
let outputFolder = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

func windowFeatures(_ frames: [PoseFrame]) -> [PoseWindowFeatures] {
    PoseWindowFeatureExtractor.windows(frames).compactMap(PoseWindowFeatureExtractor.features)
}

// MARK: Data

/// Held-out participants: every fourth subject number (004, 008, ..., 024).
func isTestSubject(_ subject: String) -> Bool {
    (Int(subject.split(separator: "_").last ?? "") ?? 0) % 4 == 0
}

/// Identical videos give identical poses. The Mendeley set has byte-identical files under two
/// subjects or two exercises, so recordings are grouped by their pose data before splitting.
func fingerprint(_ frames: [PoseFrame]) -> Int {
    var hasher = Hasher()
    hasher.combine(frames.count)
    for frame in frames.prefix(90) {
        hasher.combine(frame.time)
        for (joint, point) in frame.joints.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(joint.rawValue); hasher.combine(point.x); hasher.combine(point.y)
        }
    }
    return hasher.finalize()
}

var recordings: [Recording] = []
var realByFingerprint: [Int: [(PoseRecording, Bool)]] = [:]
let files = ((try? FileManager.default.contentsOfDirectory(at: posesFolder, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
let decoder = JSONDecoder()
for file in files {
    guard let recording = try? decoder.decode(PoseRecording.self, from: Data(contentsOf: file)) else {
        print("unreadable: \(file.lastPathComponent)")
        continue
    }
    realByFingerprint[fingerprint(recording.frames), default: []]
        .append((recording, isTestSubject(recording.subject)))
}
var droppedDuplicates: [String] = []
for group in realByFingerprint.values.sorted(by: { $0[0].0.source < $1[0].0.source }) {
    // Keep one copy; when a group spans both splits, keep it in training and drop the test copies.
    let kept = group.first { !$0.1 } ?? group[0]
    droppedDuplicates += group.filter { $0.0.source != kept.0.source }.map(\.0.source)
    recordings.append(Recording(id: kept.0.source, label: kept.0.label, origin: "real", test: kept.1,
                                windows: windowFeatures(kept.0.frames)))
}
let realCount = recordings.count
print("dropped \(droppedDuplicates.count) duplicate recordings")

var rng = SyntheticRandom(seed: 20261012)
for label in allLabels {
    for index in 0..<syntheticPerClass {
        let frames = SyntheticExerciseMotion.sequence(label: label, using: &rng)
        recordings.append(Recording(id: "synthetic-\(label)-\(index)", label: label, origin: "synthetic",
                                    test: index % 5 == 0, windows: windowFeatures(frames)))
    }
}
print("\(realCount) real recordings, \(recordings.count - realCount) synthetic")

func frame(for selected: [Recording]) -> DataFrame {
    var frame = DataFrame()
    let rows = selected.flatMap { recording in recording.windows.map { (recording.label, $0) } }
    frame.append(column: Column(name: "label", contents: rows.map(\.0)))
    for name in PoseWindowFeatures.featureNames {
        frame.append(column: Column(name: name, contents: rows.map { $0.1.values[name] ?? 0 }))
    }
    return frame
}

let training = recordings.filter { !$0.test }
let trainingFrame = frame(for: training)
print("training windows: \(trainingFrame.rows.count)")

// MARK: Train

let started = Date()
let classifier = try MLBoostedTreeClassifier(
    trainingData: trainingFrame, targetColumn: "label", featureColumns: PoseWindowFeatures.featureNames,
    parameters: .init(validation: .none, maxDepth: 6, maxIterations: 120, randomSeed: 7))
print(String(format: "trained in %.0f s", Date().timeIntervalSince(started)))
let model = classifier.model

// MARK: Evaluate

func predict(_ features: PoseWindowFeatures) -> (String, Double) {
    let input = try! MLDictionaryFeatureProvider(dictionary: features.values.mapValues { $0 as NSNumber })
    let output = try! model.prediction(from: input)
    let probabilities = output.featureValue(for: "labelProbability")?.dictionaryValue ?? [:]
    let best = probabilities.max { $0.value.doubleValue < $1.value.doubleValue }
    return (best.map { "\($0.key)" } ?? "?", best?.value.doubleValue ?? 0)
}

/// Same vote as the app (ExerciseRecognizer.decide): a supported exercise needs 60% of windows at
/// 0.8 confidence or more; anything else is "uncertain".
func decide(_ predictions: [(String, Double)]) -> String {
    // No measurable window: Vision lost the body, so no recognizer can decide ("uncertain" in the app).
    if predictions.isEmpty { return "no pose" }
    var votes: [String: Int] = [:]
    for (label, confidence) in predictions where confidence >= 0.8 { votes[label, default: 0] += 1 }
    let ranked = votes.sorted { $0.value > $1.value }
    guard !predictions.isEmpty, let winner = ranked.first, ranked.dropFirst().first?.value != winner.value,
          Double(winner.value) / Double(predictions.count) >= 0.6, exerciseLabels.contains(winner.key)
    else { return "uncertain" }
    return winner.key
}

struct Tally {
    var confusion: [String: [String: Int]] = [:]
    mutating func add(truth: String, predicted: String) { confusion[truth, default: [:]][predicted, default: 0] += 1 }
    func lines(labels: [String]) -> [String] {
        let predictedLabels = Set(confusion.values.flatMap(\.keys))
        return labels.compactMap { label in
            guard let row = confusion[label] else { return nil }
            let total = row.values.reduce(0, +)
            let correct = row[label] ?? 0
            let predictedAs = confusion.values.reduce(0) { $0 + ($1[label] ?? 0) }
            let precision = predictedAs > 0 ? String(format: "%.0f%%", 100 * Double(correct) / Double(predictedAs)) : "n/a"
            let others = row.filter { $0.key != label }.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            _ = predictedLabels
            return "| \(label) | \(correct) / \(total) (\(String(format: "%.0f%%", 100 * Double(correct) / Double(max(total, 1))))) | \(precision) | \(others) |"
        }
    }
}

/// Set-level truth: an exercise label, or "uncertain" for other and none.
func setTruth(_ label: String) -> String { exerciseLabels.contains(label) ? label : "uncertain" }

var report: [String] = []
var summary: [String: Any] = ["droppedDuplicates": droppedDuplicates]
let realTest = recordings.filter { $0.origin == "real" && $0.test }
report.append("Real data: \(realCount) side-view recordings after dropping \(droppedDuplicates.count) duplicates. "
              + "Held out: subjects 004, 008, 012, 016, 020, 024 (\(realTest.count) recordings). "
              + "Synthetic: \(syntheticPerClass) sequences per class, one in five held out.\n")
for origin in ["real", "synthetic"] {
    let tested = recordings.filter { $0.test && $0.origin == origin }
    var windowTally = Tally(), setTally = Tally(), ruleSetTally = Tally()
    for recording in tested {
        let predictions = recording.windows.map(predict)
        for (label, _) in predictions { windowTally.add(truth: recording.label, predicted: label) }
        setTally.add(truth: setTruth(recording.label), predicted: decide(predictions))
        let rules = recording.windows.map { (AngleRules.label(for: $0) ?? "unknown", 1.0) }
        ruleSetTally.add(truth: setTruth(recording.label), predicted: decide(rules))
    }
    let setLabels = Array(exerciseLabels).sorted() + ["uncertain", "no pose"]
    report.append("## Held-out \(origin) data: \(tested.count) recordings, \(tested.reduce(0) { $0 + $1.windows.count }) windows\n")
    report.append("Windows (2.5 s), trained model. Recall, then precision.\n")
    report.append("| Class | Correct / total | Precision | Most confused with |\n| --- | --- | --- | --- |")
    report += windowTally.lines(labels: allLabels)
    report.append("\nWhole sets, trained model with the app's vote (other and none should come out uncertain).\n")
    report.append("| Class | Correct / total | Precision | Most confused with |\n| --- | --- | --- | --- |")
    report += setTally.lines(labels: setLabels)
    report.append("\nWhole sets, rule-based recognizer (no training) on the same recordings.\n")
    report.append("| Class | Correct / total | Precision | Most confused with |\n| --- | --- | --- | --- |")
    report += ruleSetTally.lines(labels: setLabels)
    report.append("")
    summary[origin] = ["recordings": tested.count, "windowConfusion": windowTally.confusion,
                       "setConfusion": setTally.confusion, "ruleSetConfusion": ruleSetTally.confusion]
}

// Rules need no training, so every real recording is a fair test for them.
var allRealRules = Tally()
for recording in recordings where recording.origin == "real" {
    let rules = recording.windows.map { (AngleRules.label(for: $0) ?? "unknown", 1.0) }
    allRealRules.add(truth: setTruth(recording.label), predicted: decide(rules))
}
report.append("## Rule-based recognizer on all \(realCount) real recordings\n")
report.append("| Class | Correct / total | Precision | Most confused with |\n| --- | --- | --- | --- |")
report += allRealRules.lines(labels: Array(exerciseLabels).sorted() + ["uncertain", "no pose"])
summary["rulesAllReal"] = allRealRules.confusion

// MARK: Write

let metadata = MLModelMetadata(
    author: "Finn team",
    shortDescription: "Exercise classifier on joint-angle windows (PoseWindowFeatures). Trained on "
        + "Mendeley 10.17632/kgbb3yn47p.2 side-view videos (CC BY 4.0) and synthetic sequences. "
        + "Lunge and stiff-leg deadlift are synthetic only. Not a technique judge.",
    license: "Model trained on CC BY 4.0 data: Mendeley Data 10.17632/kgbb3yn47p.2",
    version: "1",
    additional: ["finn.features": PoseWindowFeatures.featureNames.joined(separator: ","),
                 "finn.window": "\(PoseWindowFeatureExtractor.windowDuration)",
                 "finn.trainedAt": ISO8601DateFormatter().string(from: Date())])
let modelURL = outputFolder.appending(path: "FinnAngleClassifier.mlmodel")
try? FileManager.default.removeItem(at: modelURL)
try classifier.write(to: modelURL, metadata: metadata)
let reportText = "# Finn angle classifier report\n\n" + report.joined(separator: "\n") + "\n"
try reportText.write(to: outputFolder.appending(path: "report.md"), atomically: true, encoding: .utf8)
let json = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputFolder.appending(path: "report.json"))
print(reportText)
print("wrote \(modelURL.path)")
