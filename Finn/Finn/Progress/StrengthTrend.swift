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

/// how far ahead the person asks Finn to look
nonisolated enum ProgressHorizon: String, CaseIterable, Identifiable, Hashable {
    case oneWeek, twoWeeks, oneMonth, twoMonths

    var id: Self { self }

    /// the picker label and the words in "in 2 weeks"
    var phrase: String {
        switch self {
        case .oneWeek: String(localized: "1 week")
        case .twoWeeks: String(localized: "2 weeks")
        case .oneMonth: String(localized: "1 month")
        case .twoMonths: String(localized: "2 months")
        }
    }

    /// projected bars between today and the horizon: daily for a week, every other day for two,
    /// about weekly for the months
    var barCount: Int {
        switch self {
        case .oneWeek, .twoWeeks: 7
        case .oneMonth: 4
        case .twoMonths: 8
        }
    }

    func end(from today: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: today)
        let end: Date? = switch self {
        case .oneWeek: calendar.date(byAdding: .day, value: 7, to: day)
        case .twoWeeks: calendar.date(byAdding: .day, value: 14, to: day)
        case .oneMonth: calendar.date(byAdding: .month, value: 1, to: day)
        case .twoMonths: calendar.date(byAdding: .month, value: 2, to: day)
        }
        return end ?? day
    }
}

/// a straight line through best reps against training days, fitted by least squares
nonisolated struct StrengthFit: Equatable {
    /// the first workout's day, where the line's day count starts
    let origin: Date
    let intercept: Double
    let slopePerDay: Double

    func value(at date: Date, calendar: Calendar) -> Double {
        intercept + slopePerDay * Double(StrengthTrend.days(from: origin, to: date, calendar: calendar))
    }
}

/// where the line points by a chosen date. An estimate, never a measurement or a target
nonisolated struct StrengthProjection: Equatable {
    let horizon: ProgressHorizon
    /// whole reps, oldest first; the last falls on the horizon's date
    let points: [StrengthPoint]

    var target: Int { Int(points.last?.value ?? 0) }
}

/// the person's best set per workout for one exercise, oldest first, and the line through them
nonisolated struct StrengthTrend: Equatable {
    let exercise: ExerciseKind
    let metric: StrengthMetric
    let points: [StrengthPoint]
    /// nil until there are enough workouts, on more than one day, to draw a line
    let fit: StrengthFit?

    /// workouts needed before Finn projects anything
    static let minimumWorkouts = 3

    nonisolated enum ProjectionStatus: Equatable {
        /// how many more workouts to log
        case needsWorkouts(Int)
        /// every workout falls on one day, so there is no change over time to follow
        case needsMoreDays
        case ready
    }

    var best: Double? { points.map(\.value).max() }

    var projectionStatus: ProjectionStatus {
        if points.count < Self.minimumWorkouts { return .needsWorkouts(Self.minimumWorkouts - points.count) }
        return fit == nil ? .needsMoreDays : .ready
    }

    static func make(for exercise: ExerciseKind, history: [WorkoutSessionSummary],
                     calendar: Calendar = .current) -> StrengthTrend {
        let points = history.compactMap { session -> StrengthPoint? in
            let best = session.sets.filter { $0.exercise == exercise }.map { $0.analysis.reps.count }.max()
            return best.map { StrengthPoint(date: session.startedAt, value: Double($0)) }
        }
        .sorted { $0.date < $1.date }
        let fit = points.count >= minimumWorkouts ? leastSquares(points, calendar: calendar) : nil
        return StrengthTrend(exercise: exercise, metric: .of(exercise), points: points, fit: fit)
    }

    /// the line extended from today to the horizon, in whole reps and never under the current best
    func projection(to horizon: ProgressHorizon, today: Date = .now,
                    calendar: Calendar = .current) -> StrengthProjection? {
        guard let fit, let best else { return nil }
        let start = calendar.startOfDay(for: today)
        let span = Self.days(from: start, to: horizon.end(from: today, calendar: calendar), calendar: calendar)
        let count = horizon.barCount
        let points = (1...count).compactMap { step -> StrengthPoint? in
            // evenly spread, the last one exactly on the horizon's date
            let offset = Int((Double(span) * Double(step) / Double(count)).rounded())
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let reps = fit.value(at: date, calendar: calendar).rounded()
            return StrengthPoint(date: date, value: max(best, reps))
        }
        return StrengthProjection(horizon: horizon, points: points)
    }

    /// whole calendar days between two dates, so a time of day never tilts the line
    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                to: calendar.startOfDay(for: end)).day ?? 0
    }

    /// least-squares line of value against day; nil when every point falls on one day
    static func leastSquares(_ points: [StrengthPoint], calendar: Calendar) -> StrengthFit? {
        guard let first = points.first?.date else { return nil }
        let origin = calendar.startOfDay(for: first)
        let xs = points.map { Double(days(from: origin, to: $0.date, calendar: calendar)) }
        let ys = points.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let spread = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard spread > 0 else { return nil }
        let covariance = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let slope = covariance / spread
        return StrengthFit(origin: origin, intercept: meanY - slope * meanX, slopePerDay: slope)
    }
}
