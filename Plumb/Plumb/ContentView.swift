import SwiftUI
import UIKit

private enum PlumbStyle {
    static let ink = Color.primary
    static let supportingText = Color(uiColor: .secondaryLabel)
    static let primaryButtonText = HomeStyle.onAccent
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: WorkoutSessionModel
    @State private var observationSpeaker = ObservationSpeaker()
    /// Headphones and a paired Apple Watch; idle unless `connectsAccessories`.
    @State private var accessories = AccessoryMonitor()
    /// The set in progress on the Lock Screen and in the Dynamic Island (`Widgets/SetLiveActivity.swift`).
    @State private var liveActivity = SetLiveActivity()
    /// True for the live camera, and for demo input only behind `-plumb-watch-demo`.
    private let connectsAccessories: Bool
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    /// History, Options or Privacy, opened from the first screen.
    @State private var tabRoutes: [HomeTab: HomeRoute] = [:]
    @State private var sessionRoute: HomeRoute?
    private var route: HomeRoute? {
        get { model.stage == .ready ? tabRoutes[selectedTab] : sessionRoute }
        nonmutating set {
            if model.stage == .ready { tabRoutes[selectedTab] = newValue }
            else { sessionRoute = newValue }
        }
    }
    @State private var selectedTab: HomeTab = .home
    @State private var keyboardVisible = false
    @State private var showsPlumbDemo = false
    /// What the camera does, shown once before iOS asks for it.
    @State private var showsCameraPrimer = false
    /// The first-launch screens (`Onboarding/`), also replayed from Options.
    @State private var showsOnboarding: Bool
    /// Badges earned from the saved history (`Badges/`).
    @State private var badges: BadgeLedger
    private let preferences: PlumbPreferences
    /// The live rep count, large enough to read from a few steps away, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var liveCountSize: CGFloat = 64
    /// Live advice during a set: a short order that fits on one line and reads from three metres.
    @ScaledMetric(relativeTo: .largeTitle) private var liveCueSize: CGFloat = 44
    private var destructiveLabelColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 69 / 255, blue: 58 / 255, alpha: 1)
                : UIColor(red: 198 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1)
        })
    }
    #if DEBUG
    private var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") }
    private var isVideoFileInput: Bool { ProcessInfo.processInfo.arguments.contains("-plumb-video-file") }
    private var usesTestDarkAppearance: Bool {
        ProcessInfo.processInfo.arguments.contains("-plumb-ui-dark")
    }
    private var isValidationMode: Bool { ProcessInfo.processInfo.arguments.contains("-plumb-validation") }
    private var isCaptureStage: Bool {
        switch model.stage {
        case .framing, .countdown, .capturing, .analyzing: return true
        default: return false
        }
    }
    private var isErrorStage: Bool {
        if case .error = model.stage { return true }
        return false
    }
    #endif

    @MainActor init(source: any PoseStreaming, store: any SessionStoring = LocalSessionStore(),
                    narrator: ComparisonNarrator? = nil,
                    exerciseClassifier: (any ExerciseClassifying)? = CoreMLExerciseClassifier.bundled(),
                    preferences: PlumbPreferences = .standard,
                    announcer: (any LiveAnnouncing)? = nil,
                    fitness: (any FitnessWorkoutSaving)? = nil,
                    health: (any HealthReading)? = nil,
                    connectsAccessories: Bool = false,
                    badgeStore: (any BadgeStoring)? = nil,
                    showsOnboarding: Bool? = nil) {
        _model = State(initialValue: WorkoutSessionModel(source: source, store: store,
                                                         narrator: narrator,
                                                         exerciseClassifier: exerciseClassifier,
                                                         preferences: preferences,
                                                         announcer: announcer,
                                                         fitness: fitness,
                                                         health: health))
        self.connectsAccessories = connectsAccessories
        self.preferences = preferences
        _badges = State(initialValue: BadgeLedger(store: badgeStore ?? LocalBadgeStore()))
        // Demo and recorded input skip the welcome unless asked for it (`-plumb-ui-onboarding`).
        _showsOnboarding = State(initialValue: showsOnboarding ?? !preferences.onboardingCompleted)
    }

    /// Demo or recorded input, marked as such on the watch too.
    private var usesSyntheticInput: Bool {
        #if DEBUG
        return isDemo || isVideoFileInput
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            // Keep each tab's navigation and Coach draft alive while a set is on screen.
            setup
                .opacity(model.stage == .ready ? 1 : 0)
                .allowsHitTesting(model.stage == .ready)
                .accessibilityHidden(model.stage != .ready)
            if model.stage != .ready {
                NavigationStack {
                    sessionContent
                        .navigationDestination(item: $sessionRoute) { destinationPage($0) }
                }
                .background(HomeStyle.background)
            }
        }
        #if DEBUG
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            guard route == nil, let index = arguments.firstIndex(of: "-plumb-open"),
                  arguments.indices.contains(index + 1) else { return }
            switch arguments[index + 1] {
            case "coach": selectedTab = .coach
            case "workout": selectedTab = .workout
            case "history": route = .history
            case "options": route = .options
            case "privacy": route = .privacy
            case "awards": route = .awards
            case "health": model.showsPersonalizationOffer = true
            default: break
            }
        }
        #endif
        .safeAreaInset(edge: .top, spacing: 0) {
            #if DEBUG
            if isDemo && !isCaptureStage && !isErrorStage { demoIndicator }
            #endif
        }
        .tint(HomeStyle.accent)
        #if DEBUG
        .preferredColorScheme(usesTestDarkAppearance ? .dark : nil)
        #endif
        // The phone stands a few steps away and nobody touches it: keep the screen on while the
        // camera is open, or Auto-Lock interrupts framing and throws the set away.
        .onChange(of: model.stage, initial: true) { _, stage in
            UIApplication.shared.isIdleTimerDisabled = Self.keepsScreenOn(stage)
            if stage == .ready { sessionRoute = nil }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        // Siri or a shortcut asked for a set or the history; a set in progress is never interrupted.
        .onChange(of: SiriLaunchRequests.shared.pending, initial: true) { _, _ in applySiriRequest() }
        .onChange(of: model.stage) { _, _ in applySiriRequest() }
        // Personalize with Health: read again whenever the first screen shows.
        .task(id: model.stage == .ready) {
            if model.stage == .ready { await model.refreshHealth() }
        }
        .sheet(isPresented: Binding(
            get: { model.showsPersonalizationOffer },
            set: { if !$0 { model.showsPersonalizationOffer = false } }
        )) {
            PersonalizationOfferView { personalize in
                Task { await model.answerPersonalizationOffer(personalize: personalize) }
            }
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(preferences: preferences) { profile in
                // The answers take effect now, not at the next launch.
                model.speaksLive = profile.speaksLive
                if let first = profile.favoriteExercises.first { model.selectedExercise = first }
                showsOnboarding = false
            }
        }
        .fullScreenCover(isPresented: $showsPlumbDemo) {
            PlumbDemoView {
                showsPlumbDemo = false
                selectedTab = .workout
            }
        }
        // Badges follow the saved history: checked at launch and after every saved set. Only the set
        // just saved is celebrated; at launch (`lastSavedSetID` nil) the history's badges are recorded quietly.
        .onChange(of: model.history, initial: true) { _, history in
            badges.update(history: history, celebrating: model.lastSavedSetID)
        }
        .task {
            liveActivity.attach(to: model, demoInput: usesSyntheticInput)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-plumb-ui-live-activity-sample") {
                liveActivity.showSample()
            }
            #endif
            guard connectsAccessories else { return }
            accessories.start(model: model, demoInput: usesSyntheticInput)
        }
        // The home screen widget opens the camera on its exercise (`plumb://start-set`).
        .onOpenURL { url in
            guard let link = PlumbDeepLink(url), case .startSet(let key) = link,
                  model.stage == .ready || model.stage == .result else { return }
            if let key, let exercise = ExerciseKind(rawValue: key) { model.selectedExercise = exercise }
            if !usesSyntheticInput && CameraPermission.notAskedYet {
                showsCameraPrimer = true
            } else {
                Task { await model.startPreview() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && connectsAccessories { accessories.refreshHeadphones() }
            if phase != .active { observationSpeaker.stop() }
            if phase == .background { Task { await model.backgrounded() } }
            if phase == .active && model.historyIssue == .unavailable {
                model.retryHistory()
            }
            // The person may have allowed or turned off Plumb in Health settings meanwhile.
            if phase == .active { model.refreshFitnessAccess() }
        }
        .confirmationDialog("Delete this session?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete session", role: .destructive) {
                if let id = deleteCandidate { model.deleteHistory(id: id) }
                deleteCandidate = nil
            }
        } message: {
            // Plumb never deletes Health data: say so where the person decides.
            Text(deleteCandidateLeavesHealthWorkout
                 ? "Its measured set summaries will be removed from this iPhone. The workout saved to Apple Health stays there; you can delete it in the Health app."
                 : "Its measured set summaries will be removed from this iPhone.")
        }
        .alert("Delete all local data?", isPresented: $deleteAllRequested) {
            Button("Delete all data", role: .destructive) {
                model.deleteAllData()
                badges.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.leavesHealthWorkouts
                 ? "This removes saved sessions and any recovered history backups from this iPhone. Workouts saved to Apple Health stay there; you can delete them in the Health app."
                 : "This removes saved sessions and any recovered history backups from this iPhone.")
        }
    }

    /// Carries out what Siri asked ("Start a squat set in Plumb", "Show my history in Plumb") once the
    /// model can take it; otherwise the request waits for the next stage change.
    private func applySiriRequest() {
        guard let request = SiriLaunchRequests.shared.pending,
              SiriLaunchRequests.canApply(request, at: model.stage) else { return }
        SiriLaunchRequests.shared.pending = nil
        switch request {
        case .startSet(let exercise):
            route = nil
            observationSpeaker.stop()
            model.selectedExercise = exercise
            if !usesSyntheticInput && CameraPermission.notAskedYet {
                showsCameraPrimer = true
            } else {
                Task { await model.startPreview() }
            }
        case .showHistory:
            route = .history
        }
    }

    /// Whether the session about to be deleted has a workout in Apple Health, which stays there.
    private var deleteCandidateLeavesHealthWorkout: Bool {
        guard let id = deleteCandidate else { return false }
        return model.leavesHealthWorkout(forSession: id)
    }

    #if DEBUG
    private var demoIndicator: some View {
        Text("DEMO INPUT")
            .font(.caption.bold())
            .dynamicTypeSize(...DynamicTypeSize.large)
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.yellow, in: Capsule())
            .accessibilityHidden(true)
    }
    #endif

    @ViewBuilder private var sessionContent: some View {
        switch model.stage {
        case .ready: EmptyView()
        case .openingCamera: ProgressView("Opening camera")
        case .framing, .countdown, .capturing, .analyzing: capture
        case .result: result
        case .error(let issue): failure(issue)
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    NavigationStack {
                        tabContent(tab)
                            .navigationDestination(item: Binding(
                                get: { tabRoutes[tab] },
                                set: { tabRoutes[tab] = $0 }
                            )) { destinationPage($0) }
                            .toolbar {
                                if tab != .workout && tab != .home {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button { route = .account } label: {
                                            Label("Settings", systemImage: "gearshape")
                                        }
                                        .accessibilityIdentifier("home.account")
                                    }
                                }
                            }
                    }
                    .toolbar(tab == .home && tabRoutes[tab] == nil ? .hidden : .visible, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }
            if !keyboardVisible {
                HomeTabBar(selection: $selectedTab)
            }
        }
        .background { HomeBackdrop() }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    @ViewBuilder private func tabContent(_ tab: HomeTab) -> some View {
        switch tab {
        case .home:
            DashboardView(history: model.history, exercise: model.selectedExercise,
                          badges: badges.earned, tryPlumb: { selectedTab = .workout },
                          watchDemo: { showsPlumbDemo = true }) { route = $0 }
        case .workout: workoutSetup
        case .posture: historyList(title: "Posture", exercise: nil)
        case .coach: CoachView(history: model.history)
        }
    }

    @ViewBuilder private func destinationPage(_ destination: HomeRoute) -> some View {
        switch destination {
        case .history: historyPage
        case .options: optionsPage
        case .privacy: privacyPage
        case .coach: CoachView(history: model.history)
        case .lastWorkout:
            if let last = model.history.first {
                historyDetail(last)
            } else {
                ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.functional",
                                       description: Text("Start a set in the Workout tab. Your last workout will appear here."))
                    .navigationTitle("Last workout")
            }
        case .account: accountPage
        case .posture: historyList(title: "Posture", exercise: nil)
        case .weights: historyList(title: "Best set", exercise: model.selectedExercise)
        case .awards: BadgesView(ledger: badges)
        // The subscription does not exist yet (1.1): the banner is hidden, and its route lands on
        // the account page rather than on a placeholder.
        case .plus: accountPage
        }
    }

    private var accountPage: some View {
        List {
            Section {
                Label("Plumb", systemImage: "figure.strengthtraining.functional")
                    .font(.title2.weight(.semibold))
                    .padding(.vertical, 8)
                Text("Your workouts are stored on this iPhone.")
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { optionsPage } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
                NavigationLink { historyPage } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink { privacyPage } label: {
                    Label("Privacy", systemImage: "lock")
                }
            }
            Section("Account") {
                Text("No account is needed. Plumb keeps your saved workouts on this iPhone.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
    }

    private var workoutSetup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // After Done: whether the session reached Apple Fitness.
                if let save = model.fitnessSave {
                    HomeCard { fitnessStatus(save) }
                }
                // Framing that went on with no set (or nobody in view) closed the camera by itself.
                if let note = model.framingClosedNote {
                    HomeCard {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("setup.framingClosed")
                }
                // Cancel, or the app going to the background during a set, comes back here without Done.
                if let open = model.unfinishedSession {
                    HomeCard { unfinishedSessionLine(open) }
                }
                ExerciseChips(selection: Binding(
                    get: { model.selectedExercise },
                    set: { model.selectedExercise = $0 }
                ), order: preferences.exerciseOrder)
                .padding(.horizontal, -20)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Exercise")
                .accessibilityIdentifier("setup.exercise")
                ExerciseHeroCard(kind: model.selectedExercise, compact: !model.history.isEmpty)
                accessoryNotes
                // Personalize with Health: a line adapted to the person, with the data it rests on.
                if let note = model.readinessNote {
                    HomeCard { healthNote(note) }
                        .accessibilityIdentifier("setup.healthReadiness")
                }
                if let focus = model.focus {
                    HomeCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Your focus", systemImage: "scope")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(HomeStyle.supportingText)
                            Text(focus.focus)
                                .font(.body.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(focus.summary)
                                .font(.subheadline)
                                .foregroundStyle(HomeStyle.supportingText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("setup.focus")
                }
                if let last = model.history.first {
                    lastSessionCard(last)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                // Said where the decision is made: before the camera opens.
                Button { route = .privacy } label: {
                    Label(dynamicTypeSize.isAccessibilitySize ? "Camera privacy" : "Analyzed on this iPhone. No video is saved.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows what Plumb keeps and what it never records")
                .accessibilityIdentifier("home.privacy")
                Button {
                    if !usesSyntheticInput && CameraPermission.notAskedYet {
                        showsCameraPrimer = true
                    } else {
                        Task { await model.startPreview() }
                    }
                } label: {
                    PrimaryActionLabel(title: "Start a set")
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("home.start")
                .accessibilityHint("Opens the camera for \(selectedCopy.name.lowercased())")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(HomeStyle.background)
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { route = .history } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    Button { route = .coach } label: {
                        Label("Coach", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    Button { route = .awards } label: {
                        Label("Awards", systemImage: "rosette")
                    }
                    Button { route = .options } label: {
                        Label("Options", systemImage: "slider.horizontal.3")
                    }
                    Button { route = .privacy } label: {
                        Label("Privacy", systemImage: "lock")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .accessibilityIdentifier("home.more")
            }
        }
        .sheet(isPresented: $showsCameraPrimer) {
            CameraPrimer(onContinue: {
                showsCameraPrimer = false
                Task { await model.startPreview() }
            }, onPrivacy: {
                showsCameraPrimer = false
                route = .privacy
            })
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
    }

    /// The latest saved session, with what Plumb noticed in it, opening History.
    private func lastSessionCard(_ session: WorkoutSessionSummary) -> some View {
        let reps = session.sets.reduce(0) { $0 + $1.analysis.reps.count }
        var names: [String] = []
        for set in session.sets where !names.contains(set.exercise.definition.copy.name) {
            names.append(set.exercise.definition.copy.name)
        }
        let sets = String(localized: "\(session.sets.count) sets")
        let when: String = {
            let time = session.startedAt.formatted(date: .omitted, time: .shortened)
            if Calendar.current.isDateInToday(session.startedAt) { return String(localized: "Today, \(time)") }
            if Calendar.current.isDateInYesterday(session.startedAt) { return String(localized: "Yesterday, \(time)") }
            return session.startedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }()
        // The latest observation the person kept, word for word.
        let note = session.sets.last(where: { $0.cue != nil && $0.cueResponse != .notRelevant })?.cue?.observation
        return Button { route = .history } label: {
            HomeCard {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last session")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(HomeStyle.supportingText)
                        Text("\(names.joined(separator: ", ")) · \(reps) reps")
                            .font(.headline)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(when) · \(sets)")
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                        if let note {
                            Label(note, systemImage: "text.quote")
                                .font(.subheadline)
                                .padding(.top, 6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HomeStyle.supportingText)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your history")
        .accessibilityIdentifier("home.lastSession")
    }

    /// One short line about the latest save to Apple Health, with Try again when it can help.
    private func fitnessStatus(_ save: FitnessSaveReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(save.status.text, systemImage: Self.fitnessSymbol(save.status))
                .font(.subheadline)
                .accessibilityIdentifier("fitness.status")
            if save.status.offersRetry && model.savesToFitness {
                Button("Try again") { Task { await model.saveToFitness(sessionID: save.sessionID) } }
                    .font(.subheadline)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("fitness.retry")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The session still open on the first screen, with a way to end it as Done does.
    private func unfinishedSessionLine(_ session: WorkoutSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.sets.count == 1 ? "Session in progress · 1 measured set"
                 : "Session in progress · \(session.sets.count) measured sets")
                .font(.subheadline)
            if model.offersFitness && model.savesToFitness {
                Text("Finish it to save it to Apple Fitness.")
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
            }
            Button("Finish session") { Task { await model.finishSession() } }
                .font(.subheadline)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityIdentifier("setup.finishSession")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func fitnessSymbol(_ status: FitnessSaveStatus) -> String {
        switch status {
        case .saving: "arrow.triangle.2.circlepath"
        case .saved: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        case .needsPermission: "hand.raised"
        case .unavailable: "heart.slash"
        }
    }

    /// Under the Apple Fitness switch: why it is off for demo input, or what Health allows.
    private var fitnessOptionNote: String? {
        guard model.offersFitness else { return String(localized: "Demo and recorded input are never saved to Apple Health.") }
        guard model.savesToFitness else { return nil }
        switch model.fitnessAccess {
        case .denied: return String(localized: "Health doesn’t let Plumb save workouts. \(FitnessSaveStatus.needsPermission.text).")
        case .unavailable: return FitnessSaveStatus.unavailable.text + "."
        case .authorized, .notDetermined: return nil
        }
    }

    /// In a saved session: saved to Fitness, or a way to save it when the option is on.
    @ViewBuilder private func fitnessHistoryLine(_ session: WorkoutSessionSummary) -> some View {
        if let record = model.fitnessRecord(forSession: session.id) {
            Label("Saved to Fitness on \(record.savedAt.formatted(date: .abbreviated, time: .shortened))",
                  systemImage: "checkmark.circle")
                .font(.subheadline)
                .padding(.top, 32)
                .accessibilityIdentifier("history.savedToFitness")
        } else if model.offersFitness && model.savesToFitness {
            VStack(alignment: .leading, spacing: 4) {
                if let save = model.fitnessSave, save.sessionID == session.id {
                    Label(save.status.text, systemImage: Self.fitnessSymbol(save.status))
                        .font(.subheadline)
                }
                if model.canSaveToFitness(session) {
                    // Saving the session still open on the first screen finishes it.
                    Button(model.unfinishedSession?.id == session.id ? "Finish session and save to Fitness"
                           : "Save to Fitness") { Task { await model.saveToFitness(sessionID: session.id) } }
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("history.saveToFitness")
                }
            }
            .padding(.top, 32)
        }
    }

    private static func keepsScreenOn(_ stage: WorkoutStage) -> Bool {
        switch stage {
        case .openingCamera, .framing, .countdown, .capturing, .analyzing: true
        case .ready, .result, .error: false
        }
    }

    /// A personalized line and, under it, the Health data it rests on.
    private func healthNote(_ note: HealthNote) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.text)
                .font(.subheadline)
            Text(note.basis)
                .font(.footnote)
                .foregroundStyle(PlumbStyle.supportingText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// What connected headphones or a paired Apple Watch add to the chosen exercise, one line each.
    @ViewBuilder private var accessoryNotes: some View {
        let lines = AccessoryGuide.setupLines(for: model.selectedExercise, status: accessories.status,
                                              speaksLive: model.speaksLive)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.accessory) { line in
                    Label(line.text, systemImage: line.accessory == .appleWatch ? "applewatch" : "headphones")
                }
            }
            .font(.footnote)
            .foregroundStyle(PlumbStyle.supportingText)
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("setup.accessories")
        }
    }

    private var selectedCopy: ExerciseCopy { model.selectedExercise.definition.copy }
    private var captureCopy: ExerciseCopy { model.captureExercise.definition.copy }

    private var privacyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    privacyFact("video.slash", "No video is saved",
                                "Frames are analyzed on this iPhone, then dropped.")
                    privacyFact("icloud.slash", "No account, no upload",
                                "Plumb has no server. Set summaries are saved on this iPhone.")
                    privacyFact("trash", "Yours to delete",
                                "Remove one session or everything in History.")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Video is processed on this iPhone and never saved.")
                    Text("Plumb uses the camera to measure a supported exercise from the side. Camera frames and pose points stay on this iPhone.")
                    Text("One camera view cannot assess your whole technique or prevent injury.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved results").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Measured set summaries are saved on this iPhone so you can review previous sets. They include which measured patterns each set showed, so Plumb can point out your most frequent one.")
                    Text("Saved summaries may be included in your device backup.")
                    Text("Delete saved sessions in History.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Health").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("If you turn on Save workouts to Apple Fitness, Plumb writes each finished session to Health as a workout, with your permission: its time, sets, measured reps, and exercise names.")
                    Text("Plumb reads Health only if you turn on Personalize with Health: heart rate, resting heart rate, heart rate variability, VO2 max, workouts, active energy, steps, sleep, age, weight and height, to adapt its advice to you. It never writes calories or heart rate, and nothing leaves this iPhone through Plumb.")
                    Text("Health keeps these workouts under your Health settings. Deleting history in Plumb doesn’t remove them; delete them in the Health app.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional audio").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Plumb says the countdown, each rep, and short live observations, and you can tap to hear an observation, through your iPhone or headphones. Turn spoken reps off in Options. Plumb does not record sound or use the microphone.")
                }
                Divider()
                if WatchBridge.isWatchAppBundled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apple Watch").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("When Plumb is open on your paired Apple Watch, this iPhone sends it the exercise name, the set’s progress, the rep count, live observations, and the result line. Video and pose points stay on this iPhone. The watch does not measure your movement.")
                    }
                    Divider()
                }
                if model.recognitionMethod != .unavailable {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optional exercise recognition").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Unless you turn it off in Options, Plumb reads pose points after a set to recognize the exercise from your joint angles. Pose points and video stay on this iPhone.")
                    }
                    Divider()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional explanation").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("On supported iPhones, Apple's on-device model can explain a measured comparison. The camera video is never given to the model.")
                }
                Divider()
                Link("Full privacy policy", destination: URL(string: "https://james8464.github.io/hackathon-project/privacy.html")!)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(HomeStyle.background)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
    }

    /// One plain fact at the top of Privacy.
    private func privacyFact(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var optionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercise recognition").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    if model.recognitionMethod != .unavailable {
                        Toggle("Recognize the exercise automatically", isOn: Binding(
                            get: { model.recognizesExercise },
                            set: { model.recognizesExercise = $0 }
                        ))
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .tint(Color(uiColor: .systemGreen))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("options.recognizeExercise")
                    }
                    switch model.recognitionMethod {
                    case .keypointModel, .angleModel:
                        Text("After each set, an on-device model trained by the Plumb team guesses the exercise from your pose points. If it isn’t confident, Plumb uses the exercise you chose. Its accuracy is still being tested.")
                    case .angleRules:
                        Text("After each set, Plumb guesses the exercise from your joint angles: which joint bends, how far, and how your torso is tilted. If the guess isn’t clear, Plumb uses the exercise you chose.")
                    case .unavailable:
                        Text("This build has no exercise recognition, so Plumb uses the exercise you choose on the first screen.")
                    }
                    if model.hasExerciseClassifier {
                        Toggle("Use the trained model instead (experimental)", isOn: Binding(
                            get: { model.usesTrainedModel },
                            set: { model.usesTrainedModel = $0 }
                        ))
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .tint(Color(uiColor: .systemGreen))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("options.useTrainedModel")
                    }
                }
                .optionCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Camera angle").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    Toggle("Check the camera angle in 3D", isOn: Binding(
                        get: { model.checksCameraAngle },
                        set: { model.checksCameraAngle = $0 }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color(uiColor: .systemGreen))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.checkCameraAngle")
                    Text("On supported iPhones, Plumb estimates your body’s 3D position to tell a side view from a front or angled one. When you are a little turned, it suggests turning and still counts your reps. When you clearly face the camera, or face away, it still counts your reps but gives no posture advice. If it asks you to turn while your side already faces the camera, switch this off.")
                }
                .optionCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hands-free").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    Toggle("Start and stop sets for me", isOn: Binding(
                        get: { model.handsFree },
                        set: { model.handsFree = $0 }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color(uiColor: .systemGreen))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.handsFree")
                    Text("Once you hold still in position for a moment, Plumb counts down and starts the set. It ends the set when you walk back to your iPhone, or when you stop moving after your reps. Start set and Stop set still work.")
                    Toggle("Say reps aloud", isOn: Binding(
                        get: { model.speaksLive },
                        set: { model.speaksLive = $0 }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color(uiColor: .systemGreen))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.speaksLive")
                    Text("Plumb says the countdown, each counted rep, and when a rep is clearly faster or shorter than your first reps of the set. It uses your AirPods or other headphones when they are connected, otherwise the iPhone speaker.")
                }
                .optionCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Fitness").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    Toggle("Save workouts to Apple Fitness", isOn: Binding(
                        get: { model.savesToFitness },
                        set: { isOn in
                            model.savesToFitness = isOn
                            // Permission in context: Health asks when the person turns this on.
                            if isOn { Task { await model.requestFitnessAccess() } }
                        }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color(uiColor: .systemGreen))
                    .frame(minHeight: 44)
                    .disabled(!model.offersFitness)
                    .accessibilityIdentifier("options.savesToFitness")
                    Text("When you finish a session (Done, or Finish session on the first screen), Plumb saves it to Apple Health as a strength training workout with its time and measured reps, never calories or heart rate, so it shows in the Fitness app.")
                    if let note = fitnessOptionNote {
                        Text(note)
                            .foregroundStyle(PlumbStyle.supportingText)
                            .accessibilityIdentifier("options.fitnessNote")
                    }
                }
                .optionCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personalize with Health").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    Toggle("Use my Health data", isOn: Binding(
                        get: { model.personalizesWithHealth },
                        // Permission in context: Health asks for each type when the person turns this on.
                        set: { isOn in Task { await model.setPersonalizesWithHealth(isOn) } }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color(uiColor: .systemGreen))
                    .frame(minHeight: 44)
                    .disabled(!model.offersHealthPersonalization)
                    .accessibilityIdentifier("options.personalizesWithHealth")
                    Text("Plumb adapts its advice to you: rest between sets, a lighter day after a short night or a heavy day, and your heart rate from Apple Watch. Each tip says which data it uses. Nothing leaves this iPhone, and Plumb works fully without it.")
                    if !model.offersHealthPersonalization {
                        Text("Demo and recorded input never read Health.")
                            .foregroundStyle(PlumbStyle.supportingText)
                    }
                    ForEach(HealthReadType.allCases, id: \.self) { type in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.title).font(.subheadline.weight(.semibold))
                            Text(type.use)
                                .font(.subheadline)
                                .foregroundStyle(PlumbStyle.supportingText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .optionCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
                    Text("The first-launch screens: your goal, your exercises, your level, the voice, and where to put your iPhone. Your answers set the order of the exercises and how the coach talks to you.")
                    Button("Replay the welcome") { showsOnboarding = true }
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("options.replayOnboarding")
                }
                .optionCard()
                #if DEBUG
                // Coach demo key and engine switch; absent from the Release build.
                CoachDeveloperSection()
                    .optionCard()
                #endif
            }
            .font(.subheadline)
            .foregroundStyle(PlumbStyle.supportingText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(HomeStyle.background)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder private var recognitionNote: some View {
        let chosen = model.captureExercise.definition.copy.name
        switch model.recognition {
        case .notAttempted:
            EmptyView()
        case .recognized(let kind, _):
            let name = kind.definition.copy.name
            Text(kind == model.captureExercise
                 ? "Recognized as \(name) on this iPhone."
                 : "Recognized as \(name) on this iPhone, so Plumb used it instead of \(chosen). Your next sets use \(name).")
                .font(.subheadline)
                .accessibilityIdentifier("result.recognition")
        case .uncertain:
            // Not sure: the person's own choice was used, as they expect. Nothing to add.
            EmptyView()
        }
    }

    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraFeedView(model: model)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.76)],
                           startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                #if DEBUG
                if isDemo || isVideoFileInput {
                    Text(isDemo ? "DEMO INPUT" : "VIDEO FILE INPUT")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(.yellow, in: Capsule())
                }
                #endif
                if model.stage == .capturing {
                    // During the set, everything to read sits at the top, under the status bar: the
                    // count in the corner and the advice banner across. The person fills the middle
                    // of the picture, and on 15 October the banner and the count, drawn there, hid the
                    // upper body and the skeleton of a push-up filmed from the floor.
                    if dynamicTypeSize.isAccessibilitySize {
                        status.frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top) {
                            watchLabel
                            Spacer(minLength: 0)
                            liveCount
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 8) {
                                status
                                watchLabel
                            }
                            Spacer(minLength: 0)
                            liveCount
                        }
                    }
                    liveCue
                } else {
                    status
                    watchLabel
                }
                #if DEBUG
                if isValidationMode && model.stage == .framing {
                    Text(model.previewDeviations.isEmpty ? "3D view: no estimate"
                         : "3D view: \(Int(model.previewDeviations.sorted()[model.previewDeviations.count / 2].rounded()))° from profile")
                        .font(.footnote.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.68), in: Capsule())
                        .accessibilityIdentifier("validation.liveView")
                }
                #endif
                Spacer()
                if model.stage == .framing {
                    Text("\u{00A0}\(captureCopy.framingPrompt)\u{00A0}")
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(captureCopy.framingPrompt)
                    if let focus = model.captureFocus {
                        Text("Focus: \(focus.focus)")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("capture.focus")
                    }
                    if model.handsFree {
                        handsFreeHint
                    }
                    Button { Task { await model.beginSet() } } label: {
                        Label("Start set", systemImage: "play.fill").foregroundStyle(.black)
                            .frame(minWidth: 160, minHeight: 32)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white)
                } else if model.stage == .capturing {
                    if let startedAt = model.captureStartedAt {
                        TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                            let seconds = max(0, Int(timeline.date.timeIntervalSince(startedAt)))
                            let time = String(format: "%02d:%02d", seconds / 60, seconds % 60)
                            Text(time)
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityLabel("Elapsed time")
                                .accessibilityValue(time)
                                .accessibilityIdentifier("capture.elapsed")
                        }
                    }
                    Button {
                        let tappedAt = ContinuousClock.now
                        Task { await model.endSet(tappedAt: tappedAt) }
                    } label: {
                        Label("Stop set", systemImage: "stop.fill").foregroundStyle(.white)
                            .frame(minWidth: 160, minHeight: 32)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.red)
                } else if case .countdown(let count) = model.stage {
                    Text("\(count)")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Starting in \(count)")
                } else {
                    ProgressView("Reviewing set").tint(.white)
                }
                if model.stage != .analyzing {
                    Button("Cancel") { Task { await model.cancel() } }
                        .buttonStyle(.plain)
                        .frame(minWidth: 120, minHeight: 44)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var watchLabel: some View {
        if accessories.status.isConnected(.appleWatch) {
            Label("Apple Watch connected", systemImage: "applewatch")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.68), in: Capsule())
                .accessibilityIdentifier("capture.watch")
        }
    }

    /// While framing hands-free: what to do, and how long until the set starts by itself.
    private var handsFreeHint: some View {
        let holding = model.handsFreeProgress > 0
        // Not `livePose`, which is new on every frame and made this whole view redraw with it.
        let seen = model.athleteInView
        return VStack(spacing: 8) {
            Text(holding ? "Hold still. The set starts by itself."
                 : seen ? "Plumb starts the set once it sees you clearly and you hold still."
                 : "Go to your spot. The set starts once you hold still.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            ProgressView(value: model.handsFreeProgress)
                .tint(.white)
                .frame(maxWidth: 180)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture.handsFree")
    }

    /// The latest live advice, such as "Sit lower", in large dark type on white so it reads from two or
    /// three metres away. It always takes the same place, at the top of the screen under the count
    /// row, and the slot stays empty until there is something to say, so nothing moves.
    private var liveCue: some View {
        Text(model.liveCaption ?? " ")
            .font(.system(size: liveCueSize, weight: .bold, design: .default))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: liveCueSize * 1.6)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .opacity(model.liveCaption == nil ? 0 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.liveCaption)
            .accessibilityHidden(model.liveCaption == nil)
            .accessibilityIdentifier("capture.liveCaption")
    }

    /// The reps counted so far, readable from where the person stands, in the top corner of the
    /// picture where it covers no one.
    private var liveCount: some View {
        VStack(spacing: 0) {
            Text("\(model.liveRepCount)")
                .font(.system(size: liveCountSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy, value: model.liveRepCount)
            // The exercise being measured, such as "push-ups", so a wrong choice shows before the reps
            // are done (13 October: push-ups filmed while Squat was chosen counted nothing).
            Text(captureCopy.name.lowercased() + (model.liveRepCount == 1 ? "" : "s"))
                .font(.headline)
        }
        // A dark backing keeps the white count readable over a bright camera image, like the other
        // labels drawn over the feed (the full accessibility audit checks this contrast).
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps counted")
        .accessibilityValue("\(model.liveRepCount)")
        .accessibilityIdentifier("capture.liveReps")
    }

    private var status: some View {
        HStack(spacing: 10) {
            if model.isRecording {
                Image(systemName: "viewfinder")
                Text("Analyzing live")
            } else if model.stage == .framing {
                switch model.framingStatus {
                case .checking:
                    Image(systemName: "viewfinder")
                    Text(captureCopy.checkingVisibility)
                case .adjustPosition:
                    Image(systemName: "viewfinder")
                    if let joint = model.unclearJoint {
                        // Théophile: say which joint is unclear instead of guessing.
                        Text("\(joint.localizedName) not clear: step back or add light")
                    } else {
                        Text(captureCopy.showJoints)
                    }
                case .landmarksVisible:
                    Image(systemName: "checkmark.circle.fill")
                    Text(captureCopy.jointsVisible)
                case .turnToExpectedView:
                    Image(systemName: "arrow.turn.up.right")
                    Text(model.captureExercise.definition.expectedView.turnPrompt)
                }
            } else {
                Image(systemName: "viewfinder")
                Text("Get ready")
            }
        }
        // Hands-free, the person reads it from their spot a few steps away.
        .font(model.handsFree ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.68), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var result: some View {
        // The action bar sits over the end of the scroll view, as in #10: a bar below it clips the
        // last visible line, which the large-text audit reports as clipped text.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(resultTitle)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                if model.endedEarly {
                    Text("The camera stopped during the set. Plumb reviewed the part it captured.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("result.endedEarly")
                }
                if model.endedAtLimit {
                    Text("Plumb ends a set after 2 minutes. It reviewed the reps before that.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("result.endedAtLimit")
                }
                if model.endedHandsFree {
                    Text("Plumb ended the set when you walked away or stopped moving.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("result.endedHandsFree")
                }
                if let result = model.result {
                    switch result {
                    case .measured(let analysis, let cue):
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(analysis.reps.count)")
                                .font(.largeTitle.bold()).monospacedDigit()
                            Text("measured reps").font(.headline).foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(analysis.reps.count) measured reps")
                        recognitionNote
                        if let note = model.movementNote {
                            Text(note)
                                .font(.subheadline)
                                .accessibilityIdentifier("result.movementNote")
                        }
                        ForEach(model.formNotes, id: \.self) { note in
                            Text(note)
                                .font(.subheadline)
                                .accessibilityIdentifier("result.formNote")
                        }
                        ForEach(model.resultHealthNotes, id: \.text) { note in
                            healthNote(note)
                                .accessibilityIdentifier("result.healthNote")
                        }
                        if let pattern = model.repeatedPattern {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your most frequent pattern came back")
                                    .font(.subheadline.weight(.semibold))
                                Text(pattern.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(PlumbStyle.supportingText)
                                Text(pattern.focus)
                                    .font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("result.repeatedPattern")
                        }
                        if model.historyIssue != nil {
                            Text("Couldn’t confirm this set was saved.")
                                .font(.subheadline)
                            if model.historyIssue == .unavailable {
                                Button("Retry saving") { model.retryHistory() }
                                    .frame(minHeight: 44, alignment: .leading)
                            } else {
                                NavigationLink("Review history") { historyPage }
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                        }
                        if let cue {
                            Divider().padding(.vertical, 12)
                            if model.cueDismissed {
                                Text("Observation marked not relevant.")
                                    .font(.body)
                                    .foregroundStyle(PlumbStyle.supportingText)
                            } else {
                                Text(cue.observation)
                                    .font(.title3.weight(.semibold))
                                Text("Observed in \(FormChecks.list(cue.repNumbers)).")
                                    .font(.subheadline)
                                    .foregroundStyle(PlumbStyle.supportingText)
                                nextAction(cue.nextAction)
                                    .padding(.top, 4)
                                if let spokenText = SpokenObservation.text(for: analysis, cue: cue) {
                                    Button {
                                        if observationSpeaker.isSpeaking {
                                            observationSpeaker.stop()
                                        } else {
                                            observationSpeaker.speak(spokenText)
                                        }
                                    } label: {
                                        Label(observationSpeaker.isSpeaking ? "Stop speaking" : "Listen to observation",
                                              systemImage: observationSpeaker.isSpeaking ? "stop.fill" : "speaker.wave.2")
                                            .frame(minHeight: 44, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button("Not relevant") {
                                    observationSpeaker.stop()
                                    model.dismissCue()
                                }
                                    .buttonStyle(.plain)
                                    .font(.subheadline)
                                    .foregroundStyle(PlumbStyle.supportingText)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                        } else {
                            Divider().padding(.vertical, 12)
                            if analysis.reps.count < 4 {
                                Text("Plumb needs at least four measured reps before it can show an observation.")
                                    .font(.title3)
                            } else {
                                Text("No clear pattern to call out in this set.").font(.title3)
                            }
                            Text("This is a camera measurement, not a full technique assessment.")
                                .font(.footnote)
                                .foregroundStyle(PlumbStyle.supportingText)
                        }
                        Divider().padding(.vertical, 12)
                        if let comparison = model.comparison {
                            comparisonView(comparison)
                        } else if let gap = model.comparisonGap {
                            Text(comparisonGapText(gap))
                                .foregroundStyle(PlumbStyle.supportingText)
                        }
                        DisclosureGroup("Rep details") {
                            repList(analysis.reps, exercise: model.resultExercise)
                        }
                        ShareLink(item: SetShareSummary.text(for: analysis, cue: cue,
                                                              cueDismissed: model.cueDismissed,
                                                              comparison: model.comparison,
                                                              exercise: model.resultExercise)) {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("result.shareSummary")
                        .accessibilityHint("Shares the measured summary without video")
                        // Last on the result, as in #10: higher up, the cards sat behind the bottom
                        // button on a short result and the contrast audit measured them through it.
                        if let extremes = model.repExtremes {
                            Divider().padding(.vertical, 12)
                            repExtremesView(extremes)
                        }
                    case .insufficientView(let reason):
                        recognitionNote
                        Text(reason)
                        if let hint = model.retakeHint {
                            Text(hint)
                                .foregroundStyle(PlumbStyle.supportingText)
                        }
                        // Changing an option here keeps the session, so the next set still compares.
                        NavigationLink("Options") { optionsPage }
                            .frame(minHeight: 44, alignment: .leading)
                            .accessibilityIdentifier("result.options")
                    case .failed(let reason):
                        Text(reason)
                    case .interrupted:
                        Text("Camera capture stopped before the set was complete.")
                    }
                }
                if !badges.justEarned.isEmpty {
                    BadgeUnlockCard(badges: badges.justEarned) { route = .awards }
                }
                #if DEBUG
                if isValidationMode, let milliseconds = model.lastStopToResultMilliseconds {
                    Text("Validation timing · Stop to result: \(milliseconds) ms")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("validation.stopToResult")
                }
                if isValidationMode {
                    Text("Validation 3D view · \(viewVerdictReadout(model.lastViewVerdict))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("validation.viewCheck")
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if dynamicTypeSize.isAccessibilitySize {
                    Button {
                        observationSpeaker.stop()
                        Task { await model.finishSession() }
                    } label: {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                Button {
                    observationSpeaker.stop()
                    Task { await model.startPreview() }
                } label: {
                    Text(retakeLabel)
                        .foregroundStyle(PlumbStyle.primaryButtonText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomeStyle.filledAccent)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(HomeStyle.background)
        .navigationTitle("Set summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                    observationSpeaker.stop()
                    Task { await model.cancel() }
                }
                .accessibilityHint("Change exercise or options while keeping this session open.")
                .accessibilityIdentifier("result.back")
            }
            if !dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        observationSpeaker.stop()
                        Task { await model.finishSession() }
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .onDisappear { observationSpeaker.stop() }
    }

    #if DEBUG
    private func viewVerdictReadout(_ verdict: ViewCheck.Verdict) -> String {
        switch verdict {
        case .unavailable:
            return "no 3D estimate"
        case .matches(let median, let count):
            return "median \(Int(median.rounded()))° from profile, \(count) estimates, accepted"
        case .angled(let median, let count):
            return "median \(Int(median.rounded()))° from profile, \(count) estimates, measured with a turn tip"
        case .mismatch(let median, let count):
            return "median \(Int(median.rounded()))° from profile, \(count) estimates, refused"
        }
    }
    #endif

    /// The set's deepest and shallowest reps side by side, drawn from their pose points.
    private func repExtremesView(_ extremes: RepExtremes) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deepest and shallowest rep")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                repSnapshotView(extremes.deepest, title: String(localized: "Deepest"))
                repSnapshotView(extremes.shallowest, title: String(localized: "Shallowest"))
            }
            Text("Drawn from the pose points of each rep’s lowest moment. No image is kept.")
                .font(.footnote)
                .foregroundStyle(PlumbStyle.supportingText)
        }
        .accessibilityIdentifier("result.repExtremes")
    }

    private func repSnapshotView(_ snapshot: RepSnapshot, title: String) -> some View {
        let definition = model.resultExercise.definition
        let cropped = SkeletonGeometry.cropped(snapshot.frame)
        let angleText = cropped.flatMap {
            SkeletonGeometry(frame: $0, exercise: definition, size: CGSize(width: 100, height: 100),
                             mirrored: false).angle?.text
        }
        return VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                guard let cropped else { return }
                let geometry = SkeletonGeometry(frame: cropped, exercise: definition, size: size, mirrored: false)
                SkeletonPainter.draw(geometry, in: &context, size: size, clear: .primary,
                                     labelText: Color(uiColor: .systemBackground), lineWidth: 2.5)
            }
            .frame(height: 180)
            .accessibilityHidden(true)
            // Only the text is the accessibility element, so its contrast is judged against the card,
            // not against the lines of the drawing above it.
            VStack(alignment: .leading, spacing: 6) {
                Text("\(title) · rep \(snapshot.number)")
                    .font(.subheadline.weight(.semibold))
                Text(definition.formattedDepth(snapshot.range))
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) rep, rep \(snapshot.number), \(definition.formattedDepth(snapshot.range))"
                                + (angleText.map { ", \($0)" } ?? ""))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonGapText(_ gap: ComparisonGap) -> LocalizedStringKey {
        switch gap {
        case .differentExercise:
            "Plumb compares sets of the same exercise. Do another set of this exercise to compare."
        case .tooFewReps:
            "Plumb compares sets with at least \(SetComparison.minimumReps) measured reps each."
        case .differentSide:
            "Your earlier sets were filmed from your other side, so Plumb can’t compare them."
        case .incompatibleSets:
            "These sets used different camera views, so Plumb can’t compare them reliably."
        case .partlyVisible:
            "Plumb saw this set only partly, so it doesn’t compare it with your earlier sets."
        }
    }

    private var resultTitle: LocalizedStringKey {
        switch model.result {
        case .measured: "Set reviewed"
        case .insufficientView: "Couldn’t assess this set"
        case .failed: "Couldn’t review this set"
        case .interrupted: "Set interrupted"
        case nil: "Set result"
        }
    }

    private var retakeLabel: LocalizedStringKey {
        if case .insufficientView = model.result { return "Retake set" }
        if case .measured(_, let cue) = model.result, cue != nil { return "Try this next set" }
        return "Try another set"
    }

    private func nextAction(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next set")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PlumbStyle.supportingText)
            Text(text)
                .font(.body)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var historyPage: some View { historyList(title: "History", exercise: nil) }

    /// The saved sessions, every one or only those with a set of `exercise`.
    private func historyList(title: LocalizedStringKey, exercise: ExerciseKind?) -> some View {
        let sessions = exercise.map { kind in
            model.history.filter { $0.sets.contains { $0.exercise == kind } }
        } ?? model.history
        let exerciseName = exercise?.definition.copy.name.lowercased()
        return List {
            if model.historyIssue == .corrupted {
                Section {
                    Text("Couldn’t read saved history").font(.headline)
                    Text("You can move the damaged file aside and start a new local history.")
                        .foregroundStyle(PlumbStyle.supportingText)
                    Button("Recover history") { model.recoverHistory() }
                }
            } else if model.historyIssue == .unavailable {
                Section {
                    Text(model.hasPendingDeletion ? "Deletion couldn’t finish" : "History temporarily unavailable")
                        .font(.headline)
                    Text(model.hasPendingDeletion
                         ? "Tap Try again to finish removing the local data."
                         : "The saved file could not be accessed. Unlock this iPhone, then try again.")
                        .foregroundStyle(PlumbStyle.supportingText)
                    Button("Try again") { model.retryHistory() }
                }
            } else if sessions.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundStyle(PlumbStyle.supportingText)
                            .accessibilityHidden(true)
                        Text(exerciseName.map { "No \($0) sets saved yet." } ?? "No saved sessions yet.")
                            .font(.headline)
                        Text(exerciseName.map { "Finish a \($0) set and it shows up here, with its reps and what Plumb noticed." }
                             ?? "Finish a set and it shows up here, with its reps and what Plumb noticed.")
                            .font(.subheadline)
                            .foregroundStyle(PlumbStyle.supportingText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Saved sessions") {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            NavigationLink { historyDetail(session) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    Text(model.fitnessRecord(forSession: session.id) == nil
                                         ? "\(session.sets.count) measured sets"
                                         : "\(session.sets.count) measured sets · Saved to Fitness")
                                        .font(.subheadline)
                                        .foregroundStyle(PlumbStyle.supportingText)
                                }
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            }
                            .accessibilityIdentifier("history.session")
                            .accessibilityHint("Review measured sets")
                            Button {
                                deleteCandidate = session.id
                            } label: {
                                Image(systemName: "trash")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(destructiveLabelColor)
                            .accessibilityLabel("Delete session from \(session.startedAt.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
            }
            Section {
                Button(role: .destructive) { deleteAllRequested = true } label: {
                    Text("Delete all local data")
                        .foregroundStyle(destructiveLabelColor)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
    }

    private func historyDetail(_ session: WorkoutSessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(session.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.bottom, 28)
                ForEach(session.sets.indices, id: \.self) { index in
                    let set = session.sets[index]
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set \(index + 1)").font(.title2.weight(.semibold))
                        Text(set.exercise.definition.copy.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(set.analysis.reps.count) measured reps")
                            .monospacedDigit()
                            .foregroundStyle(PlumbStyle.supportingText)
                        if let cue = set.cue {
                            if set.cueResponse == .notRelevant {
                                Text("Observation marked not relevant.")
                                    .foregroundStyle(PlumbStyle.supportingText)
                            } else {
                                Text(cue.observation).font(.body.weight(.semibold))
                                nextAction(cue.nextAction)
                            }
                        } else {
                            Text("No clear pattern to call out in this set.")
                        }
                        DisclosureGroup("Rep details") {
                            repList(set.analysis.reps, exercise: set.exercise)
                        }
                        .padding(.top, 8)
                    }
                    if index < session.sets.count - 1 {
                        Divider().padding(.vertical, 28)
                    }
                }
                fitnessHistoryLine(session)
                Text("These are camera measurements from one view, not a full technique assessment.")
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.top, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(HomeStyle.background)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with your previous set").font(.headline)
            Text(model.comparisonRecap?.text
                 ?? SetShareSummary.statement(for: comparison.rangeDirection, exercise: comparison.exercise))
                .font(.title3.weight(.semibold))
            if model.comparisonRecap?.source == .appleIntelligence {
                Text("Worded with Apple Intelligence")
                    .font(.caption).foregroundStyle(PlumbStyle.supportingText)
            }
            DisclosureGroup("Set measurements") {
                VStack(alignment: .leading, spacing: 12) {
                    comparisonMetric("Set 1", range: comparison.firstMedianRange,
                                     duration: comparison.firstMedianDuration,
                                     exercise: comparison.exercise)
                    comparisonMetric("Set 2", range: comparison.secondMedianRange,
                                     duration: comparison.secondMedianDuration,
                                     exercise: comparison.exercise)
                }
            }
            Text("This comparison describes one camera-visible measure, not overall technique or safety.")
                .font(.footnote)
            DisclosureGroup("How range is measured") {
                Text(comparison.exercise.definition.copy.rangeExplanation)
                    .font(.footnote)
            }
            if model.isGeneratingRecap {
                ProgressView("Rewording comparison")
            } else if model.comparisonRecap == nil {
                Button("Reword comparison") { Task { await model.explainComparison() } }
                    .buttonStyle(.plain)
                    .frame(minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 12)
    }

    private func comparisonMetric(_ title: LocalizedStringKey, range: Double, duration: Double,
                                  exercise: ExerciseKind) -> some View {
        let definition = exercise.definition
        let noun = definition.copy.rangeNoun
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text("\(noun.prefix(1).uppercased() + noun.dropFirst()): \(definition.formattedRange(range))")
            Text("Rep time: \(duration.formatted(.number.precision(.fractionLength(1)))) s")
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private func repList(_ reps: [RepMetric], exercise: ExerciseKind) -> some View {
        let definition = exercise.definition
        return VStack(alignment: .leading, spacing: 8) {
            Text("Measured reps").font(.headline)
            ForEach(reps, id: \.number) { rep in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rep \(rep.number)")
                        Spacer()
                        Text(rep.duration.formatted(.number.precision(.fractionLength(1))) + " s")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    ProgressView(value: min(1, rep.relativeRange / definition.rangeDisplayScale))
                        .tint(.secondary)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rep \(rep.number), \(rep.duration.formatted(.number.precision(.fractionLength(1)))) seconds, \(definition.copy.rangeAccessibilityName) \(definition.accessibleRange(rep.relativeRange))")
                .accessibilityIdentifier("rep.\(rep.number)")
                Divider()
            }
        }
    }

    private func failure(_ issue: CameraIssue) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.title)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
                Text(issue.title).font(.largeTitle.bold())
                Text(issue.message)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(PlumbStyle.supportingText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if issue.offersSettings {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text("Open Settings")
                            .foregroundStyle(PlumbStyle.primaryButtonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomeStyle.filledAccent)
                    Button("Try again") {
                        Task { await model.cancel(); await model.startPreview() }
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        Task { await model.cancel(); await model.startPreview() }
                    } label: {
                        Text("Try again")
                            .foregroundStyle(PlumbStyle.primaryButtonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomeStyle.filledAccent)
                }
                // The first screen, with History, Options, Privacy and an open session's Finish
                // session, stays reachable while the camera cannot be used.
                Button("Back") {
                    Task { await model.cancel() }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("failure.back")
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
