import Charts
import SwiftUI

/// measured bests as a solid pink line with points; the projection as a fainter dashed line from
/// the last measured point
struct StrengthChart: View {
    let trend: StrengthTrend

    var body: some View {
        Chart {
            ForEach(trend.points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value),
                         series: .value("Series", "Measured"))
                    .foregroundStyle(DashboardStyle.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(DashboardStyle.accent)
                    .symbolSize(30)
            }
            ForEach(trend.projection) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value),
                         series: .value("Series", "Projection"))
                    .foregroundStyle(DashboardStyle.accent.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("strength.chart")
    }

    private var accessibilityLabel: String {
        String(localized: "\(trend.exercise.definition.copy.name), \(StrengthUnit.title(trend.metric)) per session")
    }

    private var accessibilityValue: String {
        var parts = trend.points.map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(StrengthUnit.format($0.value, trend.metric))"
        }
        if let end = trend.projection.last {
            parts.append(String(localized: "Projection, \(end.date.formatted(date: .abbreviated, time: .omitted)): \(StrengthUnit.format(end.value, trend.metric))"))
        }
        return parts.joined(separator: "; ")
    }
}

/// the words and numbers for a strength metric
enum StrengthUnit {
    static func title(_ metric: StrengthMetric) -> String {
        switch metric {
        case .reps: String(localized: "reps")
        case .kilograms: String(localized: "kg")
        case .seconds: String(localized: "seconds")
        }
    }

    static func format(_ value: Double, _ metric: StrengthMetric) -> String {
        switch metric {
        case .reps, .seconds: value.formatted(.number.precision(.fractionLength(0)))
        case .kilograms: value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}
