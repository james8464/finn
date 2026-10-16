import SwiftUI

struct PostureGuideView: View {
    let history: [WorkoutSessionSummary]
    @State private var exercise: ExerciseKind
    @State private var playsIllustration = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

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
                                    .background(exercise == kind ? DashboardStyle.accent : AppPageStyle.surface,
                                                in: Capsule())
                                    .foregroundStyle(exercise == kind ? Color.black : Color.primary)
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
                        Text(exercise.definition.copy.name)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button(playsIllustration ? "Pause" : "Play") {
                            playsIllustration.toggle()
                        }
                        .font(.subheadline)
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(.bordered)
                        .disabled(reduceMotion)
                        .accessibilityIdentifier("posture.playback")
                    }
                    ExerciseFigureView(kind: exercise, lineColor: AppPageStyle.tint,
                                       animates: playsIllustration && !reduceMotion)
                        .frame(height: 230)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("posture.illustration")
                    Text(reduceMotion ? "Motion paused for Reduce Motion" : "Illustrated guide · ranges vary")
                        .font(.caption)
                        .foregroundStyle(AppPageStyle.secondaryText)
                }
                .modifier(AppSurface())

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
                .modifier(AppSurface())

                comparison
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("posture.guide")
        .foregroundStyle(Color.primary)
        .background(AppPageStyle.background.ignoresSafeArea())
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
                .foregroundStyle(AppPageStyle.secondaryText)

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
                            .foregroundStyle(AppPageStyle.secondaryText)
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
                        .foregroundStyle(AppPageStyle.secondaryText)
                }
            } else {
                Text("Record a set of this exercise to see your measured movement here.")
                    .font(.subheadline)
                    .foregroundStyle(AppPageStyle.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AppSurface())
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
                    Text("Guide:").foregroundStyle(AppPageStyle.secondaryText)
                    Text(measurement.check.guidePoint)
                }
                .font(.caption)
                HStack(spacing: 4) {
                    Text("Your set:").foregroundStyle(AppPageStyle.secondaryText)
                    Text("\(measurement.faulty)/\(measurement.judged)")
                    Text("readable reps flagged")
                }
                .font(.caption)
                .foregroundStyle(AppPageStyle.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
