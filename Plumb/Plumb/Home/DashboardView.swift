import SwiftUI

/// Stable destinations. Starting a set is an action inside Workout, never a tab action.
enum HomeTab: String, CaseIterable {
    case home = "Summary", workout = "Workout", history = "History", coach = "Coach"

    var symbol: String {
        switch self {
        case .home: "chart.bar.xaxis"
        case .workout: "figure.strengthtraining.functional"
        case .history: "clock.arrow.circlepath"
        case .coach: "bubble.left.and.text.bubble.right"
        }
    }

    var identifier: String {
        switch self {
        case .home: "tab.home"
        case .workout: "tab.workout"
        case .history: "tab.history"
        case .coach: "tab.coach"
        }
    }
}

struct DashboardView: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    var badges: [EarnedBadge] = []
    let startWorkout: () -> Void
    let open: (HomeRoute) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var sets: Int { history.reduce(0) { $0 + $1.sets.count } }
    private var reps: Int { history.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.analysis.reps.count } } }

    private var bestReps: Int? {
        history.flatMap(\.sets).filter { $0.exercise == exercise }.map { $0.analysis.reps.count }.max()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("ON THIS IPHONE", systemImage: "figure.strengthtraining.functional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HomeStyle.accent)
                    Text(history.isEmpty ? "Your next set starts here." : "Make time for your next set.")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(history.isEmpty
                         ? "Choose an exercise. Plumb counts your reps and helps you review each set."
                         : "Pick up with \(exercise.chipName.lowercased()), or choose another exercise.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Button(action: startWorkout) {
                        PrimaryActionLabel(title: "Choose a workout", symbol: "figure.strengthtraining.functional")
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("summary.workout")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 20))

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Your activity")
                        let layout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                        layout {
                            metric(history.count, label: "Sessions")
                            metric(sets, label: "Sets")
                            metric(reps, label: "Reps")
                        }
                        .padding(20)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 20))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Recent workout")
                    Button { open(.lastWorkout) } label: {
                        HomeCard {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "figure.strengthtraining.functional")
                                    .font(.title2)
                                    .foregroundStyle(HomeStyle.accent)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    if let last = history.first {
                                        Text(last.sets.first?.exercise.definition.copy.name ?? "Workout")
                                            .font(.headline)
                                        Text("\(String(localized: "\(last.sets.count) sets")) · \(String(localized: "\(last.sets.reduce(0) { $0 + $1.analysis.reps.count }) reps"))")
                                            .font(.subheadline)
                                        Text(last.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.footnote).foregroundStyle(.secondary)
                                    } else {
                                        Text("No workouts yet").font(.headline)
                                        Text("Your first finished session will appear here.")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("home.lastSession")
                }

                VStack(spacing: 0) {
                    summaryRow("Best set", detail: bestReps.map { String(localized: "\(String(localized: "\($0) reps")) · \(exercise.chipName)") }
                               ?? String(localized: "No \(exercise.chipName.lowercased()) sets saved yet."),
                               symbol: "chart.bar", id: "home.weights") { open(.weights) }
                    Divider().padding(.leading, 54)
                    summaryRow("History", detail: String(localized: "All your saved sessions"), symbol: "clock.arrow.circlepath",
                               id: "home.sessions") { open(.history) }
                    Divider().padding(.leading, 54)
                    summaryRow("Awards", detail: badges.isEmpty ? String(localized: "Discover your first milestone") : String(localized: "\(badges.count) earned"),
                               symbol: "rosette", id: "home.awards") { open(.awards) }
                }
                .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 20))

                Label("Camera frames stay on your iPhone. No video is saved.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(HomeStyle.background)
        .navigationTitle("Summary")
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.title3.bold()).accessibilityAddTraits(.isHeader)
    }

    private func metric(_ value: Int, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number).font(.largeTitle.bold()).monospacedDigit()
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func summaryRow(_ title: LocalizedStringKey, detail: String, symbol: String,
                            id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(HomeStyle.accent)
                    .frame(width: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
