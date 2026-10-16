import SwiftUI

/// how to do the chosen exercise well, and what Finn has seen of the person doing it
struct PostureSection: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MovementAnimationCard(exercise: exercise)
            MovementStepsCard(exercise: exercise)
            PostureMomentsCard()
            MeasuredFormCard(
                exercise: exercise,
                evidence: PostureGuideEvidence.make(for: exercise, history: history)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("posture.guide")
    }
}
