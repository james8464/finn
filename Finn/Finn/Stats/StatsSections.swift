import Charts
import SwiftUI

/// numbers and curves drawn from the saved sessions. Every value is measured by the camera; nothing
/// is estimated. Each section answers one question and says which sessions it rests on.
nonisolated struct StatsSummary {
    let sessions: [WorkoutSessionSummary]
    let calendar = Calendar.current

    var totalReps: Int {
        sessions.flatMap(\.sets).reduce(0) { $0 + $1.analysis.reps.count }
    }

    /// days in a row with a session, counting today or yesterday as the start
    var streakDays: Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else {
            return 0
        }
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) {
            guard
                let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                days.contains(yesterday) else {
                return 0
            }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previous
        }
        return streak
    }

    /// reps per day over the last 12 weeks, oldest first, for the regularity calendar
    var dailyReps: [(day: Date, reps: Int)] {
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        guard let first = calendar.date(byAdding: .weekOfYear, value: -11, to: weekStart) else {
            return []
        }
        var byDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            byDay[day, default: 0] += session.sets.reduce(0) { $0 + $1.analysis.reps.count }
        }
        var days: [(Date, Int)] = []
        var day = first
        while day <= today {
            days.append((day, byDay[day] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }
        return days
    }

    /// this week's reps against last week's, as a share; nil without a previous week
    var weekTrend: (thisWeek: Int, lastWeek: Int, change: Double?) {
        let today = Date.now
        let thisWeek = sessions.filter { calendar.isDate(
            $0.startedAt,
            equalTo: today,
            toGranularity: .weekOfYear
        ) }
        let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: today) ?? today
        let lastWeek = sessions.filter { calendar.isDate(
            $0.startedAt,
            equalTo: lastWeekDate,
            toGranularity: .weekOfYear
        ) }
        let a = thisWeek.flatMap(\.sets).reduce(0) { $0 + $1.analysis.reps.count }
        let b = lastWeek.flatMap(\.sets).reduce(0) { $0 + $1.analysis.reps.count }
        return (a, b, b > 0 ? Double(a - b) / Double(b) : nil)
    }

    /// per session: the share of reps the observation did not name. A set without an observation
    /// counts all its reps as clean
    var qualityPerSession: [(date: Date, share: Double)] {
        sessions.compactMap { session in
            let reps = session.sets.reduce(0) { $0 + $1.analysis.reps.count }
            guard reps > 0 else {
                return nil
            }
            let flagged = session.sets.reduce(0) { total, set in
                guard let cue = set.cue, set.cueResponse != .notRelevant else {
                    return total
                }
                return total + Set(cue.repNumbers).count
            }
            return (session.startedAt, Double(reps - flagged) / Double(reps))
        }.sorted { $0.date < $1.date }
    }

    struct ExerciseFacts {
        let kind: ExerciseKind
        let sessions: [WorkoutSessionSummary]
        let reps: Int
        let bestSet: Int
        let bestSetDate: Date?
        /// mean rep time in seconds
        let tempo: Double
        /// median range of all measured reps, in the exercise's unit
        let medianRange: Double
        /// reps per session, oldest first
        let repsPerSession: [(date: Date, reps: Int)]
    }

    func facts(for kind: ExerciseKind) -> ExerciseFacts? {
        let withKind = sessions.filter { $0.sets.contains { $0.exercise == kind } }
        guard !withKind.isEmpty else {
            return nil
        }
        let sets = withKind.flatMap(\.sets).filter { $0.exercise == kind }
        let reps = sets.flatMap(\.analysis.reps)
        let best = withKind.flatMap { session in
            session.sets.filter { $0.exercise == kind }.map { ($0.analysis.reps.count, session.startedAt) }
        }.max { $0.0 < $1.0 }
        let ranges = reps.map(\.relativeRange).sorted()
        return ExerciseFacts(
            kind: kind, sessions: withKind,
            reps: reps.count,
            bestSet: best?.0 ?? 0, bestSetDate: best?.1,
            tempo: reps.isEmpty ? 0 : reps.map(\.duration).reduce(0, +) / Double(reps.count),
            medianRange: ranges.isEmpty ? 0 : ranges[ranges.count / 2],
            repsPerSession: withKind.map { session in
                (
                    session.startedAt,
                    session.sets.filter { $0.exercise == kind }.reduce(0) { $0 + $1.analysis.reps.count }
                )
            }.sorted { $0.date < $1.date }
        )
    }

    var exercises: [ExerciseFacts] {
        ExerciseKind.allCases.compactMap(facts(for:))
    }
}

/// a number that says where it comes from: tap it and the sessions behind it unfold
struct MeasuredFigure<Content: View>: View {
    let value: String
    let label: LocalizedStringKey
    let sources: [WorkoutSessionSummary]
    @ViewBuilder var content: Content
    @State private var showsSources = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        AppMotion.reduces(systemReduceMotion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : HomeStyle.spring) { showsSources.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.largeTitle.bold())
                        .tracking(-1.2)
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(HomeStyle.supportingText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the sessions behind this number")
            content
            if showsSources {
                Text(sources.isEmpty ? String(localized: "No session yet.")
                    : String(localized: "From \(sources.count) sessions: ")
                    + sources.prefix(6).map { $0.startedAt.formatted(date: .abbreviated, time: .omitted) }
                    .joined(separator: ", ") + (sources.count > 6 ? "…" : ""))
                    .font(.footnote)
                    .foregroundStyle(HomeStyle.supportingText)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
}

/// twelve weeks of days: a square per day, brighter with more reps
struct RegularityCalendar: View {
    let days: [(day: Date, reps: Int)]

    var body: some View {
        let most = max(1, days.map(\.reps).max() ?? 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 12)
        let spoken = days.filter { $0.reps > 0 }
            .map { "\($0.day.formatted(date: .abbreviated, time: .omitted)): \($0.reps)" }
            .joined(separator: "; ")
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0 ..< 84, id: \.self) { index in
                    let source = (index % 12) * 7 + index / 12
                    let entry = source < days.count ? days[source] : (day: Date.now, reps: 0)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(entry.reps == 0 ? Color.primary.opacity(0.08)
                            : AppPageStyle.tint.opacity(0.4 + 0.6 * Double(entry.reps) / Double(most)))
                        .frame(height: 12)
                        .opacity(source < days.count ? 1 : 0)
                }
            }
            .frame(height: 108)
            Text("12 weeks")
                .font(.footnote)
                .foregroundStyle(HomeStyle.supportingText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Regularity calendar")
        .accessibilityValue(spoken.isEmpty ? String(localized: "No session yet.") : spoken)
    }
}

/// the share of clean reps per session, as a line between 0 and 100 %
struct QualityChart: View {
    let points: [(date: Date, share: Double)]

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            LineMark(x: .value("Date", point.date), y: .value("Reps without observations", point.share * 100))
                .foregroundStyle(Color.primary)
                .interpolationMethod(.monotone)
            PointMark(
                x: .value("Date", point.date),
                y: .value("Reps without observations", point.share * 100)
            )
            .foregroundStyle(Color.primary)
        }
        .chartYScale(domain: 0 ... 100)
        .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps without observations per session")
        .accessibilityValue(points
            .map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(Int($0.share * 100)) percent"
            }
            .joined(separator: "; "))
    }
}

/// one exercise: its records, tempo, range and curve
struct ExerciseStatsCard: View {
    let facts: StatsSummary.ExerciseFacts
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let definition = facts.kind.definition
        VStack(alignment: .leading, spacing: 10) {
            WrappingText(text: definition.copy.name, style: .title3, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 18))
            layout {
                figure("\(facts.bestSet)", "Best set")
                figure("\(facts.reps)", "Reps")
                figure("\(facts.sessions.count)", "Sessions")
            }
            if facts.repsPerSession.count >= 2 {
                Chart(Array(facts.repsPerSession.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Reps", point.reps))
                        .foregroundStyle(Color.primary)
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Date", point.date), y: .value("Reps", point.reps))
                        .foregroundStyle(.linearGradient(
                            colors: [Color.primary.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.monotone)
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                .frame(height: 110)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(definition.copy.name), reps per session")
                .accessibilityValue(facts.repsPerSession.map {
                    "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.reps)"
                }.joined(separator: "; "))
            }
            WrappingText(
                text: String(
                    localized: "Tempo \(facts.tempo.formatted(.number.precision(.fractionLength(1)))) s per rep · median \(definition.copy.rangeNoun) \(definition.formattedRange(facts.medianRange))"
                ),
                style: .footnote,
                colour: .label.withAlphaComponent(0.72)
            )
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("stats.exercise.\(facts.kind.rawValue)")
    }

    private func figure(_ value: String, _ label: String.LocalizationValue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WrappingText(text: value, style: .title2, weight: .bold)
            WrappingText(
                text: String(localized: label),
                style: .caption1,
                colour: .label.withAlphaComponent(0.72)
            )
        }
        .accessibilityElement(children: .combine)
    }
}
