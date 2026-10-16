import SwiftUI

/// the latest measured set of the chosen exercise against the guide: each form check, what to try
/// next and how it moved since earlier sets
struct MeasuredFormCard: View {
    let exercise: ExerciseKind
    let evidence: PostureGuideEvidence

    var body: some View {
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
                        ?
                        String(
                            localized: "No reliable side-view form comparison for this set. Keep your whole body in view and record another set."
                        )
                        :
                        String(
                            localized: "No specific movement change measured for this set. Keep your whole body in view and record another set."
                        ))
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
