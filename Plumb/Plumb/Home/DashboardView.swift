import SwiftUI

enum HomeTab: String, CaseIterable {
    case home = "Home", posture = "Posture", coach = "Coach", workout = "Workout"

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
    static let lime = Color(red: 0.80, green: 0.97, blue: 0.35)
    static let secondary = Color.white.opacity(0.7)
}

/// What the 1.0 build hides. The Plumb+ banner waits for the subscription (1.1): App Store rule
/// 2.1(a) refuses placeholder content, so it is not shown until it opens something real.
enum DashboardFlags {
    static let showsPlumbPlusBanner = false
}

struct HomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("HomeBackdrop")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(.black.opacity(0.16))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct DashboardGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 15

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                if reduceTransparency {
                    shape.fill(Color(white: 0.09))
                } else {
                    shape.fill(.ultraThinMaterial).opacity(0.8).environment(\.colorScheme, .dark)
                    shape.fill(.black.opacity(0.16))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.13)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
    }
}

struct HomeTabBar: View {
    @Binding var selection: HomeTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var glassSelection

    var body: some View {
        tabs
            .background {
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(HomeTab.allCases, id: \.self) { tab in
                            Color.clear
                                .overlay {
                                    if selection == tab { selectionCapsule }
                                }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        .padding(4)
        // Glass must not sample another Liquid Glass layer. Keep the shell a material surface
        // and render the labels above the independently morphing native glass selection.
        .modifier(DashboardGlass(radius: 48))
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, 12)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    // Animate only the bar. Changing pages should respond immediately.
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 24, weight: tab == .home ? .semibold : .regular))
                            .overlay(alignment: .topTrailing) {
                                if tab == .coach {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11, weight: .medium))
                                        .offset(x: 9, y: -5)
                                }
                            }
                            .frame(height: 28)
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey(tab.rawValue))
                            .font(.caption2.weight(selection == tab ? .medium : .regular))
                    }
                    .foregroundStyle(selection == tab ? DashboardStyle.lime : DashboardStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .padding(.vertical, 1)
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var selectionCapsule: some View {
        if reduceTransparency {
            Capsule().fill(Color(white: 0.04))
                .matchedGeometryEffect(id: "selection", in: glassSelection)
        } else {
            Capsule().fill(.black.opacity(0.16))
                .glassEffect(.regular.tint(.black.opacity(0.28)).interactive(!reduceMotion), in: Capsule())
                .glassEffectID("selection", in: glassSelection)
                .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        }
    }
}

struct DashboardView: View {
    let history: [WorkoutSessionSummary]
    let exercise: ExerciseKind
    /// Badges earned so far (`Badges/`), for the Awards card.
    var badges: [EarnedBadge] = []
    let open: (HomeRoute) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40.0

    // Reference values are available only in explicitly labelled design previews.
    private var isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-plumb-dashboard-preview")
        #else
        false
        #endif
    }

    /// The most reps Plumb measured in one set of the chosen exercise. Plumb measures no load, so
    /// the record is in reps, never in kilograms.
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

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Home")
                        .font(.system(size: titleSize, weight: .bold))
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
                        .foregroundStyle(DashboardStyle.lime)
                }

                card(.lastWorkout, id: "home.lastSession") {
                    VStack(alignment: .leading, spacing: 8) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 28) {
                                    heading("Last workout")
                                    durationLabel
                                }
                                Spacer(minLength: 0)
                                scoreRing.padding(.top, 10)
                            }
                            VStack(alignment: .leading, spacing: 16) {
                                heading("Last workout")
                                durationLabel
                                scoreRing
                            }
                        }
                        HStack {
                            Spacer()
                            Text(isPreview ? "Oct 13, 2026" : history.first.map {
                                $0.startedAt.formatted(date: .abbreviated, time: .omitted)
                            } ?? "No workouts yet")
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardStyle.secondary)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                    card(.posture, id: "home.posture") {
                        metric(title: "Posture", subtitle: exercise.chipName,
                               label: "Average score", value: isPreview ? "78" : "—", unit: nil)
                    }
                    card(.weights, id: "home.weights") {
                        metric(title: "Best set", subtitle: exercise.chipName,
                               label: "Most reps in one set", value: bestReps, unit: "reps")
                    }
                    card(.history, id: "home.sessions") {
                        VStack(alignment: .leading, spacing: 0) {
                            heading("Sessions")
                            Spacer(minLength: 30)
                            Text(history.isEmpty ? "No sessions recorded." : "\(history.count) sessions recorded.")
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

                if DashboardFlags.showsPlumbPlusBanner {
                    plusBanner
                }
            }
            .padding(.horizontal, 21)
            .padding(.top, 5)
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
    }

    /// The Plumb+ banner, kept for 1.1 behind `DashboardFlags.showsPlumbPlusBanner`.
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
                            heading("Plumb+")
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
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Duration").font(.subheadline).foregroundStyle(DashboardStyle.secondary)
        }
    }

    private var scoreRing: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(.white.opacity(0.13), lineWidth: 10)
                if isPreview {
                    Circle().trim(from: 0, to: 0.78)
                        .stroke(DashboardStyle.lime, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(isPreview ? "78" : "—").font(.system(size: 26, weight: .bold))
                    Text("/ 100").font(.caption).foregroundStyle(DashboardStyle.secondary)
                }
            }
            .frame(width: 96, height: 96)
            .padding(5)
            Text("Avg. posture score").font(.system(size: 11)).foregroundStyle(DashboardStyle.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPreview ? "Sample average posture score, 78 out of 100" : "Posture score not available yet")
    }

    private func metric(title: String, subtitle: String, label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            heading(title)
            Text(subtitle).font(.footnote).foregroundStyle(DashboardStyle.secondary)
            Text(label).font(.footnote).foregroundStyle(DashboardStyle.secondary).padding(.top, 7)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 32, weight: .bold)).foregroundStyle(DashboardStyle.lime)
                if let unit { Text(unit).font(.subheadline).foregroundStyle(DashboardStyle.secondary) }
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
                                Capsule().fill(index >= 9 ? DashboardStyle.lime : .white.opacity(0.25))
                                    .frame(height: index == 10 ? 38 : (index == 0 ? 12 : 20))
                            }
                        }
                }
            }
            .frame(height: 38)
            HStack(spacing: 0) {
                ForEach(["12 AM", "6 AM", "12 PM", "6 PM"], id: \.self) { time in
                    Text(time).font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(DashboardStyle.secondary)
        }
        .accessibilityHidden(true)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
    }

    private func card<Content: View>(_ route: HomeRoute, id: String, @ViewBuilder content: () -> Content) -> some View {
        Button { open(route) } label: {
            content().padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .modifier(DashboardGlass())
                .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(id)
    }
}
