import Charts
import SwiftUI
import UIKit

private enum FinnStyle {
    static let ink = Color.primary
    static let supportingText = AppPageStyle.secondaryText
    static let primaryButtonText = HomeStyle.onAccent
}

/// builds its content in its own body, so a pushed page follows the observable model it reads: a
/// navigation destination's closure is not run again when the model changes
private struct LiveContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private let routesURLsFromParent: Bool
    @Binding private var launchURL: URL?
    @State private var model: WorkoutSessionModel
    @State private var workoutPlanDraft: PlannedWorkout?
    @State private var observationSpeaker = ObservationSpeaker()
    @State private var workoutFeedback = WorkoutFeedback()
    /// headphones and a paired Apple Watch; idle unless `connectsAccessories`
    @State private var accessories = AccessoryMonitor()
    /// the set in progress on the Lock Screen and in the Dynamic Island (`Widgets/SetLiveActivity.swift`)
    @State private var liveActivity = SetLiveActivity()
    /// true for the live camera, and for demo input only behind `-finn-watch-demo`
    private let connectsAccessories: Bool
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    /// history, Options or Privacy, opened from the first screen
    @State private var tabRoutes: [HomeTab: HomeRoute] = [:]
    @State private var sessionRoute: HomeRoute?
    private var route: HomeRoute? {
        get { model.stage == .ready ? tabRoutes[selectedTab] : sessionRoute }
        nonmutating set {
            if model.stage == .ready {
                tabRoutes[selectedTab] = newValue
            } else {
                sessionRoute = newValue
            }
        }
    }

    @State private var selectedTab: HomeTab = .home
    @State private var keyboardVisible = false
    @State private var showsFinnDemo = false
    /// TEMPORARY with `FinnFirstTryTrigger.swift`: whether Home shows the coach card.
    @AppStorage(FinnFirstTry.key, store: FinnFirstTry.defaults) private var hasTriedFinn = false
    /// the next workout and Finn's line, the one source for the Home and Workout cards
    @State private var coachMessage = FinnCoachMessage()
    /// Home's coach card opened the Workout tab: its previous workouts stay blurred until tapped
    @State private var blursPreviousWorkouts = false
    /// the Progress tab's section and exercise, so Home's Posture card can open them
    @State private var progressSection: ProgressSection = .posture
    @State private var progressExercise: ExerciseKind?
    #if DEBUG
        @State private var didRunWatchAutoDemo = false
    #endif
    /// what the camera does, shown once before iOS asks for it
    @State private var showsCameraPrimer = false
    @State private var startsAfterCameraPrimer = false
    @State private var showsSetupPrivacy = false
    /// the first-launch screens (`Onboarding/`), also replayed from Options
    @State private var showsOnboarding: Bool
    /// badges earned from the saved history (`Badges/`)
    @State private var badges: BadgeLedger
    private let preferences: FinnPreferences
    /// the live rep count, large enough to read from a few steps away, scaled with Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var liveCountSize: CGFloat = 64
    /// live advice during a set: a short order that fits on one line and reads from three metres
    @ScaledMetric(relativeTo: .largeTitle) private var liveCueSize: CGFloat = 44
    private let destructiveLabelColour = Color(red: 1, green: 69 / 255, blue: 58 / 255)
    #if DEBUG
        @ScaledMetric(relativeTo: .body) private var demoLabelSize = 12.0
        private var isDemo: Bool {
            ProcessInfo.processInfo.arguments.contains("-finn-ui-demo")
        }

        // presentation exports hide debug chrome; input and storage remain synthetic and isolated
        private var isPresentationCapture: Bool {
            ProcessInfo.processInfo.arguments.contains("-finn-presentation-capture")
        }

        private var showsDemoIndicator: Bool {
            isDemo && !isPresentationCapture
        }

        private var isVideoFileInput: Bool {
            ProcessInfo.processInfo.arguments.contains("-finn-video-file")
        }

        private var isValidationMode: Bool {
            ProcessInfo.processInfo.arguments.contains("-finn-validation")
        }

        private var isCaptureStage: Bool {
            switch model.stage {
            case .framing,
                 .countdown,
                 .capturing,
                 .analyzing:
                return true
            default:
                return false
            }
        }

        private var isErrorStage: Bool {
            if case .error = model.stage {
                return true
            }
            return false
        }
    #endif

    @MainActor init(
        source: any PoseStreaming,
        store: any SessionStoring = LocalSessionStore(),
        narrator: ComparisonNarrator? = nil,
        exerciseClassifier: (any ExerciseClassifying)? = CoreMLExerciseClassifier.bundled(),
        preferences: FinnPreferences = .standard,
        announcer: (any LiveAnnouncing)? = nil,
        fitness: (any FitnessWorkoutSaving)? = nil,
        health: (any HealthReading)? = nil,
        connectsAccessories: Bool = false,
        badgeStore: (any BadgeStoring)? = nil,
        showsOnboarding: Bool? = nil,
        startup: FinnStartupSnapshot? = nil,
        launchURL: Binding<URL?> = .constant(nil),
        routesURLsFromParent: Bool = false
    ) {
        self.routesURLsFromParent = routesURLsFromParent
        _launchURL = launchURL
        _model = State(initialValue: WorkoutSessionModel(
            source: source,
            store: store,
            narrator: narrator,
            exerciseClassifier: exerciseClassifier,
            preferences: preferences,
            announcer: announcer,
            fitness: fitness,
            health: health,
            initialHistory: startup?.history
        ))
        self.connectsAccessories = connectsAccessories
        self.preferences = preferences
        _badges = State(initialValue: BadgeLedger(
            store: badgeStore ?? LocalBadgeStore(),
            initialEarned: startup?.badges
        ))
        // demo and recorded input skip the welcome unless asked for it (`-finn-ui-onboarding`)
        _showsOnboarding = State(initialValue: showsOnboarding ?? !preferences.onboardingCompleted)
    }

    /// demo or recorded input, marked as such on the watch too
    private var usesSyntheticInput: Bool {
        #if DEBUG
            return isDemo || isVideoFileInput
        #else
            return false
        #endif
    }

    private func handleLaunchURL(_ url: URL) {
        guard
            let link = FinnDeepLink(url), case .startSet(let key) = link,
            model.stage == .ready || model.stage == .result else {
            return
        }
        if let key, let exercise = ExerciseKind(rawValue: key) {
            model.selectedExercise = exercise
        }
        if !usesSyntheticInput && CameraPermission.notAskedYet {
            showsCameraPrimer = true
        } else {
            Task { await model.startPreview() }
        }
    }

    var body: some View {
        observedPresentation
            .confirmationDialog("Delete this session?", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: {
                    if !$0 {
                        deleteCandidate = nil
                    }
                }
            )) {
                Button("Delete session", role: .destructive) {
                    if let id = deleteCandidate {
                        model.deleteHistory(id: id)
                    }
                    deleteCandidate = nil
                }
            } message: {
                // Finn never deletes Health data: say so where the person decides
                Text(deleteCandidateLeavesHealthWorkout
                    ? "Its measured set summaries will be removed from this iPhone. The workout saved to Apple Health stays there; you can delete it in the Health app."
                    : "Its measured set summaries will be removed from this iPhone.")
            }
            .alert("Delete all local data?", isPresented: $deleteAllRequested) {
                Button("Delete all data", role: .destructive) {
                    model.deleteAllData()
                    badges.reset()
                    preferences.resetLocalChoices()
                    route = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(model.leavesHealthWorkouts
                    ? "This removes saved sessions, awards and preferences from this iPhone. Workouts saved to Apple Health stay there; you can delete them in the Health app."
                    : "This removes saved sessions, awards and preferences from this iPhone.")
            }
    }

    private var observedPresentation: some View {
        workoutPresentation
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && connectsAccessories {
                    accessories.refreshHeadphones()
                }
                if phase != .active {
                    observationSpeaker.stop()
                }
                if phase == .background {
                    Task { await model.backgrounded() }
                }
                if phase == .active && model.historyIssue == .unavailable {
                    model.retryHistory()
                }
                // the person may have allowed or turned off Finn in Health settings meanwhile
                if phase == .active {
                    model.refreshFitnessAccess()
                }
            }
    }

    private var workoutPresentation: some View {
        appearancePresentation
            // the phone stands a few steps away and nobody touches it: keep the screen on while the
            // camera is open, or Auto-Lock interrupts framing and throws the set away
            .onChange(of: model.stage, initial: true) { _, stage in
                UIApplication.shared.isIdleTimerDisabled = Self.keepsScreenOn(stage)
                if stage == .ready {
                    sessionRoute = nil
                }
            }
            .onChange(of: model.stage) { _, stage in
                switch stage {
                case .capturing:
                    workoutFeedback.play(
                        .setStarted,
                        haptics: model.hapticFeedback,
                        sound: model.soundFeedback
                    )
                case .result:
                    let sound: SoundFeedbackStyle
                    if case .measured = model.result {
                        sound = model.soundFeedback
                    } else {
                        sound = .off
                    }
                    workoutFeedback.play(.setFinished, haptics: model.hapticFeedback, sound: sound)
                default:
                    break
                }
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            // Siri or a shortcut asked for a set or the history; a set in progress is never interrupted
            .onChange(of: SiriLaunchRequests.shared.pending, initial: true) { _, _ in applySiriRequest() }
            .onChange(of: model.stage) { _, _ in applySiriRequest() }
            // personalise with Health: read again whenever the first screen shows
            .task(id: model.stage == .ready) {
                if model.stage == .ready {
                    await model.refreshHealth()
                }
            }
            .sheet(isPresented: Binding(
                get: { model.showsPersonalisationOffer },
                set: {
                    if !$0 {
                        model.showsPersonalisationOffer = false
                    }
                }
            )) {
                PersonalizationOfferView { personalise in
                    Task { await model.answerPersonalisationOffer(personalise: personalise) }
                }
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            }
            .fullScreenCover(isPresented: $showsOnboarding) {
                OnboardingView(preferences: preferences) { profile in
                    // the answers take effect now, not at the next launch
                    model.speaksLive = profile.speaksLive
                    if let first = profile.favouriteExercises.first {
                        model.selectedExercise = first
                    }
                    showsOnboarding = false
                }
            }
            .fullScreenCover(isPresented: $showsFinnDemo) {
                FinnDemoView {
                    showsFinnDemo = false
                    openWorkoutSetup()
                }
            }
            // badges follow the saved history: checked at launch and after every saved set. Only the set
            // just saved is celebrated; at launch (`lastSavedSetID` nil) the history's badges are recorded quietly
            .onChange(of: model.history, initial: true) { _, history in
                badges.update(history: history, celebrating: model.lastSavedSetID)
            }
            .task {
                liveActivity.attach(to: model, demoInput: usesSyntheticInput)
                #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-finn-ui-live-activity-sample") {
                        liveActivity.showSample()
                    }
                    if
                        usesSyntheticInput,
                        ProcessInfo.processInfo.arguments.contains("-finn-watch-auto-demo"),
                        !didRunWatchAutoDemo {
                        didRunWatchAutoDemo = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(3))
                            await model.startPreview()
                            await model.beginSet(countdown: 0)
                            try? await Task.sleep(for: .seconds(18))
                            await model.endSet()
                        }
                    }
                #endif
                guard connectsAccessories else {
                    return
                }
                accessories.start(model: model, demoInput: usesSyntheticInput)
            }
            // the home screen widget opens the camera on its exercise (`finn://start-set`)
            .onOpenURL { url in
                if !routesURLsFromParent {
                    handleLaunchURL(url)
                }
            }
            .onChange(of: launchURL, initial: true) { _, url in
                guard let url else {
                    return
                }
                launchURL = nil
                handleLaunchURL(url)
            }
    }

    private var appearancePresentation: some View {
        // A native modal isolates the workout accessibility tree while preserving tab state.
        setup
            .fullScreenCover(isPresented: Binding(
                get: { model.stage != .ready },
                set: { _ in }
            )) {
                NavigationStack {
                    VStack(spacing: 0) {
                        #if DEBUG
                            if showsDemoIndicator && !isCaptureStage && !isErrorStage {
                                demoIndicator
                            }
                        #endif
                        sessionContent
                    }
                    .navigationDestination(item: $sessionRoute) { destinationPage($0) }
                }
                .background(HomeStyle.background)
                .preferredColorScheme(.dark)
                .interactiveDismissDisabled()
                .onAppear { UIApplication.shared.isIdleTimerDisabled = Self.keepsScreenOn(model.stage) }
            }
        #if DEBUG
            .onAppear {
                let arguments = ProcessInfo.processInfo.arguments
                guard
                    route == nil, let index = arguments.firstIndex(of: "-finn-open"),
                    arguments.indices.contains(index + 1) else {
                    return
                }
                switch arguments[index + 1] {
                case "coach":
                    selectedTab = .coach
                case "progress":
                    selectedTab = .progress
                case "workout":
                    selectedTab = .workout
                case "history":
                    route = .history
                case "options":
                    route = .options
                case "privacy":
                    route = .privacy
                case "awards":
                    route = .awards
                case "health":
                    model.showsPersonalisationOffer = true
                case "camera-primer":
                    openWorkoutSetup()
                    Task { @MainActor in
                        // Present after the destination tab has mounted its sheet host.
                        try? await Task.sleep(for: .milliseconds(300))
                        showsCameraPrimer = true
                    }
                default:
                    break
                }
            }
        #endif
            .tint(HomeStyle.accent)
            .preferredColorScheme(.dark)
    }

    /// carries out what Siri asked ("Start a squat set in Finn", "Show my history in Finn") once the
    /// model can take it; otherwise the request waits for the next stage change
    private func applySiriRequest() {
        guard
            let request = SiriLaunchRequests.shared.pending,
            SiriLaunchRequests.canApply(request, at: model.stage) else {
            return
        }
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

    /// whether the session about to be deleted has a workout in Apple Health, which stays there
    private var deleteCandidateLeavesHealthWorkout: Bool {
        guard let id = deleteCandidate else {
            return false
        }
        return model.leavesHealthWorkout(forSession: id)
    }

    #if DEBUG
        private var demoIndicator: some View {
            Text("DEMO INPUT")
                .font(.system(size: demoLabelSize, weight: .bold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black, in: Capsule())
                .overlay(Capsule().strokeBorder(.yellow, lineWidth: 1).accessibilityHidden(true))
                .accessibilityIdentifier("debug.demoInput")

                .frame(maxWidth: .infinity)
                .background(HomeStyle.background)
        }
    #endif

    @ViewBuilder private var sessionContent: some View {
        switch model.stage {
        case .ready:
            EmptyView()
        case .openingCamera:
            ProgressView("Opening camera")
        case .framing,
             .countdown,
             .capturing,
             .analyzing:
            capture
        case .result:
            result
        case .error(let issue):
            failure(issue)
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    NavigationStack {
                        tabContent(tab)
                            .accessibilityHidden(model.stage != .ready)
                        #if DEBUG
                            .safeAreaInset(edge: .top, spacing: 0) {
                                if showsDemoIndicator {
                                    demoIndicator
                                }
                            }
                        #endif
                            .navigationDestination(item: Binding(
                                get: { tabRoutes[tab] },
                                set: { tabRoutes[tab] = $0 }
                            )) { destinationPage($0) }
                            .toolbar {
                                // Home draws its own, having no navigation bar; Workout places it
                                // after its More menu
                                if tab != .home && tab != .workout {
                                    ToolbarItem(placement: .topBarTrailing) { accountButton }
                                }
                            }
                    }
                    .toolbar(
                        model.stage != .ready || (tab == .home && tabRoutes[tab] == nil) ? .hidden : .visible,
                        for: .navigationBar
                    )
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }
            if !keyboardVisible && model.stage == .ready {
                HomeTabBar(selection: $selectedTab)
            }
        }
        .background(Color(white: 0.035).ignoresSafeArea())
        .sheet(isPresented: $showsCameraPrimer, onDismiss: {
            guard startsAfterCameraPrimer else {
                return
            }
            startsAfterCameraPrimer = false
            Task { await model.startPreview() }
        }) {
            CameraPrimer(onContinue: {
                startsAfterCameraPrimer = true
                showsCameraPrimer = false
            }, onPrivacy: {
                showsCameraPrimer = false
                if route == .launchWorkout {
                    showsSetupPrivacy = true
                } else {
                    route = .privacy
                }
            })
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
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
            DashboardView(
                history: model.history,
                exercise: model.selectedExercise,
                badges: badges.earned,
                hasTriedFinn: $hasTriedFinn,
                coachMessage: $coachMessage,
                openNextWorkout: openNextWorkout,
                watchDemo: { showsFinnDemo = true }
            ) { destination in
                if destination == .posture {
                    openPostureProgress()
                } else {
                    route = destination
                }
            }
        case .workout:
            workoutHome
        case .progress:
            progressPage
        case .coach:
            CoachView(history: model.history)
        }
    }

    private var progressPage: some View {
        ProgressTabView(history: model.history, section: $progressSection, exercise: Binding(
            get: { progressExercise ?? model.selectedExercise },
            set: { progressExercise = $0 }
        ))
    }

    private func openWorkoutSetup() {
        selectedTab = .workout
        tabRoutes[.workout] = .launchWorkout
    }

    private func openNextWorkout() {
        tabRoutes[.workout] = nil
        blursPreviousWorkouts = true
        selectedTab = .workout
    }

    private func openPostureProgress() {
        progressSection = .posture
        progressExercise = model.selectedExercise
        tabRoutes[.progress] = nil
        selectedTab = .progress
    }

    private var workoutHome: some View {
        WorkoutTabView(
            message: coachMessage,
            history: model.history,
            blursPreviousWorkouts: $blursPreviousWorkouts,
            savedToFitness: { model.fitnessRecord(forSession: $0.id) != nil },
            openSession: { route = .session($0.id) },
            launch: { route = .launchWorkout }
        )
        // the blur belongs to the visit Home's card started: gone once the person leaves the tab
        .onChange(of: selectedTab) { _, tab in
            if tab != .workout {
                blursPreviousWorkouts = false
            }
        }
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
            // its own glass, at the far right like on the other tabs
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) { accountButton }
        }
    }

    private var accountButton: some View {
        Button { route = .account } label: {
            Label("Account settings", systemImage: "person.fill")
        }
        .accessibilityIdentifier("home.account")
    }

    private func destinationPage(_ destination: HomeRoute) -> some View {
        destinationContent(destination)
        #if DEBUG
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsDemoIndicator {
                    demoIndicator
                }
            }
        #endif
    }

    @ViewBuilder private func destinationContent(_ destination: HomeRoute) -> some View {
        switch destination {
        case .history:
            historyPage
        case .options:
            optionsPage
        case .privacy:
            privacyPage
        case .coach:
            CoachView(history: model.history)
        case .lastWorkout:
            if let last = model.history.first {
                historyDetail(last)
            } else {
                ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.functional")
                    .navigationTitle("Last workout")
            }
        case .account:
            accountPage
        // pushed pages that follow the model: built in their own body (`LiveContent`)
        case .launchWorkout:
            LiveContent { workoutSetup }
        case .session(let id):
            LiveContent {
                if let session = model.history.first(where: { $0.id == id }) {
                    historyDetail(session)
                } else {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.functional"
                    )
                }
            }
        case .posture:
            LiveContent { progressPage }
        case .weights:
            historyList(title: "Best set", exercise: model.selectedExercise)
        case .awards:
            BadgesView(ledger: badges)
        // the subscription does not exist yet (1.1): the banner is hidden, and its route lands on
        // the account page rather than on a placeholder
        case .plus:
            accountPage
        }
    }

    /// Plays the first-run experience again from its very start, as on a first launch: the welcome
    /// screens, then Home with Try Finn, then the one-time Health offer after a set. Every first-run
    /// step resets here, so a new onboarding step adds its reset here too. Saved sets, answers and
    /// settings are kept.
    private func replayOnboarding() {
        preferences.onboardingCompleted = false
        preferences.personalisationOffered = false
        hasTriedFinn = false // TEMPORARY with `FinnFirstTryTrigger.swift`.
        tabRoutes = [:]
        selectedTab = .home
        showsOnboarding = true
    }

    private var accountPage: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image("FinnMark")
                        .resizable().scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finn").font(.title2.weight(.semibold))
                        Text("No account required").font(.subheadline)
                            .foregroundStyle(AppPageStyle.secondaryText)
                    }
                }
                .padding(.vertical, 8)
            }
            Section {
                NavigationLink { optionsPage } label: {
                    Label {
                        WrappingText(text: String(localized: "Options"))
                    } icon: {
                        Image(systemName: "slider.horizontal.3").accessibilityHidden(true)
                    }
                    .accessibilityLabel("Options")
                }
                NavigationLink { historyPage } label: {
                    Label {
                        WrappingText(text: String(localized: "History"))
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
                    }
                    .accessibilityLabel("History")
                }
                NavigationLink { privacyPage } label: {
                    Label {
                        WrappingText(text: String(localized: "Privacy"))
                    } icon: {
                        Image(systemName: "lock").accessibilityHidden(true)
                    }
                    .accessibilityLabel("Privacy")
                }
                Button(action: replayOnboarding) {
                    Label {
                        WrappingText(text: String(localized: "Replay the welcome"))
                    } icon: {
                        Image(systemName: "arrow.counterclockwise").accessibilityHidden(true)
                    }
                }
                .accessibilityIdentifier("account.replayOnboarding")
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
    }

    private var reduceMotion: Bool {
        #if DEBUG
            systemReduceMotion || ProcessInfo.processInfo.arguments.contains("-finn-ui-reduce-motion")
        #else
            systemReduceMotion
        #endif
    }

    private var workoutSetup: some View {
        workoutSetupScroll
            .overlay(alignment: .bottomTrailing) {
                Button { workoutPlanDraft = WorkoutPlanner.make(history: model.history) } label: {
                    Label("New workout", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 16)
                .accessibilityIdentifier("workout.new")
                .accessibilityHint("Composes a workout from your saved sets")
            }
            .sheet(item: $workoutPlanDraft) { WorkoutPlanView(plan: $0) }
    }

    private var workoutSetupScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // after Done: whether the session reached Apple Fitness
                if let save = model.fitnessSave {
                    HomeCard { fitnessStatus(save) }
                }
                // framing that went on with no set (or nobody in view) closed the camera by itself
                if let note = model.framingClosedNote {
                    HomeCard {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("setup.framingClosed")
                }
                // cancel, or the app going to the background during a set, comes back here without Done
                if let open = model.unfinishedSession {
                    HomeCard { unfinishedSessionLine(open) }
                }
                NextWorkoutsSection { workoutPlanDraft = $0 }
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
                // personalise with Health: a line adapted to the person, with the data it rests on
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                // said where the decision is made: before the camera opens
                Button { showsSetupPrivacy = true } label: {
                    Label("Camera privacy", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows what Finn keeps and what it never records")
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
            .background(AppPageStyle.background)
        }
        .background(AppPageStyle.background.ignoresSafeArea())
        .navigationTitle("Launch workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsSetupPrivacy) { privacyPage }
    }

    /// the latest saved session, with what Finn noticed in it, opening History
    private func lastSessionCard(_ session: WorkoutSessionSummary) -> some View {
        let reps = session.sets.reduce(0) { $0 + $1.analysis.reps.count }
        var names: [String] = []
        for set in session.sets where !names.contains(set.exercise.definition.copy.name) {
            names.append(set.exercise.definition.copy.name)
        }
        let sets = String(localized: "\(session.sets.count) sets")
        let when: String = {
            let time = session.startedAt.formatted(date: .omitted, time: .shortened)
            if
                Calendar.current
                    .isDateInToday(session.startedAt) {
                return String(localized: "Today, \(time)")
            }
            if
                Calendar.current
                    .isDateInYesterday(session.startedAt) {
                return String(localized: "Yesterday, \(time)")
            }
            return session.startedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }()
        // the latest observation the person kept, word for word
        let note = session.sets.last(where: { $0.cue != nil && $0.cueResponse != .notRelevant })?.cue?
            .observation
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

    /// one short line about the latest save to Apple Health, with Try again when it can help
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

    /// the session still open on the first screen, with a way to end it as Done does
    private func unfinishedSessionLine(_ session: WorkoutSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.sets.count == 1 ? "Session in progress · 1 measured set"
                : "Session in progress · \(session.sets.count) measured sets")
                .font(.subheadline)
            if model.offersFitness && model.savesToFitness {
                Text("Finish it to save it to Apple Fitness.")
                    .font(.footnote)
                    .foregroundStyle(FinnStyle.supportingText)
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
        case .saving:
            "arrow.triangle.2.circlepath"
        case .saved:
            "checkmark.circle"
        case .failed:
            "exclamationmark.circle"
        case .needsPermission:
            "hand.raised"
        case .unavailable:
            "heart.slash"
        }
    }

    /// under the Apple Fitness switch: why it is off for demo input, or what Health allows
    private var fitnessOptionNote: String? {
        guard model.offersFitness
        else {
            return String(localized: "Demo and recorded input are never saved to Apple Health.")
        }
        guard model.savesToFitness else {
            return nil
        }
        switch model.fitnessAccess {
        case .denied:
            return String(
                localized: "Health doesn’t let Finn save workouts. \(FitnessSaveStatus.needsPermission.text)."
            )
        case .unavailable:
            return FitnessSaveStatus.unavailable.text + "."
        case .authorized,
             .notDetermined:
            return nil
        }
    }

    /// in a saved session: saved to Fitness, or a way to save it when the option is on
    @ViewBuilder private func fitnessHistoryLine(_ session: WorkoutSessionSummary) -> some View {
        if let record = model.fitnessRecord(forSession: session.id) {
            Label(
                "Saved to Fitness on \(record.savedAt.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "checkmark.circle"
            )
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
                    // saving the session still open on the first screen finishes it
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
        case .openingCamera,
             .framing,
             .countdown,
             .capturing,
             .analyzing:
            true
        case .ready,
             .result,
             .error:
            false
        }
    }

    /// a personalised line and, under it, the Health data it rests on
    private func healthNote(_ note: HealthNote) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.text)
                .font(.subheadline)
            Text(note.basis)
                .font(.footnote)
                .foregroundStyle(FinnStyle.supportingText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// what connected headphones or a paired Apple Watch add to the chosen exercise, one line each
    @ViewBuilder private var accessoryNotes: some View {
        let lines = AccessoryGuide.setupLines(
            for: model.selectedExercise,
            status: accessories.status,
            speaksLive: model.speaksLive
        )
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.accessory) { line in
                    Label(line.text, systemImage: line.accessory == .appleWatch ? "applewatch" : "headphones")
                }
            }
            .font(.footnote)
            .foregroundStyle(FinnStyle.supportingText)
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("setup.accessories")
        }
    }

    private var selectedCopy: ExerciseCopy {
        model.selectedExercise.definition.copy
    }

    private var captureCopy: ExerciseCopy {
        model.captureExercise.definition.copy
    }

    private var privacyPage: some View {
        Form {
            Section {
                privacyFact(
                    "video.slash",
                    "No video is saved",
                    "Frames are analyzed on this iPhone, then dropped."
                )
                privacyFact(
                    "icloud.slash",
                    "No account required",
                    "Finn has no server. Set summaries are saved on this iPhone."
                )
                privacyFact(
                    "trash",
                    "Yours to delete",
                    "Remove one session or everything in History."
                )
            }

            DisclosureGroup {
                Text("Video is processed on this iPhone and never saved.")
                Text(
                    "Finn uses the camera to measure a supported exercise from the side. Camera frames and pose points stay on this iPhone."
                )
                Text("One camera view cannot assess your whole technique or prevent injury.")
            } label: {
                WrappingText(text: String(localized: "Camera"))
            }
            .accessibilityIdentifier("privacy.camera")
            DisclosureGroup {
                Text(
                    "Measured set summaries are saved on this iPhone so you can review previous sets. They include which measured patterns each set showed, so Finn can point out your most frequent one."
                )
                Text("Saved summaries may be included in your device backup.")
                Text("Delete saved sessions in History.")
            } label: {
                WrappingText(text: String(localized: "Saved results"))
            }
            DisclosureGroup {
                Text(
                    "If you turn on Save workouts to Apple Fitness, Finn writes each finished session to Health as a workout, with your permission: its time, sets, measured reps, and exercise names."
                )
                Text(
                    "Finn reads Health only if you turn on Personalize with Health: heart rate, resting heart rate, heart rate variability, VO2 max, workouts, active energy, steps, sleep, age, weight and height, to adapt its advice to you. It never writes calories or heart rate, and nothing leaves this iPhone through Finn."
                )
                Text(
                    "Health keeps these workouts under your Health settings. Deleting history in Finn doesn’t remove them; delete them in the Health app."
                )
            } label: {
                WrappingText(text: String(localized: "Apple Health"))
            }
            DisclosureGroup {
                Text(
                    "Finn says the countdown, each rep, and short live observations, and you can tap to hear an observation, through your iPhone or headphones. Turn spoken reps off in Options. Finn does not record sound or use the microphone."
                )
            } label: {
                WrappingText(text: String(localized: "Optional audio"))
            }
            if WatchBridge.isWatchAppBundled {
                DisclosureGroup {
                    Text(
                        "When Finn is open on your paired Apple Watch, this iPhone sends it the exercise name, the set’s progress, the rep count, live observations, and the result line. Video and pose points stay on this iPhone. The watch does not measure your movement."
                    )
                } label: {
                    WrappingText(text: String(localized: "Apple Watch"))
                }
            }
            if model.recognitionMethod != .unavailable {
                DisclosureGroup {
                    Text(
                        "Unless you turn it off in Options, Finn reads pose points after a set to recognise the exercise from your joint angles. Pose points and video stay on this iPhone."
                    )
                } label: {
                    WrappingText(text: String(localized: "Optional exercise recognition"))
                }
            }
            DisclosureGroup {
                Text(
                    "Coach uses your question and saved set summaries. When available, Apple Intelligence processes them on this iPhone. Camera frames and raw pose points are never included."
                )
            } label: {
                WrappingText(text: String(localized: "Coach"))
            }
            .accessibilityIdentifier("privacy.coach")
            DisclosureGroup {
                Text(
                    "On supported iPhones, Apple's on-device model can explain a measured comparison. The camera video is never given to the model."
                )
            } label: {
                WrappingText(text: String(localized: "Optional explanation"))
            }
            Link(destination: URL(string: "https://james8464.github.io/finn/privacy.html")!) {
                WrappingText(
                    text: String(localized: "Full privacy policy"),
                    colour: UIColor(AppPageStyle.tint)
                )
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .formStyle(.grouped)
        .tint(AppPageStyle.tint)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// one plain fact at the top of Privacy
    private func privacyFact(
        _ symbol: String,
        _ title: String.LocalizationValue,
        _ detail: String.LocalizationValue
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(AppPageStyle.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                WrappingText(text: String(localized: title), style: .headline)
                WrappingText(
                    text: String(localized: detail),
                    style: .subheadline,
                    colour: .label.withAlphaComponent(0.72)
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var optionsPage: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { model.handsFree }, set: { model.handsFree = $0 }
                )) {
                    WrappingText(text: String(localized: "Start and stop sets for me"))
                }
                .accessibilityLabel("Start and stop sets for me")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("options.handsFree")
                Toggle(isOn: Binding(
                    get: { model.speaksLive }, set: { model.speaksLive = $0 }
                )) {
                    WrappingText(text: String(localized: "Say reps aloud"))
                }
                .accessibilityLabel("Say reps aloud")
                .accessibilityIdentifier("options.speaksLive")
            } header: {
                Text("Hands-free")
            } footer: {
                Text("Hold position to start. Walk back or stop moving to finish.")
            }

            Section {
                Picker("Haptics", selection: Binding(
                    get: { model.hapticFeedback },
                    set: { style in
                        model.hapticFeedback = style
                        if style != .off {
                            workoutFeedback.play(.rep, haptics: style, sound: .off)
                        }
                    }
                )) {
                    ForEach(HapticFeedbackStyle.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("options.hapticFeedback")
                Picker("Sound effects", selection: Binding(
                    get: { model.soundFeedback },
                    set: { style in
                        model.soundFeedback = style
                        if style != .off {
                            workoutFeedback.play(.setStarted, haptics: .off, sound: style)
                        }
                    }
                )) {
                    ForEach(SoundFeedbackStyle.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("options.soundFeedback")
            } header: {
                Text("Workout feedback")
            } footer: {
                Text(
                    "Your iPhone taps at the start and end of a set; Apple Watch taps each rep. Optional tones mark the set. Sounds respect Silent Mode and play alongside your music."
                )
            }

            Section {
                if model.recognitionMethod != .unavailable {
                    Toggle(isOn: Binding(
                        get: { model.recognisesExercise }, set: { model.recognisesExercise = $0 }
                    )) {
                        WrappingText(text: String(localized: "Recognize the exercise automatically"))
                    }
                    .accessibilityLabel("Recognize the exercise automatically")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("options.recogniseExercise")
                }
                if model.hasExerciseClassifier {
                    Toggle(isOn: Binding(
                        get: { model.usesTrainedModel }, set: { model.usesTrainedModel = $0 }
                    )) {
                        WrappingText(text: String(localized: "Use the trained model instead (experimental)"))
                    }
                    .accessibilityLabel("Use the trained model instead (experimental)")
                    .accessibilityIdentifier("options.useTrainedModel")
                }
            } header: {
                Text("Exercise recognition")
            } footer: {
                switch model.recognitionMethod {
                case .keypointModel,
                     .angleModel:
                    Text("Experimental on-device estimate. Uses your selection when uncertain.")
                case .angleRules:
                    Text("Estimates from joint angles; uses your selection when uncertain.")
                case .unavailable:
                    Text("Exercise recognition unavailable. Uses your selection.")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.checksCameraAngle }, set: { model.checksCameraAngle = $0 }
                )) {
                    WrappingText(text: String(localized: "Check the camera angle in 3D"))
                }
                .accessibilityLabel("Check the camera angle in 3D")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("options.checkCameraAngle")
            } header: {
                Text("Camera angle")
            } footer: {
                Text("Posture feedback requires a side view. Turn this off if the angle estimate is wrong.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.savesToFitness },
                    set: { isOn in
                        model.savesToFitness = isOn
                        if isOn {
                            Task { await model.requestFitnessAccess() }
                        }
                    }
                )) {
                    WrappingText(text: String(localized: "Save workouts to Apple Fitness"))
                }
                .accessibilityLabel("Save workouts to Apple Fitness")
                .disabled(!model.offersFitness)
                .accessibilityIdentifier("options.savesToFitness")
                if let note = fitnessOptionNote {
                    WrappingText(text: note, style: .footnote, colour: UIColor.label.withAlphaComponent(0.72))
                        .accessibilityIdentifier("options.fitnessNote")
                }
            } header: {
                Text("Apple Fitness")
            } footer: {
                Text(
                    "Saves finished sessions with duration and reps, without calorie or heart-rate estimates."
                )
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.personalisesWithHealth },
                    set: { isOn in Task { await model.setPersonalisesWithHealth(isOn) } }
                )) {
                    WrappingText(text: String(localized: "Use my Health data"))
                }
                .accessibilityLabel("Use my Health data")
                .disabled(!model.offersHealthPersonalisation)
                .accessibilityIdentifier("options.personalisesWithHealth")
                if !model.offersHealthPersonalisation {
                    WrappingText(
                        text: String(localized: "Demo and recorded input never read Health."),
                        style: .footnote,
                        colour: UIColor.label.withAlphaComponent(0.72)
                    )
                }
                DisclosureGroup("Health data") {
                    ForEach(HealthReadType.allCases, id: \.self) { type in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title).font(.subheadline.weight(.semibold))
                            Text(type.use).font(.footnote).foregroundStyle(AppPageStyle.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                WrappingText(
                    text: String(localized: "Personalize with Health"),
                    style: .footnote,
                    weight: .semibold,
                    colour: .secondaryLabel
                )
                .accessibilityAddTraits(.isHeader)
            } footer: {
                Text("Tailors rest and recovery advice. Data stays on this iPhone.")
            }

            Section {
                LabeledContent("Language") {
                    Text(Locale(identifier: SpokenLanguage.appLanguage)
                        .localizedString(forIdentifier: SpokenLanguage.appLanguage) ?? SpokenLanguage
                        .appLanguage)
                }
                Button("Choose app language") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .accessibilityIdentifier("options.language")
            } footer: {
                Text(
                    "Choose English (UK), English (US), French or Spanish in iPhone Settings. Finn uses your region for dates and numbers."
                )
            }

            Section {
                Button("Replay the welcome", action: replayOnboarding)
                    .accessibilityIdentifier("options.replayOnboarding")
            } header: {
                Text("Welcome")
            } footer: {
                Text(
                    "The first-launch screens: your goal, your exercises, your level, the voice, and where to put your iPhone. Your choices set exercise order and help Coach select relevant saved sets."
                )
            }
            #if DEBUG
                Section { CoachDeveloperSection() }
            #endif
        }
        .font(.body)
        .formStyle(.grouped)
        .tint(AppPageStyle.tint)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var recognitionNote: some View {
        let chosen = model.captureExercise.definition.copy.name
        switch model.recognition {
        case .notAttempted:
            EmptyView()
        case .recognized(let kind, _):
            let name = kind.definition.copy.name
            if kind != model.captureExercise {
                Text("Using \(name) instead of \(chosen). Your next sets use \(name).")
                    .font(.subheadline)
                    .accessibilityIdentifier("result.recognition")
            }
        case .uncertain:
            // not sure: the person's own choice was used, as they expect. Nothing to add.
            EmptyView()
        }
    }

    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraFeedView(model: model)
                .ignoresSafeArea()
            LinearGradient(
                colors: [.clear, .black.opacity(0.76)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            VStack(spacing: 16) {
                #if DEBUG
                    if showsDemoIndicator || (isVideoFileInput && !isPresentationCapture) {
                        Text(isDemo ? "DEMO INPUT" : "VIDEO FILE INPUT")
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(6)
                            .background(.yellow, in: Capsule())
                    }
                #endif
                if model.stage == .capturing {
                    // during the set, everything to read sits at the top, under the status bar: the
                    // count in the corner and the advice banner across. The person fills the middle
                    // of the picture, and on 15 October the banner and the count, drawn there, hid the
                    // upper body and the skeleton of a push-up filmed from the floor
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
                            :
                            "3D view: \(Int(model.previewDeviations.sorted()[model.previewDeviations.count / 2].rounded()))° from profile")
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
                        .fixedSize(horizontal: false, vertical: true)
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
                        Label("Stop set", systemImage: "stop.fill").foregroundStyle(.black)
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

    /// while framing hands-free: what to do, and how long until the set starts by itself
    private var handsFreeHint: some View {
        let holding = model.handsFreeProgress > 0
        // not `livePose`, which is new on every frame and made this whole view redraw with it
        let seen = model.athleteInView
        return VStack(spacing: 8) {
            Text(holding ? "Hold still. The set starts by itself."
                : seen ? "Finn starts the set once it sees you clearly and you hold still."
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

    /// the latest live advice, such as "Sit lower", in large dark type on white so it reads from two or
    /// three metres away. It always takes the same place, at the top of the screen under the count
    /// row, and the slot stays empty until there is something to say, so nothing moves
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

    /// the reps counted so far, readable from where the person stands, in the top corner of the
    /// picture where it covers no one. With a rep target (Try Finn), the count shows it: "4/8"
    private var liveCount: some View {
        VStack(spacing: 0) {
            Group {
                if let target = model.repTarget {
                    Text("\(model.liveRepCount)/\(target)")
                } else {
                    Text("\(model.liveRepCount)")
                }
            }
            .font(.system(size: liveCountSize, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            // Counts must stay legible while changing; a fading digit loses contrast.
            // the exercise being measured, such as "push-ups", so a wrong choice shows before the reps
            // are done (13 October: push-ups filmed while Squat was chosen counted nothing)
            Text(captureCopy.name.lowercased() + (model.liveRepCount == 1 ? "" : "s"))
                .font(.headline)
        }
        // a dark backing keeps the white count readable over a bright camera image, like the other
        // labels drawn over the feed (the full accessibility audit checks this contrast)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps counted")
        .accessibilityValue(model.repTarget.map { Text("\(model.liveRepCount) of \($0)") }
                            ?? Text("\(model.liveRepCount)"))
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
                        // théophile: say which joint is unclear instead of guessing
                        Text("\(joint.localisedName) not clear: step back or add light")
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
        // hands-free, the person reads it from their spot a few steps away
        .font(model.handsFree ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.68), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var result: some View {
        // Give the persistent action its own space so it cannot obscure measured results.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if case .measured = model.result {
                        // the navigation title already confirms the completed review
                    } else {
                        Text(resultTitle)
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                    }
                    if model.endedEarly {
                        Text("The camera stopped during the set. Finn reviewed the part it captured.")
                            .font(.footnote)
                            .foregroundStyle(FinnStyle.supportingText)
                            .accessibilityIdentifier("result.endedEarly")
                    }
                    if model.endedAtLimit {
                        Text("Finn ends a set after 2 minutes. It reviewed the reps before that.")
                            .font(.footnote)
                            .foregroundStyle(FinnStyle.supportingText)
                            .accessibilityIdentifier("result.endedAtLimit")
                    }
                    if model.endedHandsFree {
                        Text("Finn ended the set when you walked away or stopped moving.")
                            .font(.footnote)
                            .foregroundStyle(FinnStyle.supportingText)
                            .accessibilityIdentifier("result.endedHandsFree")
                    }
                    if let result = model.result {
                        switch result {
                        case .measured(let analysis, let cue):
                            VStack(alignment: .leading, spacing: 10) {
                                Text(model.resultExercise.definition.copy.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppPageStyle.tint)
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(analysis.reps.count)")
                                        .font(.largeTitle.bold()).monospacedDigit()
                                    Text("reps").font(.headline).foregroundStyle(FinnStyle.supportingText)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityAddTraits(.isStaticText)
                                .accessibilityLabel("\(analysis.reps.count) measured reps")

                            }
                            .modifier(AppSurface())
                            if analysis.reps.count >= 2 {
                                depthChart(
                                    analysis.reps,
                                    exercise: model.resultExercise,
                                    highlighted: cue?.repNumbers ?? []
                                )
                            }
                            if let pattern = model.repeatedPattern {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Repeated observation")
                                        .font(.subheadline.weight(.semibold))
                                    Text(pattern.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(FinnStyle.supportingText)
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
                            VStack(alignment: .leading, spacing: 14) {
                                if let cue {
                                    if model.cueDismissed {
                                        Text("Observation marked not relevant.")
                                            .font(.body)
                                            .foregroundStyle(FinnStyle.supportingText)
                                    } else {
                                        WrappingText(text: cue.observation, style: .title3, weight: .semibold)
                                        WrappingText(
                                            text: String(
                                                localized: "Observed in \(FormChecks.list(cue.repNumbers))."
                                            ),
                                            style: .subheadline,
                                            colour: .label.withAlphaComponent(0.72)
                                        )
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
                                                Label(
                                                    observationSpeaker
                                                        .isSpeaking ? "Stop speaking" :
                                                        "Listen to observation",
                                                    systemImage: observationSpeaker
                                                        .isSpeaking ? "stop.fill" : "speaker.wave.2"
                                                )
                                                .frame(minHeight: 44, alignment: .leading)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    if analysis.reps.count < 4 {
                                        WrappingText(
                                            text: String(localized: "Observations require 4 measured reps."),
                                            style: .title3
                                        )
                                    } else {
                                        WrappingText(
                                            text: String(localized: "No observation"),
                                            style: .title3
                                        )
                                    }
                                    WrappingText(
                                        text: String(
                                            localized: "This is a camera measurement, not a full technique assessment."
                                        ),
                                        style: .footnote,
                                        colour: UIColor.label.withAlphaComponent(0.72)
                                    )
                                }
                            }
                            .modifier(AppSurface())
                            NavigationLink { CoachView(history: model.history) } label: {
                                Label("Ask the coach", systemImage: "bubble.left.and.text.bubble.right")
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                            .accessibilityIdentifier("result.askCoach")
                            recognitionNote
                            if model.movementNote != nil || !model.formNotes.isEmpty {
                                DisclosureGroup {
                                    if let note = model.movementNote {
                                        Text(note).accessibilityIdentifier("result.movementNote")
                                    }
                                    ForEach(model.formNotes, id: \.self) { note in
                                        Text(note).accessibilityIdentifier("result.formNote")
                                    }
                                } label: {
                                    Label("Measurement limits", systemImage: "info.circle")
                                }
                                .font(.subheadline)
                                .tint(AppPageStyle.secondaryText)
                                .accessibilityIdentifier("result.measurementLimits")
                                .modifier(AppSurface())
                            }
                            ForEach(model.resultHealthNotes, id: \.text) { note in
                                healthNote(note).accessibilityIdentifier("result.healthNote")
                            }
                            if let comparison = model.comparison {
                                comparisonView(comparison)
                                    .modifier(AppSurface())
                            } else if let gap = model.comparisonGap {
                                Text(comparisonGapText(gap))
                                    .foregroundStyle(FinnStyle.supportingText)
                            }
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps, exercise: model.resultExercise)
                            }
                            ShareLink(item: SetShareSummary.text(
                                for: analysis,
                                cue: cue,
                                cueDismissed: model.cueDismissed,
                                comparison: model.comparison,
                                exercise: model.resultExercise
                            )) {
                                Label("Share summary", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                            .font(.subheadline)
                            .accessibilityIdentifier("result.shareSummary")
                            .accessibilityHint("Shares the measured summary without video")
                            // last on the result, as in #10: higher up, the cards sat behind the bottom
                            // button on a short result and the contrast audit measured them through it
                            if let extremes = model.repExtremes {
                                Divider().padding(.vertical, 12)
                                NavigationLink {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 24) {
                                            depthChart(
                                                analysis.reps,
                                                exercise: model.resultExercise,
                                                highlighted: cue?.repNumbers ?? []
                                            )
                                            repExtremesView(extremes)
                                        }
                                        .padding(20)
                                    }
                                    .background(AppPageStyle.background)
                                    .navigationTitle("Movement")
                                    .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    Label("Compare reps", systemImage: "figure.strengthtraining.traditional")
                                        .frame(minHeight: 44)
                                }
                                .accessibilityIdentifier("result.compareReps")
                                repExtremesView(extremes)
                            }
                        case .insufficientView(let reason):
                            recognitionNote
                            Text(reason)
                            if let hint = model.retakeHint {
                                Text(hint)
                                    .foregroundStyle(FinnStyle.supportingText)
                            }
                            // changing an option here keeps the session, so the next set still compares
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
                                .foregroundStyle(FinnStyle.supportingText)
                                .accessibilityIdentifier("validation.stopToResult")
                        }
                        if isValidationMode {
                            Text("Validation 3D view · \(viewVerdictReadout(model.lastViewVerdict))")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(FinnStyle.supportingText)
                                .accessibilityIdentifier("validation.viewCheck")
                        }
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .clipped()

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
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPageStyle.action)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppPageStyle.background)

        }
        .background(AppPageStyle.background)
        .navigationTitle(resultNavigationTitle)
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
            if case .measured(_, let cue) = model.result, cue != nil, !model.cueDismissed {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Not relevant") {
                            observationSpeaker.stop()
                            model.dismissCue()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Observation options")
                    .accessibilityIdentifier("result.observationOptions")
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        observationSpeaker.stop()
                        Task { await model.finishSession() }
                    } label: {
                        WrappingText(text: String(localized: "Done"), weight: .semibold, alignment: .center)
                            .fixedSize()
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                    .accessibilityIdentifier("result.done")
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

    /// the set's deepest and shallowest reps side by side, drawn from their pose points
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
            Text("Pose at the bottom of each rep. No video saved.")
                .font(.footnote)
                .foregroundStyle(FinnStyle.supportingText)
        }
        .accessibilityIdentifier("result.repExtremes")
    }

    private func repSnapshotView(_ snapshot: RepSnapshot, title: String) -> some View {
        let definition = model.resultExercise.definition
        let cropped = SkeletonGeometry.cropped(snapshot.frame)
        let angleText = cropped.flatMap {
            SkeletonGeometry(
                frame: $0,
                exercise: definition,
                size: CGSize(width: 100, height: 100),
                mirrored: false
            ).angle?.text
        }
        return VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                guard let cropped else {
                    return
                }
                let geometry = SkeletonGeometry(
                    frame: cropped,
                    exercise: definition,
                    size: size,
                    mirrored: false
                )
                SkeletonPainter.draw(
                    geometry,
                    in: &context,
                    size: size,
                    clear: .primary,
                    labelText: Color(uiColor: .systemBackground),
                    lineWidth: 2.5
                )
            }
            .frame(height: 180)
            .accessibilityHidden(true)
            // only the text is the accessibility element, so its contrast is judged against the card,
            // not against the lines of the drawing above it
            VStack(alignment: .leading, spacing: 6) {
                Text("\(title) · rep \(snapshot.number)")
                    .font(.subheadline.weight(.semibold))
                Text(definition.formattedDepth(snapshot.range))
                    .font(.footnote)
                    .foregroundStyle(FinnStyle.supportingText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(title) rep, rep \(snapshot.number), \(definition.formattedDepth(snapshot.range))"
                    + (angleText.map { ", \($0)" } ?? "")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonGapText(_ gap: ComparisonGap) -> LocalizedStringKey {
        switch gap {
        case .differentExercise:
            "Finn compares sets of the same exercise. Do another set of this exercise to compare."
        case .tooFewReps:
            "Finn compares sets with at least \(SetComparison.minimumReps) measured reps each."
        case .differentSide:
            "Your earlier sets were filmed from your other side, so Finn can’t compare them."
        case .incompatibleSets:
            "These sets used different camera views, so Finn can’t compare them reliably."
        case .partlyVisible:
            "Finn saw this set only partly, so it doesn’t compare it with your earlier sets."
        }
    }

    private var resultNavigationTitle: LocalizedStringKey {
        if case .measured = model.result {
            return "Set reviewed"
        }
        return "Set summary"
    }

    private var resultTitle: LocalizedStringKey {
        switch model.result {
        case .measured:
            "Set reviewed"
        case .insufficientView:
            "Couldn’t assess this set"
        case .failed:
            "Couldn’t review this set"
        case .interrupted:
            "Set interrupted"
        case nil:
            "Set result"
        }
    }

    private var retakeLabel: LocalizedStringKey {
        if case .insufficientView = model.result {
            return "Retake set"
        }
        if case .measured(_, let cue) = model.result, cue != nil {
            return "Try this next set"
        }
        return "Try another set"
    }

    private func nextAction(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappingText(
                text: String(localized: "Next set"),
                style: .subheadline,
                weight: .semibold,
                colour: .label.withAlphaComponent(0.72)
            )
            WrappingText(text: text)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func depthChart(_ reps: [RepMetric], exercise: ExerciseKind, highlighted: [Int]) -> some View {
        let definition = exercise.definition
        let noun = definition.copy.rangeNoun
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(noun.prefix(1).uppercased() + noun.dropFirst()) per rep")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Chart(reps, id: \.number) { rep in
                BarMark(
                    x: .value("Rep", String(rep.number)),
                    y: .value("Range", min(1.2, rep.relativeRange / definition.rangeDisplayScale)),
                    width: .ratio(0.6)
                )
                .foregroundStyle(highlighted.contains(rep.number) ? AppPageStyle
                    .tint : Color(uiColor: .secondaryLabel))
                .cornerRadius(5)
                .accessibilityLabel("Rep \(rep.number)")
                .accessibilityValue(definition.accessibleRange(rep.relativeRange))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: reps.enumerated().filter { index, _ in
                    index % max(1, reps.count / 6) == 0 || index == reps.count - 1
                }.map { String($0.element.number) }) { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(AppPageStyle.secondaryText)
                }
            }
            .chartXScale(domain: reps.map { String($0.number) })
            .chartYScale(domain: 0 ... 1.2)
            .frame(height: 120)
            .accessibilityLabel("\(noun) per rep")
        }
        .modifier(AppSurface())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result.depthChart")

    }

    @ViewBuilder private func statsSections(_ sessions: [WorkoutSessionSummary]) -> some View {
        let summary = StatsSummary(sessions: sessions)
        let trend = summary.weekTrend
        Section {
            MeasuredFigure(value: "\(summary.totalReps)", label: "Total reps", sources: sessions) {
                HStack(spacing: 16) {
                    Label(
                        summary.streakDays == 1 ? String(localized: "1 day in a row")
                            : String(localized: "\(summary.streakDays) days in a row"),
                        systemImage: "flame"
                    )
                    Label(
                        sessions.count == 1 ? String(localized: "1 session")
                            : String(localized: "\(sessions.count) sessions"),
                        systemImage: "calendar"
                    )
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                RegularityCalendar(days: summary.dailyReps)
                    .padding(.top, 4)
            }
        }
        if trend.change != nil {
            Section {
                let change = trend.change.map { Int(($0 * 100).rounded()) }
                MeasuredFigure(
                    value: change.map { ($0 >= 0 ? "+" : "") + "\($0) %" } ?? "\(trend.thisWeek)",
                    label: change == nil ? "Reps this week" : "vs. last week",
                    sources: sessions.filter { Calendar.current.isDate(
                        $0.startedAt,
                        equalTo: .now,
                        toGranularity: .weekOfYear
                    ) }
                ) {
                    Text(change == nil ? String(localized: "No previous week")
                        : String(localized: "\(trend.thisWeek) reps this week, \(trend.lastWeek) last week."))
                        .font(.footnote)
                        .foregroundStyle(FinnStyle.supportingText)
                }
            }
        }
        let quality = summary.qualityPerSession
        if quality.count >= 2 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reps without observations")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    QualityChart(points: quality)
                }
                .padding(.vertical, 4)
            }
        }
        ForEach(summary.exercises, id: \.kind) { facts in
            Section { ExerciseStatsCard(facts: facts) }
        }
        Section {
            NavigationLink { BadgesView(ledger: badges) } label: {
                Label("Awards", systemImage: "rosette")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("stats.awards")
        }
    }

    private var historyPage: some View {
        historyList(title: "History", exercise: nil)
    }

    /// the saved sessions, every one or only those with a set of `exercise`
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
                        .foregroundStyle(FinnStyle.supportingText)
                    Button("Recover history") { model.recoverHistory() }
                }
            } else if model.historyIssue == .unavailable {
                Section {
                    Text(model
                        .hasPendingDeletion ? "Deletion couldn’t finish" : "History temporarily unavailable")
                        .font(.headline)
                    Text(model.hasPendingDeletion
                        ? "Tap Try again to finish removing the local data."
                        : "The saved file could not be accessed. Unlock this iPhone, then try again.")
                        .foregroundStyle(FinnStyle.supportingText)
                    Button("Try again") { model.retryHistory() }
                }
            } else if sessions.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundStyle(FinnStyle.supportingText)
                            .accessibilityHidden(true)
                        Text(exerciseName.map { "No \($0) sets saved yet." } ?? "No saved sessions yet.")
                            .font(.headline)

                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                if exercise == nil {
                    statsSections(sessions)
                }
                Section {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            NavigationLink { historyDetail(session) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    WrappingText(text: session.startedAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    ))
                                    WrappingText(
                                        text: model.fitnessRecord(forSession: session.id) == nil
                                            ? String(localized: "\(session.sets.count) measured sets")
                                            :
                                            String(
                                                localized: "\(session.sets.count) measured sets · Saved to Fitness"
                                            ),
                                        style: .subheadline,
                                        colour: .label.withAlphaComponent(0.72)
                                    )
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
                            .foregroundStyle(destructiveLabelColour)
                            .accessibilityLabel(
                                "Delete session from \(session.startedAt.formatted(date: .abbreviated, time: .omitted))"
                            )
                        }
                    }
                } header: {
                    WrappingText(
                        text: String(localized: "Saved sessions"),
                        style: .headline,
                        weight: .semibold,
                        colour: .label.withAlphaComponent(0.72)
                    )
                    .accessibilityAddTraits(.isHeader)
                }
            }
            Section {
                Button(role: .destructive) { deleteAllRequested = true } label: {
                    Text("Delete all local data")
                        .foregroundStyle(destructiveLabelColour)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyDetail(_ session: WorkoutSessionSummary) -> some View {
        Form {
            Section {
                Text(session.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline).foregroundStyle(AppPageStyle.secondaryText)
            }
            ForEach(session.sets.indices, id: \.self) { index in
                let set = session.sets[index]
                Section {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                    layout {
                        Text(set.exercise.definition.copy.name).font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(set.analysis.reps.count) measured reps")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(AppPageStyle.tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let cue = set.cue {
                        if set.cueResponse == .notRelevant {
                            Text("Observation marked not relevant.")
                                .foregroundStyle(AppPageStyle.secondaryText)
                        } else {
                            Text(cue.observation).font(.body.weight(.semibold))
                            nextAction(cue.nextAction)
                        }
                    } else {
                        Text("No observation").foregroundStyle(AppPageStyle.secondaryText)
                    }
                    DisclosureGroup("Rep details") {
                        Text("Measured reps").font(.headline)
                        repList(set.analysis.reps, exercise: set.exercise)
                    }
                } header: {
                    Text("Set \(index + 1)")
                }
            }
            Section {
                fitnessHistoryLine(session)
                DisclosureGroup("About measurements") {
                    Text("These are camera measurements from one view, not a full technique assessment.")
                        .font(.footnote).foregroundStyle(AppPageStyle.secondaryText)
                }
            }
        }
        .tint(AppPageStyle.tint)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with your previous set").font(.headline)
            WrappingText(
                text: model.comparisonRecap?.text
                    ?? SetShareSummary.statement(
                        for: comparison.rangeDirection,
                        exercise: comparison.exercise
                    ),
                style: .title3,
                weight: .semibold
            )
            if model.comparisonRecap?.source == .appleIntelligence {
                Text("Worded with Apple Intelligence")
                    .font(.caption).foregroundStyle(FinnStyle.supportingText)
            }
            DisclosureGroup("Set measurements") {
                VStack(alignment: .leading, spacing: 12) {
                    comparisonMetric(
                        "Set 1",
                        range: comparison.firstMedianRange,
                        duration: comparison.firstMedianDuration,
                        exercise: comparison.exercise
                    )
                    comparisonMetric(
                        "Set 2",
                        range: comparison.secondMedianRange,
                        duration: comparison.secondMedianDuration,
                        exercise: comparison.exercise
                    )
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

    private func comparisonMetric(
        _ title: LocalizedStringKey,
        range: Double,
        duration: Double,
        exercise: ExerciseKind
    ) -> some View {
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
                .accessibilityLabel(
                    "Rep \(rep.number), \(rep.duration.formatted(.number.precision(.fractionLength(1)))) seconds, \(definition.copy.rangeAccessibilityName) \(definition.accessibleRange(rep.relativeRange))"
                )
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
                    .foregroundStyle(FinnStyle.supportingText)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
                Text(issue.title).font(.largeTitle.bold())
                Text(issue.message)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(FinnStyle.supportingText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if issue.offersSettings {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .foregroundStyle(FinnStyle.primaryButtonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomeStyle.filledAccent)
                    Button {
                        Task { await model.cancel()
                            await model.startPreview() }
                    } label: {
                        WrappingText(text: String(localized: "Try again"), alignment: .center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        Task { await model.cancel()
                            await model.startPreview() }
                    } label: {
                        Text("Try again")
                            .foregroundStyle(FinnStyle.primaryButtonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomeStyle.filledAccent)
                }
                // the first screen, with History, Options, Privacy and an open session's Finish
                // session, stays reachable while the camera cannot be used
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
