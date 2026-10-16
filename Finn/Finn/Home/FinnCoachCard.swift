import SwiftUI

/// The next workout Finn suggests on Home. Sample data until there is a real plan: add fields here
/// as the plan grows. `start` carries both the day and the time.
struct NextWorkout: Equatable {
    enum Intensity: String, CaseIterable {
        case light
        case moderate
        case hard

        var title: String {
            switch self {
            case .light:
                String(localized: "Light", comment: "Intensity of the next workout.")
            case .moderate:
                String(localized: "Moderate", comment: "Intensity of the next workout.")
            case .hard:
                String(localized: "Hard", comment: "Intensity of the next workout.")
            }
        }

        /// one line on how to train at this intensity, under it on the Workout card
        var encouragement: String {
            switch self {
            case .light:
                String(
                    localized: "Easy pace, focus on clean reps.",
                    comment: "How to train at light intensity, on the next workout card."
                )
            case .moderate:
                String(
                    localized: "Steady pace, leave 2 reps in the tank.",
                    comment: "How to train at moderate intensity, on the next workout card."
                )
            case .hard:
                String(
                    localized: "Push hard, stop when form slips.",
                    comment: "How to train at hard intensity, on the next workout card."
                )
            }
        }
    }

    /// one exercise of the plan, in order
    struct Exercise: Equatable, Identifiable {
        let id = UUID()
        var kind: ExerciseKind
        var sets: Int
        var reps: Int
    }

    var start: Date
    var intensity: Intensity
    /// how long the workout should take, for its end time
    var estimatedDuration: TimeInterval
    var exercises: [Exercise]

    /// Sample: two days from now at 6:30 PM, moderate, 55 minutes. No scheduling behind it.
    static func sample(now: Date = .now, calendar: Calendar = .current) -> NextWorkout {
        let day = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        let start = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
        return NextWorkout(
            start: start,
            intensity: .moderate,
            estimatedDuration: 55 * 60,
            exercises: [Exercise(kind: .bodyweightSquat, sets: 3, reps: 12),
                        Exercise(kind: .pushUp, sets: 3, reps: 10),
                        Exercise(kind: .staticLunge, sets: 3, reps: 10)]
        )
    }

    var end: Date {
        start.addingTimeInterval(estimatedDuration)
    }

    /// "Thu, Oct 17", in the person's locale.
    var dayText: String {
        start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "6:30 PM", or "18:30", as the person's settings say.
    var timeText: String {
        start.formatted(date: .omitted, time: .shortened)
    }

    /// "18:30 – 19:25", or "6:30 – 7:25 PM", as the person's settings say.
    var timeRangeText: String {
        (start ..< end).formatted(.interval.hour().minute())
    }

    /// "7:25 PM", for VoiceOver.
    var endTimeText: String {
        end.formatted(date: .omitted, time: .shortened)
    }

    /// "Thursday, October 17", for VoiceOver.
    var spokenDayText: String {
        start.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
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
        let choices = (0 ..< count).filter { $0 != previous }
        return choices.randomElement() ?? 0
    }
}

/// the next workout and Finn's current line, held once in `ContentView` so the Home and Workout
/// cards always show the same workout. Only Home shows the line
struct FinnCoachMessage: Equatable {
    var workout = NextWorkout.sample()
    var quoteIndex = FinnQuotes.next(after: nil)

    var quote: String {
        let quotes = FinnQuotes.all
        return quotes[quoteIndex % quotes.count]
    }

    /// a new line, never the same one twice in a row
    mutating func nextQuote() {
        quoteIndex = FinnQuotes.next(after: quoteIndex)
    }
}

/// Finn's neon glass: see-through pink, brighter at the top, with a bright pink edge and a soft glow,
/// and white text, since black would fall to 2.5:1 on it. Increase Contrast and Reduce Transparency
/// get the solid pink with black text (6:1)
struct FinnCardSurface: ViewModifier {
    var fillTop = DashboardStyle.coachFillTop
    var fillBottom = DashboardStyle.coachFillBottom
    var glow = 0.5
    var glowRadius: CGFloat = 14
    var edgeWidth: CGFloat = 1.5
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSolid ? .black : .white)
            .background { surface }
            .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.finnCardRadius, style: .continuous))
    }

    private var isSolid: Bool {
        reduceTransparency || contrast == .increased
    }

    @ViewBuilder private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: DashboardStyle.finnCardRadius, style: .continuous)
        if isSolid {
            shape.fill(DashboardStyle.accent)
        } else {
            shape.fill(LinearGradient(
                colors: [DashboardStyle.accent.opacity(fillTop),
                         DashboardStyle.accent.opacity(fillBottom)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay { shape.strokeBorder(DashboardStyle.accent, lineWidth: edgeWidth) }
            .shadow(color: DashboardStyle.accent.opacity(glow), radius: glowRadius)
        }
    }
}

/// Finn's monogram in a 48-point badge: who speaks on the coach card and the Try Finn card
struct FinnBadge: View {
    /// the thin pink ring, for the badge away from the pink card, on a dark background
    var showsOutline = false

    var body: some View {
        Text(verbatim: "F")
            .font(.title2.bold())
            .fontDesign(.rounded)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: 48, height: 48)
            .background(.black.opacity(0.08), in: Circle())
            .overlay {
                if showsOutline {
                    Circle()
                        .strokeBorder(
                            DashboardStyle.accent.opacity(DashboardStyle.outlineOpacity),
                            lineWidth: 1
                        )
                        .accessibilityHidden(true)
                }
            }
    }
}

/// The pink Home card once the person has tried Finn: Finn, the coach, gives the next
/// workout and one line of encouragement. The F badge says who is talking.
struct FinnCoachCard: View {
    let workout: NextWorkout
    let quote: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            .modifier(FinnCardSurface())
        }
        .buttonStyle(PressableStyle())
        // One element: who speaks, the workout, then the line.
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Opens the Workout tab.")
        .accessibilityIdentifier("home.finnCoach")
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

    private var badge: some View {
        FinnBadge()
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
        return String(
            localized: "Finn: your next workout, \(day), \(time), \(intensity). \(quote)",
            comment: "VoiceOver label of the coach card: day, time, intensity, then Finn's encouragement."
        )
    }
}
