import SwiftUI

/// follows a workout the Coach composed: tick each exercise as it is done, then validate
struct WorkoutPlanView: View {
    @State var plan: PlannedWorkout
    var store: PlannedWorkoutStore = .shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        AppMotion.reduces(systemReduceMotion)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Do each exercise in Finn, then tick it here. Validate when the workout is finished and it is kept in Next workouts."
                    )
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
                    ForEach($plan.exercises) { $item in
                        HomeCard { row($item) }
                    }
                    Button {
                        store.add(plan)
                        FinnHaptics.play(.success)
                        dismiss()
                    } label: {
                        Text("Validate workout")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!plan.isComplete)
                    .accessibilityIdentifier("plan.validate")
                    .accessibilityHint(plan.isComplete ? "" : "Tick every exercise first")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(HomeStyle.background.ignoresSafeArea())
            .navigationTitle("Your workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: Binding<PlannedExercise>) -> some View {
        let name = ExerciseDefinition.definition(for: item.wrappedValue.exercise).copy.name
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                item.wrappedValue.isDone.toggle()
            }
            FinnHaptics.play(.selection)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.wrappedValue.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.wrappedValue.isDone ? Color.accentColor : HomeStyle.supportingText)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                    Text("\(item.wrappedValue.sets) sets of \(item.wrappedValue.reps)")
                        .font(.subheadline)
                        .foregroundStyle(HomeStyle.supportingText)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.wrappedValue.isDone ? "Done" : "Not done")
        .accessibilityHint("Double tap to change")
        .accessibilityIdentifier("plan.exercise.\(item.wrappedValue.exercise.rawValue)")
    }
}

/// the saved workouts, listed in the Workout tab
struct NextWorkoutsSection: View {
    var store: PlannedWorkoutStore = .shared
    var open: (PlannedWorkout) -> Void

    var body: some View {
        if !store.upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Next workouts")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HomeStyle.supportingText)
                    .accessibilityAddTraits(.isHeader)
                ForEach(store.upcoming) { workout in
                    Button { open(workout.reset) } label: {
                        HomeCard {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(summary(workout))
                                        .font(.body.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let done = workout.lastDoneAt {
                                        Text(
                                            "Last done \(done.formatted(date: .abbreviated, time: .omitted))"
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(HomeStyle.supportingText)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(HomeStyle.supportingText)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nextWorkout.row")
                }
            }
        }
    }

    private func summary(_ workout: PlannedWorkout) -> String {
        workout.exercises
            .map { ExerciseDefinition.definition(for: $0.exercise).copy.name }
            .joined(separator: ", ")
    }
}
