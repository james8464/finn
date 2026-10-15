import SwiftUI

/// read local data off the main thread; retain failures for the existing recovery interface
nonisolated struct FinnStartupSnapshot: Sendable {
    let history: Result<[WorkoutSessionSummary], Error>
    let badges: [EarnedBadge]

    static func load(historyURL: URL? = nil, badgesURL: URL? = nil) -> Self {
        let history = Result { try LocalSessionStore(url: historyURL).load() }
        let badges = (try? LocalBadgeStore(url: badgesURL).load()) ?? []
        return Self(history: history, badges: badges)
    }
}

struct FinnStartupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot: FinnStartupSnapshot?
    @State private var pendingURL: URL?
    @State private var showsMark = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let snapshot {
                ContentView(source: CameraPoseSource.live(),
                            store: WidgetSharingSessionStore(base: LocalSessionStore()),
                            preferences: .app, announcer: LiveAnnouncer(),
                            fitness: HealthKitWorkoutExporter(), health: HealthKitReader(),
                            connectsAccessories: true, startup: snapshot,
                            launchURL: $pendingURL, routesURLsFromParent: true)
                    .onAppear {
                        // mount native navigation without an insertion animation, then uncover it
                        withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.32)) {
                            showsMark = false
                        }
                    }
            }
            if showsMark {
                FinnLaunchMark()
                    .allowsHitTesting(snapshot == nil)
                    .accessibilityHidden(snapshot != nil)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard snapshot == nil else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                FinnStartupSnapshot.load()
            }.value
            guard !Task.isCancelled else { return }
            // no minimum display time or network dependency; open as soon as local data is ready
            snapshot = loaded
        }
        .onOpenURL { url in
            // queue cold-start links until ContentView can consume them, including during its fade
            pendingURL = url
        }
    }
}

/// the icon's three plates settle along its forward slant, then quietly breathe if loading lasts
struct FinnLaunchMark: View {
    var previewReducesMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    private var reduceMotion: Bool { systemReducesMotion || previewReducesMotion }
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || scenePhase != .active)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            ZStack {
                plate(.crown, elapsed: elapsed, delay: 0, colour: Color(red: 245/255, green: 247/255, blue: 250/255))
                plate(.middle, elapsed: elapsed, delay: 0.055, colour: Color(red: 1, green: 45/255, blue: 146/255))
                    .opacity(reduceMotion || elapsed < 0.7 ? 1 : 0.90 + 0.10 * cos((elapsed - 0.7) * .pi / 1.2))
                plate(.stem, elapsed: elapsed, delay: 0.09, colour: Color(red: 198/255, green: 204/255, blue: 213/255))
            }
            .frame(width: 156, height: 156)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
        .accessibilityIdentifier("launch.loading")
    }

    private func plate(_ plate: FinnLogoPlate, elapsed: TimeInterval,
                       delay: TimeInterval, colour: Color) -> some View {
        let progress = reduceMotion ? 1 : min(1, max(0, (elapsed - delay) / 0.48))
        let remaining = pow(1 - progress, 3)
        return plate.fill(colour)
            .offset(x: -3 * remaining, y: 10 * remaining)
            .opacity(1 - 0.7 * remaining)
    }
}
