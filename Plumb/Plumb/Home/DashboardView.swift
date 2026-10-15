import SwiftUI
import Charts

/// Stable destinations. Starting a set is an action inside Workout, never a tab action.
enum HomeTab: String, CaseIterable {
    case home = "Home", posture = "Posture", coach = "Coach", workout = "Workout"

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .workout: "plus"
        case .posture: "figure.run"
        case .coach: "person"
        }
    }

    var identifier: String {
        switch self {
        case .home: "tab.home"
        case .workout: "tab.workout"
        case .posture: "tab.posture"
        case .coach: "tab.coach"
        }
    }
}

/// Content determines each widget's layout; all values come from saved measurements.
struct DashboardView: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    var badges: [EarnedBadge] = []
    let startWorkout: () -> Void
    let open: (HomeRoute) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var bestReps: Int? {
        history.flatMap(\.sets).filter { $0.exercise == exercise }.map { $0.analysis.reps.count }.max()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workoutCard
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    activityCard(now: context.date)
                }
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                layout {
                    bestSetCard
                    awardsCard
                }
                if !history.isEmpty { recentCard }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("summary.scroll")
        .background { HomeBackdrop() }
        .navigationTitle("Home")
    }

    private var workoutCard: some View {
        Button(action: startWorkout) {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.definition.copy.name)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                ExerciseFigureView(kind: exercise, animates: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: typeSize.isAccessibilitySize ? 160 : 190)
                    .padding(.horizontal, 12)
                    .accessibilityHidden(true)
                HStack(spacing: 12) {
                    Text("Choose a workout").font(.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(HomeStyle.lime)
                        .accessibilityHidden(true)
                }
            }
            .padding(22)
            .foregroundStyle(.white)
            .background(HomeStyle.cameraBottom, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("summary.workout")
    }

    private func activityCard(now: Date) -> some View {
        let days = DashboardActivityDay.recent(history: history, now: now)
        let total = days.reduce(0) { $0 + $1.reps }
        return Button { open(.history) } label: {
            HomeCard {
                VStack(alignment: .leading, spacing: 14) {
                    cardHeading("Activity")
                    if history.isEmpty {
                        Text("No saved sets")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        let layout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                            : AnyLayout(HStackLayout(alignment: .center, spacing: 20))
                        layout {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(total, format: .number).font(.largeTitle.bold()).monospacedDigit()
                                    Text("reps").font(.headline).foregroundStyle(.secondary)
                                }
                                Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
                            }
                            activityChart(days)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .accessibilityIdentifier("home.sessions")
        .accessibilityLabel(Text("Activity"))
        .accessibilityValue(history.isEmpty ? String(localized: "No saved sets") :
            String(localized: "\(total) reps in the last 7 days") + ". " + days.map {
                $0.date.formatted(.dateTime.weekday(.wide)) + ": " + String(localized: "\($0.reps) reps")
            }.joined(separator: ". "))
        .accessibilityHint("All your saved sessions")
    }

    private func activityChart(_ days: [DashboardActivityDay]) -> some View {
        Chart(days) { day in
            BarMark(x: .value("Day", day.date.formatted(.dateTime.weekday(.wide))),
                    y: .value("Reps", day.reps), width: .ratio(0.5))
                .cornerRadius(3)
                .foregroundStyle(HomeStyle.activityGreen)
                .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(String(localized: "\(day.reps) reps"))
        }
        .chartYScale(domain: 0...max(days.map(\.reps).max() ?? 0, 1))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if days.indices.contains(value.index) {
                        Text(days[value.index].date.formatted(.dateTime.weekday(.narrow)))
                    }
                }
            }
        }
        .frame(height: 88)
        .accessibilityHidden(true)
        .accessibilityIdentifier("summary.activityChart")
    }

    private var bestSetCard: some View {
        Button { open(.weights) } label: {
            HomeCard {
                VStack(alignment: .leading, spacing: 14) {
                    cardHeading("Best set")
                    if let bestReps {
                        Text("\(bestReps) reps").font(.title2.bold()).monospacedDigit()
                    } else {
                        Text("—").font(.largeTitle.bold())
                            .accessibilityHidden(true)
                    }
                    Text(exercise.chipName).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .accessibilityIdentifier("home.weights")
        .accessibilityValue(bestReps == nil ? String(localized: "No saved sets") : "")
    }

    private var awardsCard: some View {
        Button { open(.awards) } label: {
            HomeCard {
                VStack(alignment: .leading, spacing: 14) {
                    cardHeading("Awards")
                    Image(systemName: badges.isEmpty ? "rosette" : "medal.fill")
                        .font(.system(size: 34, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                    Text(badges.isEmpty ? "View milestones" : "\(badges.count) earned")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .accessibilityIdentifier("home.awards")
    }

    private var recentCard: some View {
        Button { open(.lastWorkout) } label: {
            HomeCard {
                VStack(alignment: .leading, spacing: 16) {
                    cardHeading("Recent workout")
                    if let last = history.first {
                        HStack(alignment: .top, spacing: 12) {
                            HomeSymbol(name: "figure.strengthtraining.functional", size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(last.sets.first?.exercise.definition.copy.name ?? String(localized: "Workout"))
                                    .font(.headline)
                                Text(last.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        let layout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                            : AnyLayout(HStackLayout(spacing: 24))
                        layout {
                            Label("\(last.sets.count) sets", systemImage: "square.stack.3d.up")
                            Label("\(last.sets.reduce(0) { $0 + $1.analysis.reps.count }) reps", systemImage: "repeat")
                        }
                        .font(.subheadline.weight(.medium))
                    } else {
                        Text("No workouts yet").font(.headline)
                        Text("Your first finished session will appear here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .accessibilityIdentifier("home.lastSession")
    }

    private func cardHeading(_ title: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .font(.headline)
        .fixedSize(horizontal: false, vertical: true)
    }
}
