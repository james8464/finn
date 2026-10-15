import Foundation

/// What a badge is for. Every badge rests on measured sets saved on this iPhone; none is decorative.
nonisolated enum BadgeKind: Codable, Hashable, Sendable {
    /// One measured set, whatever it showed.
    case firstSet
    /// Sets on three different days within seven days.
    case threeDaysInAWeek
    /// A fully visible set with at least `SetComparison.minimumReps` reps and nothing to correct.
    case cleanSet
    /// A measured set of each of the six exercises.
    case allSixExercises
    /// More reps in one set of this exercise than in any earlier set of it.
    case repRecord(ExerciseKind)
    /// Two comparable sets of the same exercise where the median range grew clearly.
    case longerRange(ExerciseKind)

    /// Every badge the app can show, in the order of the Awards screen. The per-exercise ones follow
    /// `ExerciseKind.allCases`.
    static var all: [BadgeKind] {
        [.firstSet, .threeDaysInAWeek, .cleanSet, .allSixExercises]
            + ExerciseKind.allCases.map(BadgeKind.repRecord)
            + ExerciseKind.allCases.map(BadgeKind.longerRange)
    }

    var title: String {
        switch self {
        case .firstSet: String(localized: "First set")
        case .threeDaysInAWeek: String(localized: "Three days in a week")
        case .cleanSet: String(localized: "Nothing to fix")
        case .allSixExercises: String(localized: "All six")
        case .repRecord(let kind): String(localized: "\(kind.definition.copy.name) record")
        case .longerRange(let kind): String(localized: "Longer \(kind.definition.copy.rangeNoun), \(kind.chipName.lowercased())")
        }
    }

    /// How to earn it, for the locked state. One sentence, no promise.
    var rule: String {
        switch self {
        case .firstSet: String(localized: "Finish one measured set.")
        case .threeDaysInAWeek: String(localized: "Measure sets on three different days within seven days.")
        case .cleanSet: String(localized: "A fully visible set of \(SetComparison.minimumReps) reps or more with no observation to correct.")
        case .allSixExercises: String(localized: "Measure at least one set of each of the six exercises.")
        case .repRecord: String(localized: "Beat your highest rep count for this exercise. Needs an earlier set to beat.")
        case .longerRange: String(localized: "Two comparable sets in one session where your median range grew by 15% or more.")
        }
    }

    var symbol: String {
        switch self {
        case .firstSet: "1.circle"
        case .threeDaysInAWeek: "calendar.badge.checkmark"
        case .cleanSet: "checkmark.seal"
        case .allSixExercises: "square.grid.3x2"
        case .repRecord: "arrow.up.right"
        case .longerRange: "arrow.up.and.down"
        }
    }
}

/// A badge the person has, with when and how. Saved as is; never recomputed from a changed rule.
nonisolated struct EarnedBadge: Codable, Equatable, Identifiable, Sendable {
    let kind: BadgeKind
    let earnedAt: Date
    /// One sentence with the measured facts behind it, written when it was earned.
    let detail: String
    /// The set that earned it. Only that set's result celebrates it: a badge the history already
    /// supported when the app first evaluated it is written down without a fête (15 October: a
    /// 14-rep push-up set announced "First set, 7 pull-up reps" and an old record).
    var setID: UUID? = nil

    var id: BadgeKind { kind }
}

/// The rules, as pure functions of the saved history. `evaluate` returns everything the history
/// supports; `BadgeLedger` keeps what was already given so nothing is given twice.
nonisolated enum BadgeRules {
    /// Ratio of medians that counts as a clearly longer range, the same as `SetComparison`.
    static let longerRangeRatio = 1.15

    /// Every badge the history earns, each dated by the set that earned it.
    static func evaluate(history: [WorkoutSessionSummary], calendar: Calendar = .current) -> [EarnedBadge] {
        let sets = history.flatMap(\.sets)
            .filter { !$0.analysis.reps.isEmpty }
            .sorted { $0.capturedAt < $1.capturedAt }
        guard !sets.isEmpty else { return [] }
        var earned: [EarnedBadge] = []

        if let first = sets.first {
            earned.append(EarnedBadge(kind: .firstSet, earnedAt: first.capturedAt,
                                      detail: Self.text(reps: first.analysis.reps.count, of: first.exercise)
                                      + String(localized: ", measured on this iPhone."), setID: first.id))
        }

        if let badge = threeDaysInAWeek(sets, calendar: calendar) { earned.append(badge) }

        if let clean = sets.first(where: { set in
            set.analysis.reps.count >= SetComparison.minimumReps && set.cue == nil
                && set.partlyVisible != true && (set.issues ?? []).isEmpty
        }) {
            earned.append(EarnedBadge(kind: .cleanSet, earnedAt: clean.capturedAt,
                                      detail: Self.text(reps: clean.analysis.reps.count, of: clean.exercise)
                                      + String(localized: ", every joint clear, no pattern to correct."),
                                      setID: clean.id))
        }

        var seen: Set<ExerciseKind> = []
        for set in sets {
            seen.insert(set.exercise)
            if seen.count == ExerciseKind.allCases.count {
                earned.append(EarnedBadge(kind: .allSixExercises, earnedAt: set.capturedAt,
                                          detail: String(localized: "Your sixth exercise was \(set.exercise.definition.copy.shareNoun)."),
                                          setID: set.id))
                break
            }
        }

        for kind in ExerciseKind.allCases {
            let ofKind = sets.filter { $0.exercise == kind }
            if let badge = repRecord(ofKind, kind: kind) { earned.append(badge) }
            if let badge = longerRange(ofKind, kind: kind) { earned.append(badge) }
        }
        return earned
    }

    private static func threeDaysInAWeek(_ sets: [SetSummary], calendar: Calendar) -> EarnedBadge? {
        var days: [Date] = []
        for set in sets {
            let day = calendar.startOfDay(for: set.capturedAt)
            if days.last != day { days.append(day) }
        }
        guard days.count >= 3 else { return nil }
        for index in 2..<days.count {
            let span = calendar.dateComponents([.day], from: days[index - 2], to: days[index]).day ?? .max
            if span <= 6 {
                let third = sets.first { calendar.startOfDay(for: $0.capturedAt) == days[index] }
                let names = days[(index - 2)...index].map { $0.formatted(.dateTime.weekday(.wide)) }
                return EarnedBadge(kind: .threeDaysInAWeek, earnedAt: third?.capturedAt ?? days[index],
                                   detail: String(localized: "Sets on \(names[0]), \(names[1]) and \(names[2]), within seven days."),
                                   setID: third?.id)
            }
        }
        return nil
    }

    /// The first set of the exercise that beats every earlier one. A single set is no record.
    private static func repRecord(_ sets: [SetSummary], kind: ExerciseKind) -> EarnedBadge? {
        guard sets.count >= 2 else { return nil }
        var best = sets[0].analysis.reps.count
        var record: (SetSummary, Int)?
        for set in sets.dropFirst() {
            let reps = set.analysis.reps.count
            if reps > best {
                record = (set, best)
                best = reps
            }
        }
        guard let (set, previous) = record else { return nil }
        return EarnedBadge(kind: .repRecord(kind), earnedAt: set.capturedAt,
                           detail: Self.text(reps: set.analysis.reps.count, of: kind)
                           + String(localized: ", up from \(previous) in your best earlier set."), setID: set.id)
    }

    /// The first pair of comparable sets (same session, same side, enough reps, fully visible) where
    /// the later median range is at least 15% longer.
    private static func longerRange(_ sets: [SetSummary], kind: ExerciseKind) -> EarnedBadge? {
        let visible = sets.filter { $0.partlyVisible != true }
        for (index, later) in visible.enumerated().dropFirst() {
            for earlier in visible[..<index].reversed() {
                guard let comparison = SetComparison.compare(earlier, later) else { continue }
                if comparison.rangeDirection == .longer {
                    let unit = kind.definition.copy.rangeNoun
                    let percent = Int(((comparison.secondMedianRange / comparison.firstMedianRange) - 1) * 100)
                    return EarnedBadge(kind: .longerRange(kind), earnedAt: later.capturedAt,
                                       detail: String(localized: "Median \(unit) \(percent)% longer than in your previous set of that session, over \(later.analysis.reps.count) reps."),
                                       setID: later.id)
                }
            }
        }
        return nil
    }

    private static func text(reps: Int, of kind: ExerciseKind) -> String {
        let noun = kind.definition.copy.shareNoun
        return reps == 1 ? String(localized: "1 \(noun) rep") : String(localized: "\(reps) \(noun) reps")
    }
}
