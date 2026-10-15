import SwiftUI
import WidgetKit

/// The widget extension: the last measured set on the home screen, and the set in progress as a
/// Live Activity. Views are in the app's `Widgets/` folder, shared with this target.
@main
struct PlumbWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastSetWidget()
        SetLiveActivityWidget()
    }
}

// MARK: - Last set

struct LastSetEntry: TimelineEntry {
    let date: Date
    let snapshot: LastSetSnapshot?
}

/// Reads the App Group once per reload; the app asks for a reload every time the history changes,
/// so there is no schedule. Without the App Group entitlement the store is nil and the widget shows
/// its empty line.
struct LastSetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastSetEntry {
        LastSetEntry(date: .now, snapshot: LastSetSnapshot(exerciseName: "Squat", exerciseKey: "bodyweightSquat",
                                                           reps: 12, capturedAt: .now, partlyVisible: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (LastSetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastSetEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> LastSetEntry {
        LastSetEntry(date: .now, snapshot: SharedSetStore.appGroup?.read())
    }
}

struct LastSetWidget: Widget {
    static let kind = "com.finlearn.plumb.widgets.last-set"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LastSetProvider()) { entry in
            LastSetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last set")
        .description("Your last measured set, and a tap to start the next one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LastSetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LastSetEntry

    var body: some View {
        LastSetWidgetView(snapshot: entry.snapshot, family: family, now: entry.date)
    }
}

// MARK: - Set in progress

struct SetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlumbSetActivityAttributes.self) { context in
            SetActivityLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(context.attributes.exerciseName)
                            if context.attributes.demoInput { DemoTag() }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        Text(context.state.reps == 1 ? "1 rep" : "\(context.state.reps) reps")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("elapsed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.startedAt, style: .timer)
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Counted on your iPhone. Tap to come back to the set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                SetActivityCompactLeading(state: context.state)
            } compactTrailing: {
                SetActivityCompactTrailing(attributes: context.attributes)
            } minimal: {
                Text("\(context.state.reps)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .keylineTint(.primary)
        }
    }
}
