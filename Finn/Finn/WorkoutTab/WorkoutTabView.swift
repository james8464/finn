import SwiftUI

/// the Workout tab: Finn's next workout and its exercises, the sessions before it, and the button
/// that sets up a new one
struct WorkoutTabView: View {
    @State private var planDraft: PlannedWorkout?
    @State private var pendingWorkoutStart: PlannedWorkout?
    @State private var generatesDraft = false
    let message: FinnCoachMessage
    let history: [WorkoutSessionSummary]
    /// set when Home's coach card opened the tab: the previous workouts stay blurred until tapped
    @Binding var blursPreviousWorkouts: Bool
    /// whether a session reached Apple Fitness, for its row
    let savedToFitness: (WorkoutSessionSummary) -> Bool
    let openSession: (WorkoutSessionSummary) -> Void
    let launch: () -> Void
    var planningContext: WorkoutPlanningContext? = nil
    var suggestedPlan: PlannedWorkout? = nil
    var onStartWorkout: ((PlannedWorkout) -> Void)? = nil
    var store: PlannedWorkoutStore = .shared
    var guided: GuidedWorkout? = nil
    var onResume: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

    var body: some View {
        ScrollView(.vertical) { workoutContents }
        .accessibilityIdentifier("workout.scroll")
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .background { HomeBackdrop() }
        .overlay(alignment: .bottomTrailing) {
            LaunchWorkoutButton(action: launch)
                .padding(.trailing, 21)
                .padding(.bottom, 16)
        }
        .sheet(item: $planDraft, onDismiss: startRequestedWorkout) {
            WorkoutPlanView(plan: $0, store: store,
                            planningContext: generatesDraft ? planningContext : nil,
                            onStart: workoutStartAction)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { generatesDraft = true; planDraft = planningContext.map { PersonalisedWorkoutRules.make(context: $0) } ?? WorkoutPlanner.make(history: history) } label: {
                    Label("New workout", systemImage: "plus")
                }
                .accessibilityIdentifier("workout.new")
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
    }

    private var workoutContents: some View {
            VStack(alignment: .leading, spacing: DashboardStyle.cardSpacing) {
                // Finn speaks the card below: the badge sits over its title
                FinnBadge(showsOutline: true)
                    .padding(.leading, DashboardStyle.cardSpacing + 20)
                    .accessibilityLabel("Finn, your coach")
                nextWorkoutOutline
                if let guided, let onResume {
                    HomeCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(guided.progressedSets) of \(guided.totalSets) sets completed")
                            Button("Resume guided workout", action: onResume)
                                .accessibilityIdentifier("workout.resumeGuided")
                        }
                    }
                }
                NextWorkoutsSection(store: store) { generatesDraft = false; planDraft = $0 }
                previousWorkouts
                    .blur(radius: blursPreviousWorkouts ? 6 : 0)
                    .accessibilityHidden(blursPreviousWorkouts)
                    .overlay {
                        if blursPreviousWorkouts {
                            // the first tap only clears the blur; the rows open from the next one
                            Button {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                    blursPreviousWorkouts = false
                                }
                                FinnHaptics.play(.selection)
                            } label: {
                                Color.clear.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show previous workouts")
                            .accessibilityIdentifier("workout.history.reveal")
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

    private var workoutStartAction: ((PlannedWorkout) -> Void)? {
        guard onStartWorkout != nil else { return nil }
        return { plan in queueWorkoutStart(plan) }
    }

    private func queueWorkoutStart(_ plan: PlannedWorkout) {
        pendingWorkoutStart = plan
    }

    private func startRequestedWorkout() {
        guard let requested = pendingWorkoutStart else { return }
        pendingWorkoutStart = nil
        onStartWorkout?(requested)
    }

    private var canOpenSuggestedWorkout: Bool {
        if let suggestedPlan {
            return (1...6).contains(suggestedPlan.exercises.count)
                && Set(suggestedPlan.exercises.map(\.id)).count == suggestedPlan.exercises.count
                && suggestedPlan.exercises.allSatisfy { (1...3).contains($0.sets) && (1...20).contains($0.reps) }
        }
        return (1...6).contains(message.workout.exercises.count)
            && message.workout.exercises.allSatisfy { (1...3).contains($0.sets) && (1...20).contains($0.reps) }
    }

    /// the sessions before the next workout, newest first
    private var previousWorkouts: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.cardSpacing) {
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
    }

    /// the next workout and its exercises in one light pink outline, like Home's Finn card and
    /// Last workout
    private var nextWorkoutOutline: some View {
        let hasExercises = !message.workout.exercises.isEmpty
        return FinnOutline(topRadius: DashboardStyle.finnCardRadius,
                           bottomRadius: hasExercises ? DashboardStyle.cardRadius : DashboardStyle.finnCardRadius) {
            VStack(spacing: DashboardStyle.cardSpacing) {
                Button {
                    guard canOpenSuggestedWorkout else { return }
                    generatesDraft = false
                    planDraft = suggestedPlan ?? PlannedWorkout(exercises: message.workout.exercises.map {
                        PlannedExercise(id: $0.id, exercise: $0.kind, sets: $0.sets, reps: $0.reps)
                    })
                } label: {
                    NextWorkoutCard(workout: message.workout)
                }
                .buttonStyle(.plain)
                .disabled(!canOpenSuggestedWorkout)
                .accessibilityHint("Review sets and reps, then follow this workout")
                .accessibilityIdentifier("workout.suggestedPlan")
                if hasExercises { exercises }
            }
        }
    }

    /// the exercises of the next workout, in order, on a glass card
    private var exercises: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardHeading("Exercises").accessibilityAddTraits(.isHeader)
            ForEach(message.workout.exercises) { exercise in
                exerciseRow(exercise)
            }
        }
        .modifier(DashboardCard())
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
