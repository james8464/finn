import Foundation

/// what a strength chart counts. Finn measures reps today; load and hold time are ready for the
/// inputs and timed exercises that will record them
nonisolated enum StrengthMetric: Equatable {
    case reps, kilograms, seconds

    /// the metric Finn records for an exercise. Every exercise is counted in reps for now
    static func of(_ exercise: ExerciseKind) -> StrengthMetric { .reps }
}

nonisolated struct StrengthPoint: Equatable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// the person's best per session for one exercise, oldest first, and a straight-line projection
/// past the last session. The projection is an estimate, never a measurement or a target
nonisolated struct StrengthTrend: Equatable {
    let exercise: ExerciseKind
    let metric: StrengthMetric
    let points: [StrengthPoint]
    /// from the last real point to `horizon` later; empty until there is enough to fit a line
    let projection: [StrengthPoint]
    /// how many recent sessions the projection rests on
    let fittedSessions: Int

    /// the most recent sessions a projection is fitted to
    static let fitWindow = 8
    /// distinct training days needed before Finn projects anything
    static let minimumDays = 3
    static let horizonDays = 28

    var best: Double? { points.map(\.value).max() }

    static func make(for exercise: ExerciseKind, history: [WorkoutSessionSummary],
                     calendar: Calendar = .current) -> StrengthTrend {
        let points = history.compactMap { session -> StrengthPoint? in
            let best = session.sets.filter { $0.exercise == exercise }.map { $0.analysis.reps.count }.max()
            return best.map { StrengthPoint(date: session.startedAt, value: Double($0)) }
        }
        .sorted { $0.date < $1.date }
        let recent = Array(points.suffix(fitWindow))
        let days = Set(recent.map { calendar.startOfDay(for: $0.date) })
        guard days.count >= minimumDays, let last = recent.last, let slope = slopePerDay(recent),
              let end = calendar.date(byAdding: .day, value: horizonDays, to: last.date) else {
            return StrengthTrend(exercise: exercise, metric: .of(exercise), points: points,
                                 projection: [], fittedSessions: 0)
        }
        let projected = max(0, last.value + slope * Double(horizonDays))
        return StrengthTrend(exercise: exercise, metric: .of(exercise), points: points,
                             projection: [last, StrengthPoint(date: end, value: projected)],
                             fittedSessions: recent.count)
    }

    /// least-squares slope of value against days; nil when every point falls on one instant
    static func slopePerDay(_ points: [StrengthPoint]) -> Double? {
        guard let first = points.first?.date, points.count >= 2 else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(first) / 86_400 }
        let ys = points.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let spread = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard spread > 0 else { return nil }
        let covariance = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        return covariance / spread
    }
}
