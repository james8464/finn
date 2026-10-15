import Foundation

/// what Siri says and shows for "How did my last set go in Plumb": the latest measured set, with
/// its exercise, measured reps, time and the observation Plumb recorded, word for word. Built from
/// the saved history only, so it never invents a number.
nonisolated struct LastSetReport: Equatable {
    let exercise: ExerciseKind
    let reps: Int
    let capturedAt: Date
    /// the observation Plumb kept for this set, exactly as saved. Nil when there was none, or when
    /// the person marked it as not relevant.
    let observation: String?
    /// the joints were clear in only part of the set: reps counted, no observation possible.
    let partlyVisible: Bool

    /// Siri's answer when the history holds no measured set.
    static var nothingYet: String {
        String(localized: "You haven't measured a set in Plumb yet. Say \"Start a squat set in Plumb\" to begin.",
               comment: "Siri, when the history is empty")
    }
    /// Siri's answer when the history cannot be read, for instance while the iPhone is locked
    /// (the file is protected until the first unlock).
    static var unavailable: String {
        String(localized: "Plumb can't read your history right now. Unlock your iPhone and ask again.",
               comment: "Siri, when the history file cannot be read")
    }

    /// the most recent set across all saved sessions, or nil when nothing was measured yet.
    static func latest(in sessions: [WorkoutSessionSummary]) -> LastSetReport? {
        guard let set = sessions.flatMap(\.sets).max(by: { $0.capturedAt < $1.capturedAt }) else {
            return nil
        }
        let kept = set.cueResponse == .notRelevant ? nil : set.cue?.observation
        return LastSetReport(exercise: set.exercise, reps: set.analysis.reps.count,
                             capturedAt: set.capturedAt, observation: kept,
                             partlyVisible: set.partlyVisible == true)
    }

    var exerciseName: String { exercise.definition.copy.name }

    /// "8 measured reps", the same wording as the shared result.
    var repsText: String {
        reps == 1 ? String(localized: "1 measured rep", comment: "Siri, rep count")
                  : String(localized: "\(reps) measured reps", comment: "Siri, rep count")
    }

    /// "today at 9:40", "yesterday at 18:05", or "12 Oct at 18:05".
    func whenText(now: Date = Date(), calendar: Calendar = .current) -> String {
        let locale = calendar.locale ?? .current
        let time = capturedAt.formatted(.dateTime.hour().minute().locale(locale))
        if calendar.isDate(capturedAt, inSameDayAs: now) {
            return String(localized: "today at \(time)", comment: "Siri, when the set was measured")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(capturedAt, inSameDayAs: yesterday) {
            return String(localized: "yesterday at \(time)", comment: "Siri, when the set was measured")
        }
        let day = capturedAt.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        return String(localized: "\(day) at \(time)", comment: "Siri, when the set was measured; day then time")
    }

    /// the observation line, honest when there is none.
    var observationText: String {
        if let observation { return observation }
        if partlyVisible {
            return String(localized: "Plumb saw the joints clearly for only part of the set, so it made no observation.",
                          comment: "Siri, partly visible set")
        }
        return String(localized: "No clear observation in that set.", comment: "Siri, set without observation")
    }

    /// the sentence Siri reads.
    func spoken(now: Date = Date(), calendar: Calendar = .current) -> String {
        let when = whenText(now: now, calendar: calendar)
        let opening = String(localized: "Your last set in Plumb: \(exerciseName), \(repsText), \(when).",
                             comment: "Siri, first sentence of the last-set answer")
        if let observation {
            return String(localized: "\(opening) Plumb noted: \(observation)",
                          comment: "Siri, the observation recorded for the set, word for word")
        }
        return "\(opening) \(observationText)"
    }
}
