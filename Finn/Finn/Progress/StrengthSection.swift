import SwiftUI

/// the chosen exercise's best set per workout as bars, and where the trend points by a chosen date
struct StrengthSection: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    @State private var horizon: ProgressHorizon = .twoWeeks
    /// the estimate on screen; nil shows the measured workouts
    @State private var projection: StrengthProjection?
    /// bars standing from the left; the rest lie flat, waiting to grow
    @State private var revealed = Int.max
    @State private var collapsed = false
    @State private var isAnimating = false
    @State private var animation: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var typeSize

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
            if trend.points.isEmpty {
                ContentUnavailableView {
                    Label("No workouts yet", systemImage: "chart.bar")
                } description: {
                    Text("Record a \(exercise.definition.copy.shareNoun) set to see your best set for each workout.")
                }
                .accessibilityIdentifier("strength.empty")
            } else {
                StrengthChart(bars: bars(trend), metric: trend.metric, label: chartLabel,
                              revealed: revealed, collapsed: collapsed)
                if let projection, !collapsed {
                    legend
                    Text("At this pace, in \(projection.horizon.phrase) you'll do ^[\(projection.target) reps](inflect: true) in one set.")
                        .font(.title3.weight(.semibold))
                        .fontDesign(.rounded)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("strength.projection")
                }
            }
            Divider().padding(.vertical, 4)
            projectionControls(trend)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(DashboardGlass())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("strength.card")
        // another exercise or a new workout makes the estimate stale
        .onChange(of: trend) { reset() }
        .onDisappear { reset() }
    }

    @ViewBuilder private func projectionControls(_ trend: StrengthTrend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project my progress")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            switch trend.projectionStatus {
            case .needsWorkouts(let missing):
                note("Log at least \(StrengthTrend.minimumWorkouts) workouts of this exercise to project your progress. \(missing) to go.")
            case .needsMoreDays:
                note("Log workouts on at least two different days to project your progress.")
            case .ready:
                horizonPicker
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button("Project", systemImage: "chart.line.uptrend.xyaxis") { project(trend) }
                        .buttonStyle(.borderedProminent)
                        .tint(DashboardStyle.accent)
                        .disabled(isAnimating || projection?.horizon == horizon)
                        .accessibilityIdentifier("strength.project")
                    if projection != nil {
                        Button("Back to history", systemImage: "chart.bar") { swap(to: nil, trend) }
                            .buttonStyle(.bordered)
                            .disabled(isAnimating)
                            .accessibilityIdentifier("strength.history")
                    }
                }
            }
        }
    }

    @ViewBuilder private var horizonPicker: some View {
        let picker = Picker("Projection horizon", selection: $horizon) {
            ForEach(ProgressHorizon.allCases) { Text($0.phrase).tag($0) }
        }
        .accessibilityIdentifier("strength.horizon")
        if typeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DashboardStyle.accent.opacity(0.35))
                .frame(width: 12, height: 12)
            Text("Projected from your trend: an estimate, not a target")
        }
        .font(.caption)
        .foregroundStyle(DashboardStyle.secondary)
        .accessibilityHidden(true)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DashboardStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chartLabel: String {
        let name = exercise.definition.copy.name
        return projection == nil ? String(localized: "\(name), best set per workout")
            : String(localized: "\(name), projected best set")
    }

    private func bars(_ trend: StrengthTrend) -> [StrengthBar] {
        if let projection {
            return projection.points.map {
                StrengthBar(id: "p\($0.date.timeIntervalSinceReferenceDate)", date: $0.date, value: $0.value,
                            isProjected: true)
            }
        }
        return trend.points.enumerated().map {
            StrengthBar(id: "w\($0.offset)", date: $0.element.date, value: $0.element.value, isProjected: false)
        }
    }

    private func project(_ trend: StrengthTrend) {
        guard let next = trend.projection(to: horizon) else { return }
        swap(to: next, trend)
    }

    /// Brief chart update; Reduce Motion swaps the values without movement.
    private func swap(to next: StrengthProjection?, _ trend: StrengthTrend) {
        animation?.cancel()
        guard !reduceMotion else {
            projection = next
            revealed = .max
            collapsed = false
            return
        }
        isAnimating = true
        animation = Task {
            withAnimation(.easeIn(duration: 0.18)) { collapsed = true }
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            withTransaction(\.disablesAnimations, true) {
                projection = next
                revealed = 0
                collapsed = false
            }
            for index in bars(trend).indices {
                try? await Task.sleep(for: .milliseconds(55))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.26)) { revealed = index + 1 }
            }
            revealed = .max
            isAnimating = false
        }
    }

    private func reset() {
        animation?.cancel()
        animation = nil
        projection = nil
        revealed = .max
        collapsed = false
        isAnimating = false
    }
}
