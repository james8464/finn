import SwiftUI

struct PostureGuideView: View {
    let history: [WorkoutSessionSummary]
    @State private var exercise: ExerciseKind
    @State private var playsIllustration = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(history: [WorkoutSessionSummary], initialExercise: ExerciseKind) {
        self.history = history
        _exercise = State(initialValue: initialExercise)
    }

    private var evidence: PostureGuideEvidence {
        PostureGuideEvidence.make(for: exercise, history: history)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose an exercise")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ExerciseKind.allCases, id: \.rawValue) { kind in
                            Button {
                                exercise = kind
                            } label: {
                                Text(kind.chipName)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .background(exercise == kind ? DashboardStyle.accent : Color.white.opacity(0.12),
                                                in: Capsule())
                                    .foregroundStyle(exercise == kind ? .black : .white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("posture.exercise.\(kind.rawValue)")
                            .accessibilityAddTraits(exercise == kind ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Illustrated movement")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button(playsIllustration ? "Pause" : "Play") {
                            playsIllustration.toggle()
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("posture.playback")
                    }
                    ExerciseFigureView(kind: exercise, lineColour: DashboardStyle.accent,
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

                comparison
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("posture.guide")
        .foregroundStyle(.white)
        .background { HomeBackdrop() }
        .navigationTitle("Posture")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var comparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your movement and the guide")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let latest = evidence.latest {
                Text("Latest measured set")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(latest.analysis.reps.count)")
                    Text("reps")
                    Text("·")
                    Text(latest.capturedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .foregroundStyle(DashboardStyle.secondary)

                if !evidence.measurements.isEmpty {
                    ForEach(evidence.measurements, id: \.check) { measurement in
                        measurementRow(measurement)
                    }
                    if evidence.flagged.isEmpty {
                        Text("No recurring issue found in the clear reps. Keep the movement consistent.")
                            .font(.subheadline)
                    } else if let first = evidence.flagged.first {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try next")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DashboardStyle.accent)
                            Text(first.check.nextAction)
                                .font(.body)
                        }
                    }
                    ForEach(evidence.trends, id: \.check) { trend in
                        Text(trend.sentence)
                            .font(.subheadline)
                            .foregroundStyle(DashboardStyle.secondary)
                    }
                } else if let issue = evidence.movementIssue {
                    Text("What Finn noticed")
                        .font(.subheadline.weight(.semibold))
                    Text(issue.title(for: exercise.definition))
                    Text("Try next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DashboardStyle.accent)
                    Text(exercise.definition.copy.nextAction)
                } else {
                    Text(exercise.definition.expectedView == .side
                         ? String(localized: "No reliable side-view form comparison for this set. Keep your whole body in view and record another set.")
                         : String(localized: "No specific movement change measured for this set. Keep your whole body in view and record another set."))
                        .font(.subheadline)
                        .foregroundStyle(DashboardStyle.secondary)
                }
            } else {
                Text("Record a set of this exercise to see your measured movement here.")
                    .font(.subheadline)
                    .foregroundStyle(DashboardStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(DashboardGlass())
        .accessibilityIdentifier("posture.comparison")
    }

    private func measurementRow(_ measurement: FormMeasurement) -> some View {
        let flagged = evidence.flagged.contains { $0.check == measurement.check }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: flagged ? "arrow.up.forward" : "checkmark.circle")
                .foregroundStyle(flagged ? DashboardStyle.accent : .green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(measurement.check.subject.capitalized)
                    .font(.subheadline.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Guide:").foregroundStyle(DashboardStyle.secondary)
                    Text(measurement.check.guidePoint)
                }
                .font(.caption)
                HStack(spacing: 4) {
                    Text("Your set:").foregroundStyle(DashboardStyle.secondary)
                    Text("\(measurement.faulty)/\(measurement.judged)")
                    Text("readable reps flagged")
                }
                .font(.caption)
                .foregroundStyle(DashboardStyle.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
