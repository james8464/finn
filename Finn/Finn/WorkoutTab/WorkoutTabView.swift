import SwiftUI

/// the Workout tab: Finn's next workout, the sessions before it, and the button that sets up a new one
struct WorkoutTabView: View {
    let message: FinnCoachMessage
    let history: [WorkoutSessionSummary]
    /// whether a session reached Apple Fitness, for its row
    let savedToFitness: (WorkoutSessionSummary) -> Bool
    let openSession: (WorkoutSessionSummary) -> Void
    let launch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.cardSpacing) {
                NextWorkoutCard(workout: message.workout, quote: message.quote)
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
}
