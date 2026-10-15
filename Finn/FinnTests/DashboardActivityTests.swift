import Foundation
import Testing
@testable import Finn

struct DashboardActivityTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func set(at date: Date, reps: Int) -> SetSummary {
        SetSummary(id: UUID(), sessionID: UUID(), capturedAt: date, bodySide: .left,
                   analysis: SetAnalysis(reps: (0..<reps).map {
                       RepMetric(number: $0 + 1, startTime: Double($0) * 2,
                                 endTime: Double($0) * 2 + 1.5, relativeRange: 0.4)
                   }, confidence: 0.9, rubricVersion: "test"), cue: nil, cueResponse: .unanswered)
    }

    @Test func captureDateDeterminesTheDayAndFutureSetsAreExcluded() {
        let session = WorkoutSessionSummary(id: UUID(), startedAt: date(20), sets: [
            set(at: date(24, hour: 23), reps: 3), set(at: date(25, hour: 1), reps: 5),
            set(at: date(25, hour: 10), reps: 2), set(at: date(25, hour: 23), reps: 99),
            set(at: date(18), reps: 99)
        ])
        let days = DashboardActivityDay.recent(history: [session], now: date(25), calendar: calendar)
        #expect(days.count == 7)
        #expect(days.map(\.reps) == [0, 0, 0, 0, 0, 3, 7])
    }

    @Test func sevenLocalCalendarDaysSurviveTheAutumnClockChange() {
        let days = DashboardActivityDay.recent(history: [], now: date(27), calendar: calendar)
        #expect(days.map { calendar.component(.day, from: $0.date) } == Array(21...27))
        #expect(Set(days.map(\.date)).count == 7)
        #expect(days.allSatisfy { $0.reps == 0 })
        #expect(days[5].date.timeIntervalSince(days[4].date) == 25 * 3600)
    }
}
