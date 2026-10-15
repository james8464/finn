import SwiftUI

/// The next workout Finn suggests on Home. Sample data until there is a real plan: add fields here
/// as the plan grows. `start` carries both the day and the time.
struct NextWorkout: Equatable {
    enum Intensity: String, CaseIterable {
        case light, moderate, hard

        var title: String {
            switch self {
            case .light: String(localized: "Light", comment: "Intensity of the next workout.")
            case .moderate: String(localized: "Moderate", comment: "Intensity of the next workout.")
            case .hard: String(localized: "Hard", comment: "Intensity of the next workout.")
            }
        }
    }

    var start: Date
    var intensity: Intensity

    /// Sample: two days from now at 6:30 PM, moderate. No scheduling behind it.
    static func sample(now: Date = .now, calendar: Calendar = .current) -> NextWorkout {
        let day = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        let start = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
        return NextWorkout(start: start, intensity: .moderate)
    }

    /// "Thu, Oct 17", in the person's locale.
    var dayText: String { start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }
    /// "6:30 PM", or "18:30", as the person's settings say.
    var timeText: String { start.formatted(date: .omitted, time: .shortened) }
    /// "Thursday, October 17", for VoiceOver.
    var spokenDayText: String { start.formatted(.dateTime.weekday(.wide).month(.wide).day()) }
}

/// Finn's encouragement on the coach card: short, energetic, no emoji.
enum FinnQuotes {
    static var all: [String] {
        [
            String(localized: "Keep going!"),
            String(localized: "Don't stop now!"),
            String(localized: "You're on the journey!"),
            String(localized: "One more rep, then another."),
            String(localized: "Strong today, stronger tomorrow."),
            String(localized: "Show up. That's the win."),
            String(localized: "Your best set is still ahead."),
            String(localized: "Every rep counts."),
            String(localized: "Momentum is on your side."),
            String(localized: "Trust the work."),
            String(localized: "Small steps, big gains."),
            String(localized: "You've got this."),
            String(localized: "Let's make it count."),
            String(localized: "Consistency beats perfect."),
        ]
    }

    /// A random line other than `previous`, so the same one never shows twice in a row.
    static func next(after previous: Int?, count: Int = all.count) -> Int {
        let choices = (0..<count).filter { $0 != previous }
        return choices.randomElement() ?? 0
    }
}

/// The pink Home card once the person has tried Finn: Finn, the coach, gives the next
/// workout and one line of encouragement. The F badge says who is talking.
struct FinnCoachCard: View {
    let workout: NextWorkout
    let quote: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                header
                details.padding(.top, 8)
                // Finn's line is a whisper: a little smaller and lighter than the date, in the same
                // solid colour so it stays readable.
                Text(String(localized: "“\(quote)”", comment: "Finn's encouragement, in quotation marks."))
                    .font(.subheadline.weight(.light))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSolid ? .black : .white)
            .background { surface }
            .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.finnCardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        // One element: who speaks, the workout, then the line.
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Opens workout setup.")
        .accessibilityIdentifier("home.finnCoach")
    }

    /// Increase Contrast and Reduce Transparency get the solid pink with black text (6:1).
    private var isSolid: Bool { reduceTransparency || contrast == .increased }

    /// Neon glass: see-through pink, brighter at the top, with a bright pink edge and a soft glow.
    /// White text, since black would fall to 2.5:1 on it.
    @ViewBuilder private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: DashboardStyle.finnCardRadius, style: .continuous)
        if isSolid {
            shape.fill(DashboardStyle.accent)
        } else {
            shape.fill(LinearGradient(colors: [DashboardStyle.accent.opacity(DashboardStyle.coachFillTop),
                                               DashboardStyle.accent.opacity(DashboardStyle.coachFillBottom)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { shape.strokeBorder(DashboardStyle.accent, lineWidth: 1.5) }
                .shadow(color: DashboardStyle.accent.opacity(0.5), radius: 14)
        }
    }

    /// Badge and title side by side; stacked at accessibility sizes, where the arrow is dropped.
    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                badge
                title
            }
        } else {
            HStack(spacing: 16) {
                badge
                title
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.headline)
            }
        }
    }

    /// Finn's monogram in the same 48-point badge as the Try Finn card.
    private var badge: some View {
        Text(verbatim: "F")
            .font(.title2.bold())
            .fontDesign(.rounded)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: 48, height: 48)
            .background(.black.opacity(0.08), in: Circle())
    }

    private var title: some View {
        Text("Your next workout")
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Date · time · intensity on one line; one per line at accessibility sizes.
    @ViewBuilder private var details: some View {
        let parts = [workout.dayText, workout.timeText, workout.intensity.title]
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(parts, id: \.self) { Text($0) }
                }
            } else {
                Text(parts.joined(separator: " · "))
            }
        }
        .font(.body.weight(.medium))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

    private var spokenLabel: String {
        let day = workout.spokenDayText, time = workout.timeText
        let intensity = workout.intensity.title.localizedLowercase
        return String(localized: "Finn: your next workout, \(day), \(time), \(intensity). \(quote)",
                      comment: "VoiceOver label of the coach card: day, time, intensity, then Finn's encouragement.")
    }
}
