import Foundation

/// the thread laid out like a messaging app: each message shows its time, the first message of a
/// day shows the day, and coming back after a pause the same day draws a thin line
nonisolated enum CoachTimeline {
    /// a gap this long between two messages of the same day draws the line
    static let pause: TimeInterval = 60 * 60

    enum Marker: Equatable, Sendable {
        /// the first message of a day: its day, centred above it
        case day(Date)
        /// they came back after a pause the same day
        case pause
    }

    /// what goes above `message`, given the message before it in the thread
    static func marker(
        for message: CoachMessage,
        after previous: CoachMessage?,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Marker? {
        guard let previous, calendar.isDate(previous.sentAt, inSameDayAs: message.sentAt) else {
            return .day(message.sentAt)
        }
        return message.sentAt.timeIntervalSince(previous.sentAt) >= pause ? .pause : nil
    }

    /// "Today" and "Yesterday", then the weekday within the week, then the date, in the
    /// person's language. Today and Yesterday come from the system, already translated
    static func dayLabel(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let label: String
        switch days {
        case 0 ... 1:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.doesRelativeDateFormatting = true
            label = formatter.string(from: date)
        case 2 ..< 7:
            label = date.formatted(style.weekday(.wide))
        default:
            label = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? date.formatted(style.weekday(.wide).day().month(.wide))
                : date.formatted(style.day().month(.wide).year())
        }
        return label.prefix(1).uppercased(with: locale) + label.dropFirst()
    }

    /// the time under a message, as the clock shows it
    static func time(of date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }
}
