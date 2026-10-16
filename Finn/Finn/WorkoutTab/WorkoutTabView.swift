import SwiftUI

/// the Workout tab: Finn's next workout and its exercises, the sessions before it, and the button
/// that sets up a new one
struct WorkoutTabView: View {
    let message: FinnCoachMessage
    let history: [WorkoutSessionSummary]
    /// whether a session reached Apple Fitness, for its row
    let savedToFitness: (WorkoutSessionSummary) -> Bool
    let openSession: (WorkoutSessionSummary) -> Void
    let launch: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.cardSpacing) {
                // Finn speaks the card below: the badge sits over its title
                FinnBadge(showsOutline: true)
                    .padding(.leading, 20)
                    .accessibilityLabel("Finn, your coach")
                NextWorkoutCard(workout: message.workout)
                if !message.workout.exercises.isEmpty {
                    exercises
                }
                Text("Previous workouts")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 14)
                if history.isEmpty {
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(DashboardStyle.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(DashboardGlass(showsBorder: false))
                } else {
                    ForEach(history) { session in
                        WorkoutHistoryRow(session: session, savedToFitness: savedToFitness(session)) {
                            openSession(session)
                        }
                    }
                }
            }
            .padding(.horizontal, 21)
            .padding(.top, 5)
            // room for the floating button over the last row
            .padding(.bottom, 96)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("workout.scroll")
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .background { HomeBackdrop() }
        .overlay(alignment: .bottomTrailing) {
            LaunchWorkoutButton(action: launch)
                .padding(.trailing, 21)
                .padding(.bottom, 16)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
    }

    /// the exercises of the next workout, in order, framed like Home's Last workout
    private var exercises: some View {
        FinnOutline {
            VStack(alignment: .leading, spacing: 12) {
                DashboardHeading("Exercises").accessibilityAddTraits(.isHeader)
                ForEach(message.workout.exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
            .modifier(DashboardCard())
        }
        .accessibilityIdentifier("workout.exercises")
    }

    /// name, then sets × reps; stacked at accessibility sizes
    private func exerciseRow(_ exercise: NextWorkout.Exercise) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(exercise.kind.chipName).font(.body.weight(.medium))
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: "\(exercise.sets) × \(exercise.reps)")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(DashboardStyle.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(exercise.kind.chipName), \(exercise.sets) sets of \(exercise.reps) reps",
                                   comment: "VoiceOver: one exercise of the next workout, with its sets and reps."))
    }
}
