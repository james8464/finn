import SwiftUI
import UIKit

private enum PlumbStyle {
    static let ink = Color.primary
    static let supportingText = Color.primary.opacity(0.72)
    static let primaryButtonText = Color(uiColor: .systemBackground)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: WorkoutSessionModel
    @State private var observationSpeaker = ObservationSpeaker()
    /// Headphones and a paired Apple Watch; idle unless `connectsAccessories`.
    @State private var accessories = AccessoryMonitor()
    /// True for the live camera, and for demo input only behind `-plumb-watch-demo`.
    private let connectsAccessories: Bool
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    /// The live rep count, large enough to read from a few steps away, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var liveCountSize: CGFloat = 88
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
                    connectsAccessories: Bool = false) {
        _model = State(initialValue: WorkoutSessionModel(source: source, store: store,
                                                         narrator: narrator,
                                                         exerciseClassifier: exerciseClassifier,
                                                         preferences: preferences,
                                                         announcer: announcer,
                                                         fitness: fitness))
        self.connectsAccessories = connectsAccessories
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
        NavigationStack {
            Group {
                switch model.stage {
                case .ready: setup
                case .openingCamera: ProgressView("Opening camera")
                case .framing, .countdown, .capturing, .analyzing: capture
                case .result: result
                case .error(let issue): failure(issue)
                }
            }
            .navigationTitle("Plumb")
            .navigationBarTitleDisplayMode(.large)
        }
        .overlay(alignment: .top) {
            #if DEBUG
            if isDemo && !isCaptureStage && !isErrorStage {
                Text("DEMO INPUT")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(6)
                    .background(.yellow, in: Capsule())
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            #endif
        }
        .tint(PlumbStyle.ink)
        #if DEBUG
        .preferredColorScheme(usesTestDarkAppearance ? .dark : nil)
        #endif
        // The phone stands a few steps away and nobody touches it: keep the screen on while the
        // camera is open, or Auto-Lock interrupts framing and throws the set away.
        .onChange(of: model.stage, initial: true) { _, stage in
            UIApplication.shared.isIdleTimerDisabled = Self.keepsScreenOn(stage)
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task {
            guard connectsAccessories else { return }
            accessories.start(model: model, demoInput: usesSyntheticInput)
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
            Text("Its measured set summaries will be removed from this iPhone.")
        }
        .alert("Delete all local data?", isPresented: $deleteAllRequested) {
            Button("Delete all data", role: .destructive) { model.deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved sessions and any recovered history backups from this iPhone.")
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review your movement after each set.")
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.bottom, 28)
                // After Done: whether the session reached Apple Fitness.
                if let save = model.fitnessSave {
                    fitnessStatus(save)
                        .padding(.bottom, 20)
                }
                // Cancel, or the app going to the background during a set, comes back here without Done.
                if let open = model.unfinishedSession {
                    unfinishedSessionLine(open)
                        .padding(.bottom, 20)
                }
                exercisePicker
                if model.usesExerciseRecognition {
                    Text("After the set, Plumb also checks which exercise you did. If it isn’t sure, it keeps your choice.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .padding(.top, 8)
                }
                if let focus = model.focus {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR FOCUS")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PlumbStyle.supportingText)
                        Text(focus.focus)
                            .font(.body.weight(.semibold))
                        Text(focus.summary)
                            .font(.subheadline)
                            .foregroundStyle(PlumbStyle.supportingText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 28)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("setup.focus")
                }
                Text("SET UP")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.top, 40)
                    .padding(.bottom, 12)
                setupStep(selectedCopy.placementTitle, detail: selectedCopy.placementDetail,
                          symbol: "iphone.gen3")
                Divider().padding(.leading, 44)
                setupStep(selectedCopy.stanceTitle, detail: selectedCopy.stanceDetail,
                          symbol: "figure.stand")
                accessoryNotes

                Text("Analysis stays on this iPhone. No video is saved.")
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.top, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.startPreview() }
            } label: {
                Text("Set up camera")
                    .foregroundStyle(PlumbStyle.primaryButtonText)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { historyPage } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { optionsPage } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { privacyPage } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
            }
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
        guard model.offersFitness else { return "Demo and recorded input are never saved to Apple Health." }
        guard model.savesToFitness else { return nil }
        switch model.fitnessAccess {
        case .denied: return "Health doesn’t let Plumb save workouts. \(FitnessSaveStatus.needsPermission.text)."
        case .unavailable: return "\(FitnessSaveStatus.unavailable.text)."
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

    private var exercisePicker: some View {
        Menu {
            Picker("Exercise", selection: Binding(
                get: { model.selectedExercise },
                set: { model.selectedExercise = $0 }
            )) {
                ForEach(ExerciseKind.allCases, id: \.self) { kind in
                    Text(kind.definition.copy.name).tag(kind)
                }
            }
        } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text("Exercise")
                    .font(.body)
                    .foregroundStyle(.primary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: 8) {
                    Text(selectedCopy.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("setup.exercise")
        .accessibilityLabel("Exercise: \(selectedCopy.name)")
        .accessibilityHint("Choose the exercise to check")
    }

    private func setupStep(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body)
                Text(detail).font(.body).foregroundStyle(PlumbStyle.supportingText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var privacyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
                    Text("Plumb reads nothing from Health and never adds calories or heart rate. Nothing leaves this iPhone through Plumb.")
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

    private var optionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercise recognition").font(.headline).accessibilityAddTraits(.isHeader)
                    if model.recognitionMethod != .unavailable {
                        Toggle("Recognize the exercise automatically", isOn: Binding(
                            get: { model.recognizesExercise },
                            set: { model.recognizesExercise = $0 }
                        ))
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
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("options.useTrainedModel")
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera angle").font(.headline).accessibilityAddTraits(.isHeader)
                    Toggle("Check the camera angle in 3D", isOn: Binding(
                        get: { model.checksCameraAngle },
                        set: { model.checksCameraAngle = $0 }
                    ))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.checkCameraAngle")
                    Text("On supported iPhones, Plumb estimates your body’s 3D position to tell a side view from a front or angled one. When you are a little turned, it suggests turning and still counts your reps. It only refuses a set when you clearly face the camera, or face away, for several seconds. If it asks you to turn while your side already faces the camera, switch this off.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hands-free").font(.headline).accessibilityAddTraits(.isHeader)
                    Toggle("Start and stop sets for me", isOn: Binding(
                        get: { model.handsFree },
                        set: { model.handsFree = $0 }
                    ))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.handsFree")
                    Text("Once you hold still in position for a moment, Plumb counts down and starts the set. It ends the set when you walk back to your iPhone, or when you stop moving after your reps. Start set and Stop set still work.")
                    Toggle("Say reps aloud", isOn: Binding(
                        get: { model.speaksLive },
                        set: { model.speaksLive = $0 }
                    ))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("options.speaksLive")
                    Text("Plumb says the countdown, each counted rep, and when a rep is clearly faster or shorter than your first reps of the set. It uses your AirPods or other headphones when they are connected, otherwise the iPhone speaker.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Fitness").font(.headline).accessibilityAddTraits(.isHeader)
                    Toggle("Save workouts to Apple Fitness", isOn: Binding(
                        get: { model.savesToFitness },
                        set: { isOn in
                            model.savesToFitness = isOn
                            // Permission in context: Health asks when the person turns this on.
                            if isOn { Task { await model.requestFitnessAccess() } }
                        }
                    ))
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
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollIndicators(.hidden)
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
                 : "Recognized as \(name) on this iPhone, so Plumb used it instead of \(chosen).")
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
                status
                if accessories.status.isConnected(.appleWatch) {
                    Label("Apple Watch connected", systemImage: "applewatch")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.68), in: Capsule())
                        .accessibilityIdentifier("capture.watch")
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
                        Text("Start set").foregroundStyle(.black)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white)
                } else if model.stage == .capturing {
                    liveCount
                    if let caption = model.liveCaption {
                        Text(caption)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.68), in: Capsule())
                            .accessibilityIdentifier("capture.liveCaption")
                    }
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
                        Text("Stop set").foregroundStyle(.black)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white)
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

    /// While framing hands-free: what to do, and how long until the set starts by itself.
    private var handsFreeHint: some View {
        let holding = model.handsFreeProgress > 0
        let seen = !(model.livePose?.joints.isEmpty ?? true)
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture.handsFree")
    }

    /// The reps counted so far, readable from where the person stands.
    private var liveCount: some View {
        VStack(spacing: 0) {
            Text("\(model.liveRepCount)")
                .font(.system(size: liveCountSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.liveRepCount)
            Text(model.liveRepCount == 1 ? "rep" : "reps")
                .font(.headline)
        }
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
                        Text("\(joint.rawValue.capitalized) not clear: step back or add light")
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.68), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button("Done") {
                        observationSpeaker.stop()
                        Task { await model.finishSession() }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                Text(resultTitle)
                    .font(.largeTitle.bold())
                if model.endedEarly {
                    Text("The camera stopped during the set. Plumb reviewed the part it captured.")
                        .font(.footnote)
                        .foregroundStyle(PlumbStyle.supportingText)
                        .accessibilityIdentifier("result.endedEarly")
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
                                Text("Observed in reps \(cue.repNumbers.map(String.init).joined(separator: " and ")).")
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
                        if let extremes = model.repExtremes {
                            repExtremesView(extremes)
                            Divider().padding(.vertical, 12)
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
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                observationSpeaker.stop()
                Task { await model.startPreview() }
            } label: {
                Text(retakeLabel)
                    .foregroundStyle(PlumbStyle.primaryButtonText)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
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
            HStack(alignment: .top, spacing: 12) {
                repSnapshotView(extremes.deepest, title: "Deepest")
                repSnapshotView(extremes.shallowest, title: "Shallowest")
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
            Text("\(title) · rep \(snapshot.number)")
                .font(.subheadline.weight(.semibold))
            Text(definition.formattedDepth(snapshot.range))
                .font(.footnote)
                .foregroundStyle(PlumbStyle.supportingText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) rep, rep \(snapshot.number), \(definition.formattedDepth(snapshot.range))"
                            + (angleText.map { ", \($0)" } ?? ""))
    }

    private func comparisonGapText(_ gap: ComparisonGap) -> String {
        switch gap {
        case .differentExercise:
            "Plumb compares sets of the same exercise. Do another set of this exercise to compare."
        case .tooFewReps:
            "Plumb compares sets with at least \(SetComparison.minimumReps) measured reps each."
        case .differentSide:
            "Your earlier sets were filmed from your other side, so Plumb can’t compare them."
        case .incompatibleSets:
            "These sets used different camera views, so Plumb can’t compare them reliably."
        }
    }

    private var resultTitle: String {
        switch model.result {
        case .measured: "Set reviewed"
        case .insufficientView: "Couldn’t assess this set"
        case .failed: "Couldn’t review this set"
        case .interrupted: "Set interrupted"
        case nil: "Set result"
        }
    }

    private var retakeLabel: String {
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

    private var historyPage: some View {
        List {
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
            } else if model.history.isEmpty {
                Text("No saved sessions yet.")
                    .foregroundStyle(PlumbStyle.supportingText)
            } else {
                Section("Saved sessions") {
                    ForEach(model.history) { session in
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
        .navigationTitle("History")
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

    private func comparisonMetric(_ title: String, range: Double, duration: Double,
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
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
