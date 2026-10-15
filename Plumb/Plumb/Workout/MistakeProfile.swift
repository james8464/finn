import Foundation

/// something a measured set showed, saved with its summary so Plumb can learn which patterns come
/// back most often for this person. Each one is a measured fact about the set, not a judgement of
/// technique.
nonisolated enum SetIssue: String, Codable, CaseIterable, Sendable {
    /// movements that left the top and came back without reaching the bottom
    case shallowMovements
    /// full movements faster or slower than a rep may take
    case outsideTempo
    /// the set ended partway through a movement
    case unfinishedLastRep
    /// the last two reps had a clearly shorter range than the first two (the end-of-set observation)
    case rangeDropped
    /// the last two reps showed a posture change against the first two: torso tilt, hip alignment or
    /// knee bend, depending on the exercise (`PostureRule`)
    case postureChanged
    /// a rep was clearly faster than the first reps of the set (said live)
    case spedUp
    /// the camera saw the person at an angle instead of from the side
    case angledView
    /// the joints were clear in only 65 to 80% of the set (`PartialVisibility`)
    case partlyVisible
    // a form fault seen on at least two reps (`FormCheck`), with the check's own name
    case pushUpHipsSag
    case pushUpHipsPike
    case pushUpDepth
    case squatChestDrop
    case squatDepth
    case lungeTorsoLean
    case lungeFrontKnee
    case deadliftKneeBend
    case deadliftHinge

    /// the form check this issue records, if it is one
    var formCheck: FormCheck? { FormCheck(rawValue: rawValue) }

    /// issues of one measured set, from its diagnostics, its change observation (`CueSelector`), its
    /// form faults and its live events
    static func issues(diagnostics: MovementDiagnostics?, cue: Cue?, findings: [FormFinding] = [],
                       spedUp: Bool) -> [SetIssue] {
        var issues: [SetIssue] = []
        if let diagnostics {
            if diagnostics.shallow > 0 { issues.append(.shallowMovements) }
            if diagnostics.outsideTempo > 0 { issues.append(.outsideTempo) }
            if diagnostics.unfinished { issues.append(.unfinishedLastRep) }
            if diagnostics.angledView != nil { issues.append(.angledView) }
            if diagnostics.partialVisibility != nil { issues.append(.partlyVisible) }
        }
        switch cue?.kind {
        case .rangeDecreased?: issues.append(.rangeDropped)
        case .torsoTiltIncreased?, .hipDropIncreased?, .kneeBendIncreased?, .swingIncreased?:
            issues.append(.postureChanged)
        case .pushUpHipsSag?, .pushUpHipsPike?, .pushUpDepth?, .squatChestDrop?, .squatDepth?, .lungeTorsoLean?,
             .lungeFrontKnee?, .deadliftKneeBend?, .deadliftHinge?, nil:
            break
        }
        issues += findings.compactMap { SetIssue(rawValue: $0.check.rawValue) }
        if spedUp { issues.append(.spedUp) }
        return issues
    }

    /// the pattern, in a few words
    func title(for definition: ExerciseDefinition) -> String {
        switch self {
        case .shallowMovements: String(localized: "Movements too shallow to count")
        case .outsideTempo: String(localized: "Movements too fast or too slow to count")
        case .unfinishedLastRep: String(localized: "Last movement not finished")
        case .rangeDropped:
            String(localized: "\(definition.copy.rangeNoun.prefix(1).uppercased() + definition.copy.rangeNoun.dropFirst()) \(definition.copy.lessRange) at the end of the set")
        case .postureChanged: definition.posture.title
        case .spedUp: String(localized: "Reps faster than your first ones")
        case .angledView: String(localized: "Filmed at an angle")
        case .partlyVisible: String(localized: "Joints not always in view")
        case .pushUpHipsSag, .pushUpHipsPike, .pushUpDepth, .squatChestDrop, .squatDepth, .lungeTorsoLean,
             .lungeFrontKnee, .deadliftKneeBend, .deadliftHinge:
            formCheck?.title ?? ""
        }
    }

    /// what to keep in mind on the next set
    func focus(for definition: ExerciseDefinition) -> String {
        switch self {
        case .shallowMovements:
            String(localized: "Reach the same depth on every rep. Plumb needs \(definition.formattedDepth(definition.phases.reachBottom)) to count one.")
        case .outsideTempo:
            String(localized: "Keep each rep between \(definition.phases.minimumDuration.formatted(.number.precision(.fractionLength(1)))) and \(definition.phases.maximumDuration.formatted(.number.precision(.fractionLength(0)))) seconds.")
        case .unfinishedLastRep: String(localized: "Come back to your starting position before the set ends.")
        case .rangeDropped: definition.copy.nextAction
        case .postureChanged: definition.posture.nextAction
        case .spedUp: String(localized: "Keep the pace of your first reps.")
        case .angledView: String(localized: "Turn so your side faces the camera.")
        case .partlyVisible: String(localized: "Keep your whole body in view, with even light.")
        case .pushUpHipsSag, .pushUpHipsPike, .pushUpDepth, .squatChestDrop, .squatDepth, .lungeTorsoLean,
             .lungeFrontKnee, .deadliftKneeBend, .deadliftHinge:
            formCheck?.nextAction ?? ""
        }
    }
}

/// the pattern that comes back most often in a person's recent sets of one exercise, so the app can
/// point it out before the next set and recognise it when it returns. Counts only measured sets
/// saved on this iPhone; nothing is compared with other people.
nonisolated struct MistakeProfile: Equatable, Sendable {
    /// recent sets of the exercise that are looked at
    static let recentSets = 10
    /// a pattern must appear in at least this many of those sets...
    static let minimumSets = 2
    /// ...and in at least this share of them
    static let minimumShare = 0.3

    let exercise: ExerciseKind
    let issue: SetIssue
    /// sets that showed the issue, among `outOf` recent sets of the exercise
    let sets: Int
    let outOf: Int

    /// the most frequent issue in the latest sets of `exercise`, or nil when none comes back often
    /// enough. Ties go to the issue seen most recently.
    static func make(history: [WorkoutSessionSummary], exercise: ExerciseKind) -> MistakeProfile? {
        let recent = history.flatMap(\.sets)
            .filter { $0.exercise == exercise && $0.issues != nil }
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(recentSets)
        guard !recent.isEmpty else { return nil }
        var best: (issue: SetIssue, count: Int, latest: Int)?
        for issue in SetIssue.allCases {
            let matching = recent.enumerated().filter { $0.element.issues?.contains(issue) == true }
            guard let latest = matching.first?.offset else { continue }
            let candidate = (issue: issue, count: matching.count, latest: latest)
            if let current = best,
               current.count > candidate.count || (current.count == candidate.count && current.latest <= candidate.latest) {
                continue
            }
            best = candidate
        }
        guard let best, best.count >= minimumSets,
              Double(best.count) / Double(recent.count) >= minimumShare else { return nil }
        return MistakeProfile(exercise: exercise, issue: best.issue, sets: best.count, outOf: recent.count)
    }

    /// for example "Movements too shallow to count in 3 of your last 5 squat sets."
    var summary: String {
        let definition = exercise.definition
        return String(localized: "\(issue.title(for: definition)) in \(sets) of your last \(outOf) \(definition.copy.shareNoun) sets.")
    }

    var focus: String { issue.focus(for: exercise.definition) }
}
