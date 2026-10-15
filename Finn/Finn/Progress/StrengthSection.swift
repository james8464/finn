import SwiftUI

/// the chosen exercise's best set per session over time, with where the trend points next
struct StrengthSection: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = 32.0

    private var trend: StrengthTrend { StrengthTrend.make(for: exercise, history: history) }

    var body: some View {
        let trend = trend
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Best set")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Most reps in one set").font(.footnote).foregroundStyle(DashboardStyle.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(trend.best.map { StrengthUnit.format($0, trend.metric) } ?? "—")
                    .font(.system(size: metricSize, weight: .bold))
                    .foregroundStyle(DashboardStyle.accent)
                Text(StrengthUnit.title(trend.metric)).font(.subheadline).foregroundStyle(DashboardStyle.secondary)
            }
            .accessibilityElement(children: .combine)
            if trend.points.isEmpty {
                Text("No workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(DashboardStyle.secondary)
            } else {
                StrengthChart(trend: trend)
                legend(hasProjection: !trend.projection.isEmpty)
                Text(trend.projection.isEmpty
                     ? String(localized: "A projection appears after \(StrengthTrend.minimumDays) days of training.")
                     : String(localized: "Projection: the trend of your last \(trend.fittedSessions) sessions, not a target."))
                    .font(.caption)
                    .foregroundStyle(DashboardStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(DashboardGlass())
        .accessibilityIdentifier("strength.card")
    }

    private func legend(hasProjection: Bool) -> some View {
        HStack(spacing: 16) {
            swatch("Measured", dashed: false)
            if hasProjection { swatch("Projection", dashed: true) }
        }
        .font(.caption)
        .foregroundStyle(DashboardStyle.secondary)
        .accessibilityHidden(true)
    }

    private func swatch(_ title: LocalizedStringKey, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: 18, y: 1))
            }
            .stroke(DashboardStyle.accent.opacity(dashed ? 0.6 : 1),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashed ? [4, 4] : []))
            .frame(width: 18, height: 2)
            Text(title)
        }
    }
}
