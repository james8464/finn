import SwiftUI

/// the chosen exercise drawn moving, with a pause. Still with Reduce Motion
struct MovementAnimationCard: View {
    let exercise: ExerciseKind
    @State private var playsIllustration = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Illustrated movement")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !reduceMotion {
                    Button(playsIllustration ? "Pause" : "Play") {
                        playsIllustration.toggle()
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("posture.playback")
                }
            }
            ExerciseFigureView(kind: exercise, lineColour: DashboardStyle.accent, figureColour: .white,
                               animates: playsIllustration)
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("posture.illustration")
            Text(reduceMotion ? "Motion paused for Reduce Motion" : "Illustration for guidance; bodies and ranges vary")
                .font(.caption)
                .foregroundStyle(DashboardStyle.secondary)
        }
        .padding(16)
        .modifier(DashboardGlass())
    }
}

/// the written steps for the chosen exercise
struct MovementStepsCard: View {
    let exercise: ExerciseKind

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to move")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(PostureGuideSteps.forExercise(exercise), id: \.self) { step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(DashboardStyle.accent)
                        .accessibilityHidden(true)
                    Text(step).font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(DashboardGlass())
    }
}
