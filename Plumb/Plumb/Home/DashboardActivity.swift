import Foundation

/// Calendar days use each set's capture date, including sessions spanning midnight.
nonisolated struct DashboardActivityDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let reps: Int

    static func recent(history: [WorkoutSessionSummary], now: Date = .now,
                       calendar: Calendar = .current) -> [Self] {
        let today = calendar.startOfDay(for: now)
        let sets = history.flatMap(\.sets).filter { $0.capturedAt <= now }
        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let count = sets.filter { calendar.isDate($0.capturedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.analysis.reps.count }
            return Self(date: day, reps: count)
        }
    }
}
