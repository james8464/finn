import SwiftUI
import WidgetKit

/// The views of the home screen widget and the Live Activity. They live with the app's sources so
/// unit tests can render them to images; the extension declares the widgets around them.
/// Monochrome like the app: labels in the primary color, the system background behind.

// MARK: - Last set widget

/// The home screen widget: the last measured set, or a plain line when nothing is saved yet, and a
/// way to start a set in the app.
struct LastSetWidgetView: View {
    let snapshot: LastSetSnapshot?
    let family: WidgetFamily
    /// Today, for "Today 9:41" versus a date; tests fix it.
    var now: Date = .now

    private var startURL: URL {
        PlumbDeepLink.startSet(exerciseKey: snapshot?.exerciseKey).url
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
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
                Text(snapshot.exerciseName)
                    .font(.headline)
                Text(Self.when(snapshot.capturedAt, now: now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No set measured yet")
                    .font(.headline)
                Text("Open Plumb to start one")
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
                        Text(snapshot.exerciseName)
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
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 92)
                .frame(maxHeight: .infinity)
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("Start a set in Plumb")
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "scope")
                .font(.caption.weight(.semibold))
            Text("Last set")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    /// "Today 9:41", "Yesterday 18:02", otherwise the date.
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

/// The Lock Screen banner of a set in progress.
struct SetActivityLockScreenView: View {
    let attributes: PlumbSetActivityAttributes
    let state: PlumbSetActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text("Plumb · \(attributes.exerciseName)")
                    if attributes.demoInput { DemoTag() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Text(state.reps == 1 ? "1 rep" : "\(state.reps) reps")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
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
        .activityBackgroundTint(Color(uiColor: .systemBackground))
        .activitySystemActionForegroundColor(.primary)
    }
}

/// The two ends of the compact Dynamic Island.
struct SetActivityCompactLeading: View {
    let state: PlumbSetActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "scope")
            Text("\(state.reps)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.callout.weight(.semibold))
        .padding(.leading, 4)
    }
}

struct SetActivityCompactTrailing: View {
    let attributes: PlumbSetActivityAttributes
    var body: some View {
        Text(attributes.startedAt, style: .timer)
            .font(.callout.weight(.medium))
            .monospacedDigit()
            .frame(width: 44)
            .multilineTextAlignment(.trailing)
            .padding(.trailing, 4)
    }
}

/// The small yellow label the app shows on demo input, carried into the activity.
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
