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
                    .allowsHitTesting(!showsMark)
                    .accessibilityHidden(showsMark)
            }
            if showsMark {
                FinnLaunchCover(readyToReveal: snapshot != nil) { showsMark = false }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard snapshot == nil else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                FinnStartupSnapshot.load()
            }.value
            guard !Task.isCancelled else { return }
            // mount navigation beneath the cover while its one-second sequence finishes
            snapshot = loaded
        }
        .onOpenURL { url in
            // queue cold-start links until ContentView can consume them, including during its fade
            pendingURL = url
        }
    }
}

/// shared by live startup and the replay preview: 760 ms presentation + 240 ms fade
private struct FinnLaunchCover: View {
    let readyToReveal: Bool
    var previewReducesMotion = false
    let onFinished: () -> Void
    @State private var startedAt = ContinuousClock.now
    @State private var isVisible = true

    var body: some View {
        FinnLaunchMark(previewReducesMotion: previewReducesMotion)
            .opacity(isVisible ? 1 : 0)
            .task(id: readyToReveal) {
                guard readyToReveal else { return }
                do {
                    try await ContinuousClock().sleep(until: startedAt.advanced(by: .milliseconds(760)))
                    try Task.checkCancellation()
                } catch { return }
                // never animate insertion of the native navigation underneath this cover
                withAnimation(.easeOut(duration: 0.24), completionCriteria: .removed) {
                    isVisible = false
                } completion: {
                    onFinished()
                }
            }
    }
}

#if DEBUG
/// replay the production sequence without relaunching the simulator or touching saved data
struct FinnLaunchPreview: View {
    var reducesMotion = false
    @State private var showsMark = true
    @State private var replayID = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Launch animation").font(.title2.bold())
                Text("1 second").foregroundStyle(.secondary)
                Button("Replay", systemImage: "arrow.counterclockwise") {
                    replayID += 1
                    showsMark = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityIdentifier("launch.replay")
            }
            .allowsHitTesting(!showsMark)
            .accessibilityHidden(showsMark)
            if showsMark {
                FinnLaunchCover(readyToReveal: true, previewReducesMotion: reducesMotion) {
                    showsMark = false
                }
                .id(replayID)
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif

/// the icon's three plates settle along its forward slant, then hold still
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
