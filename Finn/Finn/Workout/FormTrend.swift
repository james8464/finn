import Foundation

/// A change in the share of readable reps that triggered the same form check.
nonisolated struct FormTrendChange: Equatable, Sendable {
    enum Direction: Equatable, Sendable { case improved, worsened }

    let check: FormCheck
    let earlier: FormMeasurement
    let later: FormMeasurement
    let direction: Direction

    var sentence: String {
        let subject = check.subject
        let oldFaulty = earlier.faulty
        let oldJudged = earlier.judged
        let newFaulty = later.faulty
        let newJudged = later.judged
        switch direction {
        case .improved:
            return String(localized: "Your \(subject) check flagged \(newFaulty) of \(newJudged) reps, down from \(oldFaulty) of \(oldJudged) in the previous comparable set.")
        case .worsened:
            return String(localized: "Your \(subject) check flagged \(newFaulty) of \(newJudged) reps, up from \(oldFaulty) of \(oldJudged) in the previous comparable set.")
        }
    }
}

/// Compare recorded form evidence, never infer a change from a missing or unclear measurement.
nonisolated enum FormTrend {
    static let minimumJudgedReps = 4
    static let minimumShareChange = 0.30

    /// Checks with enough trustworthy readings to compare or index in saved history.
    static func eligibleMeasurements(in set: SetSummary) -> [FormMeasurement] {
        guard set.analysis.confidence >= EvidenceRubric.minimumJointConfidence,
              set.partlyVisible != true else { return [] }
        return (set.formMeasurements ?? []).filter {
            $0.check.exercise == set.exercise && $0.judged >= minimumJudgedReps
                && (0...$0.judged).contains($0.faulty) && $0.typical.isFinite
        }
    }

    static func isComparable(_ earlier: SetSummary, _ later: SetSummary) -> Bool {
        guard compatibleMetadata(earlier, later) else { return false }
        let priorChecks = Set(eligibleMeasurements(in: earlier).map(\.check))
        return eligibleMeasurements(in: later).contains { priorChecks.contains($0.check) }
    }

    /// Candidates are newest first. Each check uses its own latest eligible prior reading.
    static func compareLatest<S: Sequence>(to later: SetSummary,
                                           among earlier: S) -> [FormTrendChange] where S.Element == SetSummary {
        let current = eligibleMeasurements(in: later)
        var missing = Set(current.map(\.check))
        var prior: [FormCheck: FormMeasurement] = [:]
        for candidate in earlier {
            guard compatibleMetadata(candidate, later) else { continue }
            for measurement in eligibleMeasurements(in: candidate) where missing.contains(measurement.check) {
                prior[measurement.check] = measurement
                missing.remove(measurement.check)
            }
            if missing.isEmpty { break }
        }
        return current.compactMap { measurement in
            prior[measurement.check].flatMap { change($0, measurement) }
        }
    }

    static func compare(_ earlier: SetSummary, _ later: SetSummary) -> [FormTrendChange] {
        guard isComparable(earlier, later) else { return [] }

        let prior = Dictionary(eligibleMeasurements(in: earlier).map { ($0.check, $0) },
                               uniquingKeysWith: { first, _ in first })
        return eligibleMeasurements(in: later).compactMap { current in
            guard let previous = prior[current.check] else { return nil }
            return change(previous, current)
        }
    }

    private static func compatibleMetadata(_ earlier: SetSummary, _ later: SetSummary) -> Bool {
        earlier.id != later.id && earlier.exercise == later.exercise
            && earlier.cameraView == later.cameraView && earlier.bodySide == later.bodySide
            && earlier.analysis.rubricVersion == later.analysis.rubricVersion
    }

    private static func change(_ earlier: FormMeasurement,
                               _ later: FormMeasurement) -> FormTrendChange? {
        let difference = Double(later.faulty) / Double(later.judged)
            - Double(earlier.faulty) / Double(earlier.judged)
        guard abs(difference) >= minimumShareChange else { return nil }
        return FormTrendChange(check: later.check, earlier: earlier, later: later,
                               direction: difference < 0 ? .improved : .worsened)
    }
}
