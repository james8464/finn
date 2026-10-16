import SwiftUI
import WidgetKit

/// the views of the home screen widget and the Live Activity. They live with the app's sources so
/// unit tests can render them to images; the extension declares the widgets around them
/// always dark, like the app; semantic colours still adapt to widget rendering modes

// MARK: - Last set widget

/// the home screen widget: the last measured set, or a plain line when nothing is saved yet, and a
/// way to start a set in the app
struct LastSetWidgetView: View {
    let snapshot: LastSetSnapshot?
    let family: WidgetFamily
    /// today, for "Today 9:41" versus a date; tests fix it
    var now: Date = .now

    private var startURL: URL {
        FinnDeepLink.startSet(exerciseKey: snapshot?.exerciseKey).url
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            default: small
            }
        }
        .environment(\.colorScheme, .dark)
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(startURL)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            if let snapshot {
                Text("\(snapshot.reps)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                exerciseLabel(snapshot)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(snapshot.partlyVisible ? String(localized: "Partly visible · \(Self.when(snapshot.capturedAt, now: now))") : Self.when(snapshot.capturedAt, now: now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No set measured yet")
                    .font(.headline)
                Text("Open Finn to start one")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                if let snapshot {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(snapshot.reps)")
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        exerciseLabel(snapshot)
                            .font(.headline)
                    }
                    HStack(spacing: 0) {
                        Text(Self.when(snapshot.capturedAt, now: now))
                        if snapshot.partlyVisible { Text(" · partly visible") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("No set measured yet")
                        .font(.headline)
                    Text("Your last set shows here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            Link(destination: startURL) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.functional")
                        .font(.title2)
                    Text("Start a set")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .frame(width: 92)
                .frame(maxHeight: .infinity)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .widgetAccentable()
            }
            .accessibilityLabel("Start a set in Finn")
        }
    }

    private func exerciseLabel(_ snapshot: LastSetSnapshot) -> Text {
        if snapshot.reps == 1 { Text("rep · \(snapshot.exerciseName)") }
        else { Text("reps · \(snapshot.exerciseName)") }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.strengthtraining.functional")
                .font(.caption.weight(.semibold))
            Text("Last set")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    /// "Today 9:41", "Yesterday 18:02", otherwise the date
    static func when(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today \(time)") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return String(localized: "Yesterday \(time)") }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Live Activity

/// the Lock Screen banner of a set in progress
struct SetActivityLockScreenView: View {
    let attributes: FinnSetActivityAttributes
    let state: FinnSetActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.functional")
                    Text("Finn · \(attributes.exerciseName)")
                    if attributes.demoInput { DemoTag() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Text(state.reps == 1 ? "1 rep" : "\(state.reps) reps")
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(attributes.startedAt, style: .timer)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                Text("elapsed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .environment(\.colorScheme, .dark)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    }
}

/// the two ends of the compact Dynamic Island
struct SetActivityCompactLeading: View {
    let state: FinnSetActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.strengthtraining.functional")
            Text("\(state.reps)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.callout.weight(.semibold))
        .padding(.leading, 4)
    }
}

struct SetActivityCompactTrailing: View {
    let attributes: FinnSetActivityAttributes
    var body: some View {
        Text(attributes.startedAt, style: .timer)
            .font(.callout.weight(.medium))
            .monospacedDigit()
            .frame(width: 44)
            .multilineTextAlignment(.trailing)
            .padding(.trailing, 4)
    }
}

/// the small yellow label the app shows on demo input, carried into the activity
struct DemoTag: View {
    var body: some View {
        Text("DEMO")
            .font(.caption2.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.yellow, in: Capsule())
    }
}
