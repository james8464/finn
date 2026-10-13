import Foundation

/// Facts measured on each rep of a set, beyond the count: for pull-ups and muscle-ups, whether
/// the chin passed the hands, whether the arms were straight at the start of the rep, and how
/// much the body swung. Each check is a camera measurement from the side, not a judgment of
/// technique; when a joint it needs is not tracked, it says nothing.
nonisolated enum FormChecks {
    /// Elbow angle from which an arm counts as straight at the bottom of a pull-up.
    static let straightArmDegrees = 150.0
    /// Hip travel, forward and back, above which the body is said to swing (share of arm length).
    static let swingShare = 0.35

    static func sentences(for analysis: SetAnalysis, frames: [PoseFrame],
                          definition: ExerciseDefinition) -> [String] {
        switch definition.kind {
        case .pullUp, .muscleUp: pullChecks(analysis, frames: frames, definition: definition)
        case .bodyweightSquat, .pushUp, .staticLunge, .stiffLegDeadlift: []
        }
    }

    private static func pullChecks(_ analysis: SetAnalysis, frames: [PoseFrame],
                                   definition: ExerciseDefinition) -> [String] {
        guard !analysis.reps.isEmpty,
              case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else { return [] }
        var sentences: [String] = []
        let total = analysis.reps.count

        // Chin above the hands at the top of each rep (the bar itself is not tracked).
        if definition.kind == .pullUp {
            let tops = analysis.reps.map { ExerciseAnalyzer.deepestFrame(of: $0, in: frames, as: definition) }
            let judged = zip(analysis.reps, tops).compactMap { rep, frame -> (Int, Bool)? in
                guard let frame, let chin = chinAboveHands(frame) else { return nil }
                return (rep.number, chin)
            }
            if judged.count * 2 >= total {
                let missed = judged.filter { !$0.1 }.map(\.0)
                sentences.append(missed.isEmpty
                    ? "Chin above your hands in all \(judged.count) reps Plumb could check."
                    : "Chin above your hands in \(judged.count - missed.count) of \(judged.count) reps; not in \(list(missed)).")
            }
        }

        // Straight arms at the hang before each rep: the frame with the lowest shoulders between
        // the previous rep's end and this rep's start.
        let starts = analysis.reps.enumerated().compactMap { index, rep -> (Int, Double)? in
            let from = index == 0 ? (frames.first?.time ?? 0) : analysis.reps[index - 1].endTime
            let hang = frames.filter { $0.time >= from && $0.time <= rep.startTime + 0.05 }
                .compactMap { frame -> (PoseFrame, Double)? in
                    guard let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                          shoulder.confidence >= EvidenceRubric.minimumJointConfidence else { return nil }
                    return (frame, shoulder.y)
                }
                .max { $0.1 < $1.1 }?.0
            return hang.flatMap { elbowAngle($0, side: side) }.map { (rep.number, $0) }
        }
        if starts.count * 2 >= total {
            let bent = starts.filter { $0.1 < straightArmDegrees }.map(\.0)
            sentences.append(bent.isEmpty
                ? "Arms straight at the start of every rep."
                : "Arms not fully straight at the start of \(list(bent)).")
        }

        // Swing: how far the hips travel forward and back during the set.
        if let swing = swing(frames, side: side), swing >= swingShare {
            sentences.append("Your hips swung about \(Int((swing * 100).rounded()))% of your arm length forward and back. A still body makes each rep count the same.")
        }
        return sentences
    }

    /// Nose above the higher hand, when the nose and at least one wrist are tracked.
    static func chinAboveHands(_ frame: PoseFrame) -> Bool? {
        guard let nose = frame.joints[.nose], nose.confidence >= EvidenceRubric.minimumJointConfidence else {
            return nil
        }
        let wrists = [frame.joints[.leftWrist], frame.joints[.rightWrist]].compactMap { $0 }
            .filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        guard let hands = wrists.map(\.y).min() else { return nil }
        return nose.y < hands
    }

    private static func elbowAngle(_ frame: PoseFrame, side: BodySide) -> Double? {
        guard let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
              let elbow = frame.joints[JointRole.elbow.joint(on: side)],
              let wrist = frame.joints[JointRole.wrist.joint(on: side)],
              min(shoulder.confidence, elbow.confidence, wrist.confidence) >= EvidenceRubric.minimumJointConfidence
        else { return nil }
        return ExerciseAnalyzer.angle(from: shoulder, vertex: elbow, to: wrist, aspectRatio: frame.aspectRatio)
    }

    /// Spread of hip position across the set (10th to 90th percentile), over the arm length.
    private static func swing(_ frames: [PoseFrame], side: BodySide) -> Double? {
        let points = frames.compactMap { frame -> (hipX: Double, arm: Double)? in
            guard let hip = frame.joints[JointRole.hip.joint(on: side)],
                  let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                  let wrist = frame.joints[JointRole.wrist.joint(on: side)],
                  min(hip.confidence, shoulder.confidence, wrist.confidence) >= EvidenceRubric.minimumJointConfidence
            else { return nil }
            let arm = hypot(shoulder.x - wrist.x, (shoulder.y - wrist.y) * frame.aspectRatio)
            return (hip.x, arm)
        }
        guard points.count >= 10 else { return nil }
        let xs = points.map(\.hipX).sorted()
        let arms = points.map(\.arm).sorted()
        let arm = arms[Int(Double(arms.count - 1) * 0.9)]
        guard arm > 0 else { return nil }
        return (xs[Int(Double(xs.count - 1) * 0.9)] - xs[Int(Double(xs.count - 1) * 0.1)]) / arm
    }

    private static func list(_ reps: [Int]) -> String {
        let names = reps.map { "rep \($0)" }
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }
}
