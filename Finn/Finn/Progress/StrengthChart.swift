import Charts
import SwiftUI

/// one bar: a workout's best set, or an estimate for a day ahead
struct StrengthBar: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
    let isProjected: Bool
}

/// best sets as solid pink bars, estimates as faint ones. The first `revealed` bars stand at full
/// height; the rest, and every bar while `collapsed`, lie flat and clear so the section can
/// animate them out and back in
struct StrengthChart: View {
    let bars: [StrengthBar]
    let metric: StrengthMetric
    let label: String
    var revealed = Int.max
    var collapsed = false

    var body: some View {
        Chart(Array(bars.enumerated()), id: \.element.id) { index, bar in
            let stands = !collapsed && index < revealed
            BarMark(x: .value("Workout", bar.id), y: .value("Reps", stands ? bar.value : 0), width: .ratio(0.6))
                .foregroundStyle(DashboardStyle.accent.opacity(bar.isProjected ? 0.35 : 1))
                .cornerRadius(4)
                .opacity(stands ? 1 : 0)
                .accessibilityLabel(bar.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(describe(bar))
        }
        .chartYScale(domain: 0...top)
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    // a categorical axis labels every bar, so only some get a date
                    if let id = value.as(String.self), labelled.contains(id),
                       let bar = bars.first(where: { $0.id == id }) {
                        Text(bar.date, format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spoken)
        .accessibilityIdentifier("strength.chart")
    }

    /// room above the tallest bar, so growing bars never rescale the axis
    private var top: Double { max(1, ((bars.map(\.value).max() ?? 0) * 1.15).rounded(.up)) }

    /// at most four dates under the bars: the first, the last and two between
    private var labelled: Set<String> {
        guard bars.count > 4 else { return Set(bars.map(\.id)) }
        let last = bars.count - 1
        return Set([0, last / 3, 2 * last / 3, last].map { bars[$0].id })
    }

    private var spoken: String {
        bars.map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(describe($0))" }
            .joined(separator: "; ")
    }

    private func describe(_ bar: StrengthBar) -> String {
        let value = "\(StrengthUnit.format(bar.value, metric)) \(StrengthUnit.title(metric))"
        return bar.isProjected ? String(localized: "\(value), estimate") : value
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
