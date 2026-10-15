import SwiftUI

enum HomeTab: String, CaseIterable {
    case home = "Home", posture = "Posture", coach = "Coach", workout = "Workout"

    var identifier: String { "tab.\(rawValue.lowercased())" }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .coach: "person"
        case .posture: "figure.run"
        case .workout: "plus"
        }
    }
}

enum DashboardStyle {
    /// Figma brand/pink/selection, node 68:12: #FF2D92 (sRGB)
    static let accent = Color(.sRGB, red: 1, green: 45.0 / 255, blue: 146.0 / 255, opacity: 1)
    static let secondary = Color.white.opacity(0.7)
}

/// what the 1.0 build hides. The Finn+ banner waits for the subscription (1.1): App Store rule
/// 2.1(a) refuses placeholder content, so it is not shown until it opens something real
enum DashboardFlags {
    static let showsFinnPlusBanner = false
}

struct DashboardView: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    /// badges earned so far (`Badges/`), for the Awards card
    var badges: [EarnedBadge] = []
    let tryFinn: () -> Void
    let watchDemo: () -> Void
    let open: (HomeRoute) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40.0
    @ScaledMetric(relativeTo: .largeTitle) private var durationSize = 44.0
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = 32.0
    @ScaledMetric(relativeTo: .body) private var scoreSize = 26.0
    @ScaledMetric(relativeTo: .body) private var detailSize = 11.0

    // reference values are available only in explicitly labelled design previews
    private var isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-finn-dashboard-preview")
        #else
        false
        #endif
    }

    /// the most reps Finn measured in one set of the chosen exercise. Finn measures no load, so
    /// the record is in reps, never in kilograms
    private var bestReps: String {
        if isPreview { return "12" }
        let best = history.flatMap(\.sets).filter { $0.exercise == exercise }
            .map { $0.analysis.reps.count }.max()
        return best.map(String.init) ?? "—"
    }

    private var duration: String {
        if isPreview { return "42:18" }
        guard let last = history.first, let workout = FitnessWorkout.make(from: last) else { return "—" }
        let seconds = Int(workout.activeDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var postureEvidence: PostureGuideEvidence {
        PostureGuideEvidence.make(for: exercise, history: history)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Home")
                        .font(.system(size: titleSize, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { open(.account) } label: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 21))
                            .frame(width: 44, height: 44)
                            .modifier(DashboardGlass(radius: 22))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Account settings")
                    .accessibilityIdentifier("home.account")
                }
                .padding(.bottom, 5)

                if isPreview {
                    Text("DESIGN PREVIEW · SAMPLE DATA")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DashboardStyle.accent)
                }

                tryFinnCard

                card(.lastWorkout, id: "home.lastSession") {
                    VStack(alignment: .leading, spacing: 8) {
                        if dynamicTypeSize.isAccessibilitySize {
                            // avoid measuring a discarded horizontal layout at large text sizes
                            VStack(alignment: .leading, spacing: 16) {
                                heading("Last workout")
                                durationLabel
                                setCountRing
                            }
                        } else {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 28) {
                                    heading("Last workout")
                                    durationLabel
                                }
                                Spacer(minLength: 0)
                                setCountRing.padding(.top, 10)
                            }
                        }
                        HStack {
                            Spacer()
                            Group {
                                if isPreview { Text("Oct 13, 2026") }
                                else if let last = history.first {
                                    Text(last.startedAt.formatted(date: .abbreviated, time: .omitted))
                                } else { Text("No workouts yet") }
                            }
                            .font(.system(size: detailSize))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(DashboardStyle.secondary)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                    card(.posture, id: "home.posture") {
                        VStack(alignment: .leading, spacing: 7) {
                            heading("Posture")
                            Text(exercise.chipName).font(.footnote).foregroundStyle(DashboardStyle.secondary)
                            Spacer(minLength: 12)
                            if !postureEvidence.measurements.isEmpty {
                                Text(postureEvidence.flagged.isEmpty
                                     ? String(localized: "No recurring issue")
                                     : String(localized: "\(postureEvidence.flagged.count) checks to review"))
                                    .font(.subheadline.weight(.semibold))
                            } else {
                                Text("See movement guide").font(.subheadline.weight(.semibold))
                            }
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(DashboardStyle.accent)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                    }
                    card(.weights, id: "home.weights") {
                        metric(title: "Best set", subtitle: exercise.chipName,
                               label: "Most reps in one set", value: bestReps, unit: "reps")
                    }
                    card(.history, id: "home.sessions") {
                        VStack(alignment: .leading, spacing: 0) {
                            heading("Sessions")
                            Spacer(minLength: 30)
                            Text(history.isEmpty ? String(localized: "No sessions")
                                 : String(localized: "\(history.count) sessions"))
                                .font(.footnote)
                                .foregroundStyle(DashboardStyle.secondary)
                            Spacer(minLength: 30)
                        }
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                    }
                    card(.awards, id: "home.awards") {
                        AwardsCardContent(badges: badges, heading: heading("Awards"))
                            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                    }
                }

                if DashboardFlags.showsFinnPlusBanner {
                    plusBanner
                }
            }
            .padding(.horizontal, 21)
            .padding(.top, 5)
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("summary.scroll")
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .background { HomeBackdrop() }
    }

    /// a solid brand-colour invitation to the real workout, with a separate illustrated preview
    private var tryFinnCard: some View {
        VStack(spacing: 0) {
            Button(action: tryFinn) {
                HStack(spacing: 16) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "viewfinder")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.08), in: Circle())
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Try Finn").font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.headline).accessibilityHidden(true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens workout setup for your first real set.")
            .accessibilityIdentifier("home.tryFinn")
            Rectangle().fill(.black.opacity(0.12)).frame(height: 1).padding(.horizontal, 20)
            Button(action: watchDemo) {
                Label("Watch the demo", systemImage: "play.circle")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("home.watchDemo")
        }
        .foregroundStyle(.black)
        .background(DashboardStyle.accent, in: RoundedRectangle(cornerRadius: 24))
    }

    /// the Finn+ banner, kept for 1.1 behind `DashboardFlags.showsFinnPlusBanner`
    private var plusBanner: some View {
                Button { open(.plus) } label: {
                    ZStack(alignment: .topLeading) {
                        GeometryReader { proxy in
                            Image("HomeBackdrop").resizable().scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                                .clipped()
                        }
                        LinearGradient(colors: [.black.opacity(0.2), .clear, .black.opacity(0.65)],
                                       startPoint: .top, endPoint: .bottom)
                        HStack {
                            heading("Finn+")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(width: 26, height: 26)
                                .background(.white.opacity(0.4), in: Circle())
                        }
                        .padding(16)
                    }
                    .frame(height: 165)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("home.plus")
    }

    private var durationLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(duration)
                .font(.system(size: durationSize, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Duration").font(.subheadline).foregroundStyle(DashboardStyle.secondary)
        }
    }

    private var setCountRing: some View {
        VStack(spacing: 5) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(isPreview ? "3" : history.first.map { String($0.sets.count) } ?? "—")
                    .font(.title.bold())
            } else {
            ZStack {
                Circle().stroke(.white.opacity(0.13), lineWidth: 10)
                Text(isPreview ? "3" : history.first.map { String($0.sets.count) } ?? "—")
                    .font(.system(size: scoreSize, weight: .bold))
            }
            .frame(width: 96, height: 96)
            .padding(5)
            }
            Text("Measured sets").font(.system(size: detailSize)).foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPreview ? String(localized: "Sample workout, 3 measured sets")
                            : history.first.map { String(localized: "\($0.sets.count) measured sets") }
                                ?? String(localized: "No measured sets yet"))
    }

    private func metric(title: String, subtitle: String, label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            heading(title)
            Text(subtitle).font(.footnote).foregroundStyle(DashboardStyle.secondary)
            Text(LocalizedStringKey(label)).font(.footnote).foregroundStyle(DashboardStyle.secondary).padding(.top, 7)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: metricSize, weight: .bold)).foregroundStyle(DashboardStyle.accent)
                if let unit { Text(LocalizedStringKey(unit)).font(.subheadline).foregroundStyle(DashboardStyle.secondary) }
            }
            miniatureChart.padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var miniatureChart: some View {
        VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<16) { index in
                    Capsule().fill(.white.opacity(0.045))
                        .overlay(alignment: .bottom) {
                            if isPreview && [0, 1, 6, 9, 10].contains(index) {
                                Capsule().fill(index >= 9 ? DashboardStyle.accent : .white.opacity(0.25))
                                    .frame(height: index == 10 ? 38 : (index == 0 ? 12 : 20))
                            }
                        }
                }
            }
            .frame(height: 38)
            // the empty real-data charts have no time series to label. Hours belong
            // only to the explicitly marked sample preview
            if isPreview { HStack(spacing: 0) {
                ForEach(["12 AM", "6 AM", "12 PM", "6 PM"], id: \.self) { time in
                    Text(time).font(.system(size: detailSize))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(DashboardStyle.secondary)
            }
        }
        .frame(minHeight: 54, alignment: .top)
        .accessibilityHidden(true)
    }

    private func heading(_ text: String) -> some View {
        Text(LocalizedStringKey(text)).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
    }

    private func card<Content: View>(_ route: HomeRoute, id: String, @ViewBuilder content: () -> Content) -> some View {
        Button { open(route) } label: {
            content().padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .modifier(DashboardGlass(showsBorder: false))
                .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(id)
    }
}
