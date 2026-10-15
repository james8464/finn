import Charts
import SwiftUI
import UIKit

private enum PlumbStyle {
    static let ink = Color.white
    static let supportingText = Color.white.opacity(0.6)
    static let primaryButtonText = Color.black
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
    /// The blurred room behind the first screen: the live camera, once the person has allowed it.
    @State private var ambientCamera = AmbientCamera()
    /// True for the live camera, and for demo input only behind `-plumb-watch-demo`.
    private let connectsAccessories: Bool
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    /// History, Coach, Awards, Options or Privacy, pushed from the first screen.
    @State private var route: HomeRoute?
    /// The four tabs: the set, the history, the coach, and the rest of the person's things.
    @State private var tab: AppTab = .workout
    /// The six exercises, large, behind the icon at the top left of the first screen.
    @State private var showsExercisePicker = false
    /// Coach, Options or History opened from the result, on top of its sheet.
    @State private var resultPage: ResultPage?
    @State private var resultDetent: PresentationDetent = .large
    /// What the camera does, shown once before iOS asks for it.
    @State private var showsCameraPrimer = false
    /// The first-launch screens (`Onboarding/`), also replayed from Options.
    @State private var showsOnboarding: Bool
    /// Badges earned from the saved history (`Badges/`).
    @State private var badges: BadgeLedger
    private let preferences: PlumbPreferences
    /// The live rep count, the one thing that moves during a set, readable from a few steps away.
    @ScaledMetric(relativeTo: .largeTitle) private var liveCountSize: CGFloat = 128
    /// Live advice during a set, in the bottom banner, readable from the same distance.
    @ScaledMetric(relativeTo: .largeTitle) private var liveCueSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var homeTitleSize: CGFloat = 50
    @ScaledMetric(relativeTo: .largeTitle) private var resultCountSize: CGFloat = 104
    @ScaledMetric(relativeTo: .largeTitle) private var startButtonSize: CGFloat = 132
    @ScaledMetric(relativeTo: .largeTitle) private var figureHeight: CGFloat = 230
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

    /// The first screen shows through the result sheet; the set itself covers it.
    private var showsResultSheet: Binding<Bool> {
        Binding(get: { model.stage == .result },
                set: { shown in
                    // Swiping the sheet away goes back to the first screen; the session stays open.
                    guard !shown, model.stage == .result else { return }
                    observationSpeaker.stop()
                    Task { await model.cancel() }
                })
    }

    private var hidesTabBar: Bool {
        switch model.stage {
        case .ready, .result: false
        default: true
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(String(localized: "Workout"), systemImage: "figure.strengthtraining.functional", value: AppTab.workout) {
                workoutTab
            }
            Tab(String(localized: "Stats"), systemImage: "chart.xyaxis.line", value: AppTab.stats) {
                NavigationStack { statsPage }
            }
            Tab(String(localized: "Coach"), systemImage: "bubble.left.and.text.bubble.right", value: AppTab.coach) {
                NavigationStack { CoachView(history: model.history) }
            }
            Tab(String(localized: "Awards"), systemImage: "rosette", value: AppTab.awards) {
                NavigationStack { BadgesView(ledger: badges) }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: tab)
        .overlay(alignment: .top) {
            #if DEBUG
            if isDemo && !isCaptureStage && !isErrorStage {
                Text("DEMO INPUT")
                    .font(.caption.bold())
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary, in: Capsule())
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            #endif
        }
        .tint(.white)
        // Plumb is dark everywhere: three people preferred it to the light version (15 October).
        .preferredColorScheme(.dark)
        .sheet(isPresented: showsResultSheet) { result }
        .sheet(isPresented: $showsExercisePicker) {
            ExercisePickerSheet(order: preferences.exerciseOrder, selection: Binding(
                get: { model.selectedExercise },
                set: { kind in withAnimation(HomeStyle.spring) { model.selectedExercise = kind } }
            ))
        }
        .modifier(SessionLifecycle(view: self))
    }

    /// Every measured set since the install, as numbers and curves, with the sessions below.
    private var statsPage: some View {
        historyList(title: String(localized: "Stats"), exercise: nil)
    }

    /// The first tab: the first screen, the camera over it, the result sheet above it.
    private var workoutTab: some View {
        NavigationStack {
            ZStack {
                switch model.stage {
                case .ready, .result:
                    home
                case .openingCamera:
                    ZStack {
                        PlumbBackdrop()
                        ProgressView("Opening camera")
                    }
                case .framing, .countdown, .capturing, .analyzing:
                    capture
                case .error(let issue):
                    failure(issue)
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar { rootToolbar }
            .navigationDestination(item: $route) { destination in
                destinationPage(destination)
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            }
            // Full-screen camera during a set: the tab bar comes back with the result.
            .toolbar(hidesTabBar ? .hidden : .visible, for: .tabBar)
            #if DEBUG
            .onAppear {
                let arguments = ProcessInfo.processInfo.arguments
                guard route == nil, let index = arguments.firstIndex(of: "-plumb-open"),
                      arguments.indices.contains(index + 1) else { return }
                switch arguments[index + 1] {
                case "coach": tab = .coach
                case "options": route = .options
                case "awards": tab = .awards
                case "history": tab = .stats
                default: break
                }
            }
            #endif
        }
    }
}

/// The modifiers that outlive any one tab: screen, Siri, Health, the welcome, badges, accessories,
/// deep links, the scene, and the two delete dialogs.
private struct SessionLifecycle: ViewModifier {
    let view: ContentView
    func body(content: Content) -> some View { view.lifecycle(content) }
}

extension ContentView {
    fileprivate func lifecycle(_ content: some View) -> some View {
        content
        // The phone stands a few steps away and nobody touches it: keep the screen on while the
        // camera is open, or Auto-Lock interrupts framing and throws the set away.
        .onChange(of: model.stage, initial: true) { _, stage in
            UIApplication.shared.isIdleTimerDisabled = Self.keepsScreenOn(stage)
            // The blurred room behind the first screen and the result; never with demo input.
            if !usesSyntheticInput && (stage == .ready || stage == .result) { ambientCamera.start() }
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
            get: { model.showsPersonalizationOffer && model.stage != .result },
            set: { if !$0 { model.showsPersonalizationOffer = false } }
        )) {
            personalizationOffer
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(preferences: preferences) { profile in
                // The answers take effect now, not at the next launch.
                model.speaksLive = profile.speaksLive
                if let first = profile.favoriteExercises.first { model.selectedExercise = first }
                showsOnboarding = false
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
            startSet()
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
}

extension ContentView {

    /// Asked once after the first measured set. Presented from the result sheet when it is up, or
    /// from the first screen: two sheets on the same view would block each other (15 October, the
    /// share sheet never came up and every button of the result looked disabled).
    private var personalizationOffer: some View {
        PersonalizationOfferView { personalize in
            Task { await model.answerPersonalizationOffer(personalize: personalize) }
        }
        .presentationDetents([.medium, .large])
    }

    /// The native bar: the one icon on the first screen, Cancel or Stop over the camera.
    @ToolbarContentBuilder private var rootToolbar: some ToolbarContent {
        switch model.stage {
        case .ready, .result:
            ToolbarItem(placement: .topBarTrailing) {
                // Settings only: Options and Privacy. The coach and the awards have their tabs.
                Menu {
                    Button { route = .options } label: { Label("Options", systemImage: "slider.horizontal.3") }
                    Button { route = .privacy } label: { Label("Privacy", systemImage: "lock") }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .accessibilityHint("Options and privacy")
                .accessibilityIdentifier("home.more")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { showsExercisePicker = true } label: {
                    Label("Exercises", systemImage: "dumbbell.fill")
                }
                .accessibilityHint("Choose the exercise")
                .accessibilityIdentifier("home.exercises")
            }

        case .framing, .countdown, .openingCamera:
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { Task { await model.cancel() } }
            }
        case .capturing:
            ToolbarItem(placement: .topBarLeading) {
                Button("Stop set") {
                    let tappedAt = ContinuousClock.now
                    Task { await model.endSet(tappedAt: tappedAt) }
                }
                .accessibilityIdentifier("capture.stop")
            }
        case .analyzing, .error:
            ToolbarItem(placement: .topBarLeading) { EmptyView() }
        }
    }

    /// Opens the camera for the chosen exercise: the primer first if iOS has not asked yet, and the
    /// ambient preview is let go of before the measuring source takes the camera.
    private func startSet() {
        if !usesSyntheticInput && CameraPermission.notAskedYet {
            showsCameraPrimer = true
            return
        }
        Task {
            await ambientCamera.stop()
            await model.startPreview()
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
            tab = .workout
            observationSpeaker.stop()
            model.selectedExercise = exercise
            startSet()
        case .showHistory:
            tab = .stats
        }
    }

    /// Whether the session about to be deleted has a workout in Apple Health, which stays there.
    private var deleteCandidateLeavesHealthWorkout: Bool {
        guard let id = deleteCandidate else { return false }
        return model.leavesHealthWorkout(forSession: id)
    }

    // MARK: - First screen

    /// One title, one button. The exercise changes by touching the title or swiping sideways;
    /// everything else waits behind the icon in the corner.
    private var home: some View {
        ZStack {
            if usesSyntheticInput {
                PlumbBackdrop()
            } else {
                AmbientCameraBackdrop(camera: ambientCamera)
            }
            VStack(spacing: 0) {
                exerciseTitle
                    .padding(.top, 64)
                homeNotes
                Spacer(minLength: 16)
                // One slow, well-done rep of the chosen exercise, seen as the camera will see it.
                ExerciseFigureView(kind: model.selectedExercise, lineColor: .white)
                    .frame(maxWidth: 360)
                    .frame(height: figureHeight)
                    .id(model.selectedExercise)
                    .transition(.blurReplace)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("home.figure")
                Spacer(minLength: 16)
                startButton
                    .padding(.bottom, 4)
                if let progressLine {
                    Button { tab = .stats } label: {
                        Text(progressLine)
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens your history")
                    .accessibilityIdentifier("home.progress")
                }
                // Said where the decision is made: before the camera opens.
                Button { route = .privacy } label: {
                    Text("Analyzed on this iPhone. No video is saved.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows what Plumb keeps and what it never records")
                .accessibilityIdentifier("home.privacy")
                .padding(.horizontal, 24)
                // The glass bars float over the content: keep the actions clear of the tab bar.
                .padding(.bottom, 84)
            }
        }
        .gesture(exerciseSwipe)
        .sensoryFeedback(.selection, trigger: model.selectedExercise)
        .sensoryFeedback(.impact(weight: .medium), trigger: model.stage == .openingCamera)
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
            .presentationBackground(HomeStyle.background)
        }
    }

    /// "Ready for squats?": touching it opens the native exercise menu.
    private var exerciseTitle: some View {
        Menu {
            Picker("Exercise", selection: Binding(
                get: { model.selectedExercise },
                set: { kind in withAnimation(HomeStyle.spring) { model.selectedExercise = kind } }
            )) {
                ForEach(preferences.exerciseOrder, id: \.self) { kind in
                    Text(kind.definition.copy.name).tag(kind)
                }
            }
        } label: {
            Text(model.selectedExercise.readyTitle)
                .font(.system(size: homeTitleSize, weight: .bold, design: .default))
                .tracking(-homeTitleSize * 0.03)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : HomeStyle.spring, value: model.selectedExercise)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Exercise: \(model.selectedExercise.definition.copy.name)")
        .accessibilityHint("Opens the list of exercises")
        .accessibilityIdentifier("home.exercise")
    }

    /// A sideways swipe anywhere on the first screen moves to the next or previous exercise.
    private var exerciseSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) else { return }
                let order = preferences.exerciseOrder
                guard let index = order.firstIndex(of: model.selectedExercise) else { return }
                let next = dx < 0 ? min(index + 1, order.count - 1) : max(index - 1, 0)
                guard next != index else { return }
                withAnimation(HomeStyle.spring) { model.selectedExercise = order[next] }
            }
    }

    private var startButton: some View {
        Button { startSet() } label: {
            PrimaryActionLabel(title: "Start a set")
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 24)
        .accessibilityHint("Opens the camera for \(selectedCopy.name.lowercased())")
        .accessibilityIdentifier("home.start")
    }

    /// Lines that appear only when there is something to say: a save to Fitness, a session still
    /// open, a Health note, the focus from earlier sets.
    @ViewBuilder private var homeNotes: some View {
        let hasNotes = model.fitnessSave != nil || model.framingClosedNote != nil
            || model.unfinishedSession != nil || model.readinessNote != nil
        if hasNotes {
            VStack(spacing: 8) {
                if let save = model.fitnessSave {
                    homeNote { fitnessStatus(save) }
                }
                if let note = model.framingClosedNote {
                    homeNote {
                        Text(note)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("setup.framingClosed")
                }
                if let open = model.unfinishedSession {
                    homeNote { unfinishedSessionLine(open) }
                }
                if let note = model.readinessNote {
                    homeNote { healthNote(note) }
                        .accessibilityIdentifier("setup.healthReadiness")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    private func homeNote<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plumbGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// "3 sessions this week · best 27 push-ups": measured, never estimated.
    private var progressLine: String? {
        guard !model.history.isEmpty else { return nil }
        let calendar = Calendar.current
        let thisWeek = model.history.filter {
            calendar.isDate($0.startedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
        let kind = model.selectedExercise
        let best = model.history.flatMap(\.sets).filter { $0.exercise == kind }
            .map { $0.analysis.reps.count }.max()
        let sessions = String(localized: "\(thisWeek) sessions this week")
        guard let best else { return sessions }
        let record = best == 1 ? "1 \(kind.definition.copy.name.lowercased())" : "\(best) \(kind.pluralName)"
        return String(localized: "\(sessions) · best \(record)")
    }

    /// "Yesterday, 27 push-ups": the latest saved session in one line.
    private var lastSessionLine: String? {
        guard let session = model.history.first else { return nil }
        let reps = session.sets.reduce(0) { $0 + $1.analysis.reps.count }
        var kinds: [ExerciseKind] = []
        for set in session.sets where !kinds.contains(set.exercise) { kinds.append(set.exercise) }
        let what: String
        if kinds.count == 1, let kind = kinds.first {
            what = reps == 1 ? "1 \(kind.definition.copy.name.lowercased())" : "\(reps) \(kind.pluralName)"
        } else {
            what = String(localized: "\(reps) reps")
        }
        if Calendar.current.isDateInToday(session.startedAt) {
            return String(localized: "Today, \(what)")
        } else if Calendar.current.isDateInYesterday(session.startedAt) {
            return String(localized: "Yesterday, \(what)")
        }
        return "\(session.startedAt.formatted(.dateTime.day().month(.abbreviated))), \(what)"
    }

    @ViewBuilder private func destinationPage(_ destination: HomeRoute) -> some View {
        switch destination {
        case .history: historyPage
        case .options: optionsPage
        case .privacy: privacyPage
        case .coach: CoachView(history: model.history)
        case .awards: BadgesView(ledger: badges)
        }
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
        }
        .scrollIndicators(.hidden)
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
                        .frame(minHeight: 44)
                    .accessibilityIdentifier("options.handsFree")
                    Text("Once you hold still in position for a moment, Plumb counts down and starts the set. It ends the set when you walk back to your iPhone, or when you stop moving after your reps. Start set and Stop set still work.")
                    Toggle("Say reps aloud", isOn: Binding(
                        get: { model.speaksLive },
                        set: { model.speaksLive = $0 }
                    ))
                    .font(.body)
                    .foregroundStyle(Color.primary)
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

    // MARK: - The set

    /// The camera, clear and full screen. One thing moves: the count at the top. One thing speaks:
    /// the advice in the banner at the bottom. Nothing to touch while the set runs.
    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraFeedView(model: model)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                captureMarks
                if model.stage == .capturing {
                    liveCount
                } else if model.stage == .framing {
                    status
                }
                Spacer()
                captureBottom
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.liveRepCount)
        .sensoryFeedback(.warning, trigger: model.liveCaption) { _, new in new != nil }
        .toolbar {
            if model.stage == .framing {
                ToolbarItem(placement: .bottomBar) {
                    Button { Task { await model.beginSet() } } label: {
                        Text("Start set")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .accessibilityIdentifier("capture.start")
                }
            }
        }
        .overlay {
            if case .countdown(let count) = model.stage {
                Text("\(count)")
                    .font(.system(size: liveCountSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: liveCountSize * 1.4, minHeight: liveCountSize * 1.4)
                    .plumbGlass(in: Circle())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .snappy, value: count)
                    .accessibilityLabel("Starting in \(count)")
            }
        }
        // VoiceOver hears each piece of advice as it appears, like everyone else does.
        .onChange(of: model.liveCaption) { _, caption in
            if let caption { AccessibilityNotification.Announcement(caption).post() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The small marks that say what is connected; the way out lives in the bar above.
    @ViewBuilder private var captureMarks: some View {
        HStack(spacing: 8) {
            Spacer()
            #if DEBUG
            if isDemo || isVideoFileInput {
                Text(isDemo ? "DEMO INPUT" : "VIDEO FILE INPUT")
                    .font(.caption.bold())
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary, in: Capsule())
            }
            if isValidationMode && model.stage == .framing {
                Text(model.previewDeviations.isEmpty ? "3D view: no estimate"
                     : "3D view: \(Int(model.previewDeviations.sorted()[model.previewDeviations.count / 2].rounded()))° from profile")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .plumbGlass(in: Capsule())
                    .accessibilityIdentifier("validation.liveView")
            }
            #endif
            if accessories.status.isConnected(.appleWatch) {
                Image(systemName: "applewatch")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
                    .plumbGlass(in: Circle())
                    .accessibilityLabel("Apple Watch connected")
                    .accessibilityIdentifier("capture.watch")
            }
        }
    }

    /// Under the count: the framing guidance before the set, the advice during it.
    @ViewBuilder private var captureBottom: some View {
        switch model.stage {
        case .framing:
            // One line to read from the spot; the hands-free line only when it applies.
            VStack(spacing: 10) {
                Text(captureCopy.framingPrompt)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if model.handsFree {
                    handsFreeHint
                }
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .plumbGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .capturing:
            liveCue
        case .analyzing:
            ProgressView("Reviewing set")
                .foregroundStyle(Color.primary)
                .padding(20)
                .frame(maxWidth: .infinity)
                .plumbGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        default:
            EmptyView()
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
                .foregroundStyle(PlumbStyle.supportingText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: model.handsFreeProgress)
                .tint(Color.primary)
                .frame(maxWidth: 180)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture.handsFree")
    }

    /// The latest live advice, such as "Chest up.", in large type in the banner at the bottom, so it
    /// reads from two or three metres away without covering the body. The banner stays empty until
    /// there is something to say.
    private var liveCue: some View {
        Text(model.liveCaption ?? " ")
            .font(.system(size: liveCueSize, weight: .bold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, minHeight: liveCueSize * 2.2)
            .plumbGlass(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .opacity(model.liveCaption == nil ? 0 : 1)
            .animation(reduceMotion ? nil : .snappy, value: model.liveCaption)
            .accessibilityHidden(model.liveCaption == nil)
            .accessibilityIdentifier("capture.liveCaption")
    }

    /// The reps counted so far, the only thing that moves on the screen.
    private var liveCount: some View {
        VStack(spacing: 2) {
            VStack(spacing: -6) {
                Text("\(model.liveRepCount)")
                    .font(.system(size: liveCountSize, weight: .bold, design: .default))
                    .tracking(-liveCountSize * 0.04)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: model.liveRepCount)
                // The exercise being measured, so a wrong choice shows before the reps are done
                // (13 October: push-ups filmed while Squat was chosen counted nothing).
                Text(model.liveRepCount == 1 ? captureCopy.name.lowercased() : model.captureExercise.pluralName)
                    .font(.headline)
                    .foregroundStyle(PlumbStyle.supportingText)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 28)
            .padding(.top, 2)
            .padding(.bottom, 12)
            .plumbGlass(in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reps counted")
            .accessibilityValue("\(model.liveRepCount)")
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("capture.liveReps")
            if let startedAt = model.captureStartedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                    let seconds = max(0, Int(timeline.date.timeIntervalSince(startedAt)))
                    let time = String(format: "%02d:%02d", seconds / 60, seconds % 60)
                    Text(time)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .plumbGlass(in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(time)
                        .accessibilityIdentifier("capture.elapsed")
                }
            }
        }
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
        .foregroundStyle(Color.primary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .plumbGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - The result

    /// A sheet over the blurred room: the number, one observation, Next set. The measurements,
    /// the comparison and the sharing wait further down the same sheet.
    private enum ResultPage: String, Identifiable {
        case coach, options, history
        var id: String { rawValue }
    }

    private var result: some View {
        NavigationStack {
            resultContent
        }
        // Opens tall so nothing is cut at any text size; a pull down shows the room behind it.
        .presentationDetents([.fraction(0.62), .large], selection: $resultDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
        .sensoryFeedback(.success, trigger: model.stage == .result)
    }

    private var resultContent: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    resultHero
                    resultDetails
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
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { resultPage = .coach } label: {
                    Label("Ask Plumb", systemImage: "bubble.left.and.text.bubble.right")
                }
                .accessibilityHint("Opens the coach with this set's facts")
                .accessibilityIdentifier("result.coach")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Ends the session: the next set starts a new one, and Fitness gets this one.
                Button("Done") {
                    observationSpeaker.stop()
                    Task { await model.finishSession() }
                }
                .accessibilityHint("Ends this session")
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    observationSpeaker.stop()
                    startSet()
                } label: {
                    Text(retakeLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .accessibilityIdentifier("result.next")
            }
        }
        .onDisappear { observationSpeaker.stop() }
        .sheet(isPresented: Binding(
            get: { model.showsPersonalizationOffer },
            set: { if !$0 { model.showsPersonalizationOffer = false } }
        )) {
            personalizationOffer
        }
        .sheet(item: $resultPage) { page in
            NavigationStack {
                switch page {
                case .coach: CoachView(history: model.history)
                case .options: optionsPage
                case .history: historyPage
                }
            }
        }
    }

    private var isMeasuredResult: Bool {
        if case .measured = model.result { return true }
        return false
    }

    /// The number and one sentence, centered, large enough to read from the mat.
    @ViewBuilder private var resultHero: some View {
        VStack(spacing: 4) {
            Text(resultTitle)
                .font(isMeasuredResult ? .subheadline.weight(.semibold) : .title.bold())
                .foregroundStyle(isMeasuredResult ? PlumbStyle.supportingText : Color.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if case .measured(let analysis, let cue) = model.result {
                Text("\(analysis.reps.count)")
                    .font(.system(size: resultCountSize, weight: .bold, design: .default))
                    .tracking(-resultCountSize * 0.04)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.top, 4)
                Text(analysis.reps.count == 1 ? model.resultExercise.definition.copy.name.lowercased()
                     : model.resultExercise.pluralName)
                    .font(.system(size: resultCountSize * 0.4, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.top, -14)
                if let cue {
                    Text(model.cueDismissed ? String(localized: "Observation marked not relevant.") : cue.observation)
                        .font(.title3)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .accessibilityIdentifier("result.observation")
                }
            }
            if !badges.justEarned.isEmpty {
                BadgeUnlockCard(badges: badges.justEarned) {
                    Task { await model.cancel() }
                    tab = .awards
                }
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    /// Everything measured, below the hero: the notes, the comparison, the reps, the share.
    @ViewBuilder private var resultDetails: some View {
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
                Divider().padding(.vertical, 8)
                if analysis.reps.count >= 2 {
                    depthChart(analysis.reps, exercise: model.resultExercise, highlighted: cue?.repNumbers ?? [])
                }
                if let extremes = model.repExtremes {
                    repExtremesView(extremes)
                        .padding(.top, 8)
                }
                Button { resultPage = .coach } label: {
                    Label("Ask the coach", systemImage: "bubble.left.and.text.bubble.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityHint("Opens the coach with this set's facts")
                .accessibilityIdentifier("result.askCoach")
                Divider().padding(.vertical, 8)
                Text("\(analysis.reps.count) measured reps")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(PlumbStyle.supportingText)
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
                        Button("Review history") { resultPage = .history }
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                if let cue {
                    Divider().padding(.vertical, 12)
                    if !model.cueDismissed {
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
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("result.shareSummary")
                .accessibilityHint("Shares the measured summary without video")
            case .insufficientView(let reason):
                recognitionNote
                Text(reason)
                if let hint = model.retakeHint {
                    Text(hint)
                        .foregroundStyle(PlumbStyle.supportingText)
                }
                // Changing an option here keeps the session, so the next set still compares.
                Button("Options") { resultPage = .options }
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("result.options")
            case .failed(let reason):
                Text(reason)
            case .interrupted:
                Text("Camera capture stopped before the set was complete.")
            }
        }
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

    /// One bar per rep, its range in the exercise's own unit; the reps behind the observation are
    /// drawn in black, the others in grey. Measured values only.
    private func depthChart(_ reps: [RepMetric], exercise: ExerciseKind, highlighted: [Int]) -> some View {
        let definition = exercise.definition
        let noun = definition.copy.rangeNoun
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(noun.prefix(1).uppercased() + noun.dropFirst()) per rep")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Chart(reps, id: \.number) { rep in
                BarMark(x: .value("Rep", rep.number),
                        y: .value("Range", min(1.2, rep.relativeRange / definition.rangeDisplayScale)))
                    .foregroundStyle(highlighted.contains(rep.number) ? Color.primary : Color.primary.opacity(0.28))
                    .cornerRadius(5)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: reps.map(\.number)) { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartXScale(domain: 0.5...(Double(reps.count) + 0.5))
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noun) per rep")
            .accessibilityValue(reps.map { "rep \($0.number), \(definition.accessibleRange($0.relativeRange))" }
                .joined(separator: "; "))
        }
        .accessibilityIdentifier("result.depthChart")
    }

    /// Per exercise since the install: sessions, reps and the best set. Measured, nothing else.
    private func exerciseTotals(_ sessions: [WorkoutSessionSummary]) -> some View {
        let kinds = ExerciseKind.allCases.filter { kind in sessions.contains { $0.sets.contains { $0.exercise == kind } } }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Since you started")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(kinds, id: \.self) { kind in
                let withKind = sessions.filter { $0.sets.contains { $0.exercise == kind } }
                let sets = withKind.flatMap(\.sets).filter { $0.exercise == kind }
                let reps = sets.reduce(0) { $0 + $1.analysis.reps.count }
                let best = sets.map { $0.analysis.reps.count }.max() ?? 0
                HStack(alignment: .firstTextBaseline) {
                    Text(kind.definition.copy.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(withKind.count) sessions · \(reps) reps · best \(best)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(PlumbStyle.supportingText)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("stats.totals")
    }

    /// Sessions per week over the last eight weeks: regularity, as bars.
    private func weeklyChart(_ sessions: [WorkoutSessionSummary]) -> some View {
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let weeks: [Date] = (0..<8).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        let counts = weeks.map { start -> (Date, Int) in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return (start, sessions.filter { $0.startedAt >= start && $0.startedAt < end }.count)
        }
        let spoken: String = counts.map { week, count -> String in
            "\(week.formatted(date: .abbreviated, time: .omitted)): \(count)"
        }.joined(separator: "; ")
        return VStack(alignment: .leading, spacing: 8) {
            Text("Sessions per week")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Chart(counts, id: \.0) { week, count in
                BarMark(x: .value("Week", week, unit: .weekOfYear), y: .value("Sessions", count))
                    .foregroundStyle(week == thisWeek ? Color.white : Color.white.opacity(0.35))
                    .cornerRadius(4)
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sessions per week")
            .accessibilityValue(spoken)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("stats.weekly")
    }

    /// For each exercise measured in two or more sessions: the median range per session, as a line.
    @ViewBuilder private func rangeTrend(_ sessions: [WorkoutSessionSummary]) -> some View {
        let kinds = ExerciseKind.allCases.filter { kind in
            sessions.filter { $0.sets.contains { $0.exercise == kind } }.count >= 2
        }
        ForEach(kinds, id: \.self) { kind in
            let definition = kind.definition
            let points: [(Date, Double)] = sessions.compactMap { session in
                let ranges = session.sets.filter { $0.exercise == kind }
                    .flatMap { $0.analysis.reps.map(\.relativeRange) }.sorted()
                guard !ranges.isEmpty else { return nil }
                return (session.startedAt, ranges[ranges.count / 2])
            }.sorted { $0.0 < $1.0 }
            let spoken: String = points.map { day, range -> String in
                "\(day.formatted(date: .abbreviated, time: .omitted)): \(definition.accessibleRange(range))"
            }.joined(separator: "; ")
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(definition.copy.name): \(definition.copy.rangeNoun) per session")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Chart(Array(points.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("Date", point.0), y: .value("Range", point.1))
                            .foregroundStyle(.white)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", point.0), y: .value("Range", point.1))
                            .foregroundStyle(.white)
                    }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .frame(height: 120)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(definition.copy.name), \(definition.copy.rangeNoun) per session")
                    .accessibilityValue(spoken)
                    Text("Median of the measured reps of each session.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Reps per session for each exercise, above the saved sessions. Only with two or more sessions.
    @ViewBuilder private func historyChart(_ sessions: [WorkoutSessionSummary]) -> some View {
        let points: [(exercise: ExerciseKind, date: Date, reps: Int)] = sessions.flatMap { session in
            Dictionary(grouping: session.sets, by: \.exercise).map { kind, sets in
                (kind, session.startedAt, sets.reduce(0) { $0 + $1.analysis.reps.count })
            }
        }
        let kinds = Dictionary(grouping: points, by: \.exercise).filter { $0.value.count >= 2 }.keys
        let shown = points.filter { kinds.contains($0.exercise) }.sorted { $0.date < $1.date }
        let spoken: String = shown.map { point -> String in
            let day = point.date.formatted(date: .abbreviated, time: .omitted)
            return "\(point.exercise.chipName), \(day), \(point.reps) reps"
        }.joined(separator: "; ")
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reps per session")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Chart(Array(shown.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Reps", point.reps))
                        .foregroundStyle(by: .value("Exercise", point.exercise.chipName))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", point.date), y: .value("Reps", point.reps))
                        .foregroundStyle(by: .value("Exercise", point.exercise.chipName))
                }
                .chartForegroundStyleScale(range: [Color.white, Color.white.opacity(0.6),
                                                   Color.white.opacity(0.4), Color.white.opacity(0.28),
                                                   Color.white.opacity(0.2), Color.white.opacity(0.14)])
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Reps per session")
                .accessibilityValue(spoken)
            }
            .padding(.vertical, 6)
            .accessibilityIdentifier("history.chart")
        }
    }

    /// The set's deepest and shallowest reps side by side, drawn from their pose points.
    private func repExtremesView(_ extremes: RepExtremes) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deepest and shallowest rep")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 12) {
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
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 14))
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
        return "Next set"
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
    private func historyList(title: String, exercise: ExerciseKind?) -> some View {
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
                if exercise == nil {
                    Section { exerciseTotals(sessions) }
                }
                if sessions.count >= 2 {
                    Section { historyChart(sessions) }
                    if exercise == nil {
                        Section { weeklyChart(sessions) }
                        rangeTrend(sessions)
                    }
                }
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
        .plumbBackdrop()
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
        .navigationTitle("Session")
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
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    Button("Try again") {
                        Task { await model.cancel(); await ambientCamera.stop(); await model.startPreview() }
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        Task { await model.cancel(); await ambientCamera.stop(); await model.startPreview() }
                    } label: {
                        Text("Try again")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
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
        }
    }
}

