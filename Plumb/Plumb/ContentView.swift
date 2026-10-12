import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: WorkoutSessionModel
    @State private var observationSpeaker = ObservationSpeaker()
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    private var primaryButtonLabelColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .black : .white
        })
    }
    private var destructiveLabelColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 69 / 255, blue: 58 / 255, alpha: 1)
                : UIColor(red: 198 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1)
        })
    }
    #if DEBUG
    private var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") }
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
                    preferences: PlumbPreferences = .standard) {
        _model = State(initialValue: WorkoutSessionModel(source: source, store: store,
                                                         narrator: narrator,
                                                         exerciseClassifier: exerciseClassifier,
                                                         preferences: preferences))
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
            .navigationBarTitleDisplayMode(.inline)
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
        .tint(.accentColor)
        #if DEBUG
        .preferredColorScheme(usesTestDarkAppearance ? .dark : nil)
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { observationSpeaker.stop() }
            if phase == .background { Task { await model.backgrounded() } }
            if phase == .active && model.historyIssue == .unavailable {
                model.retryHistory()
            }
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
                if !dynamicTypeSize.isAccessibilitySize {
                    Image("PlumbMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                        .padding(.bottom, 28)
                }
                Text(selectedCopy.setupTitle)
                    .font(.largeTitle.bold())
                    .padding(.bottom, 12)
                Text(selectedCopy.setupSummary)
                    .font(.body)
                    .padding(.bottom, 24)
                exercisePicker
                    .padding(.bottom, model.usesExerciseRecognition ? 8 : 28)
                if model.usesExerciseRecognition {
                    Text("Plumb will try to recognize the exercise after the set. If it isn’t confident, it uses your choice.")
                        .font(.footnote)
                        .padding(.bottom, 28)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Label(selectedCopy.placement, systemImage: "iphone.gen3")
                    Label(selectedCopy.stance, systemImage: "figure.stand")
                }
                .font(.body)
                .padding(.bottom, 36)
                Text("On-device analysis. No video saved. One camera view only.")
                    .font(.footnote)
                    .padding(.bottom, 28)
                let links = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 24))
                links {
                    NavigationLink { historyPage } label: {
                        Text("History")
                            .frame(minWidth: 88, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    NavigationLink { privacyPage } label: {
                        Text("Privacy")
                            .frame(minWidth: 88, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    NavigationLink { optionsPage } label: {
                        Text("Options")
                            .frame(minWidth: 88, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            }
            #if DEBUG
            .padding(.top, isDemo && dynamicTypeSize.isAccessibilitySize ? 64 : 0)
            #endif
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.startPreview() }
            } label: {
                Text("Set up camera")
                    .foregroundStyle(primaryButtonLabelColor)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .toolbar(.hidden, for: .navigationBar)
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
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: 8) {
                    Text(selectedCopy.name)
                        .font(.headline)
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

    private var privacyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Video is processed on this iPhone and never saved.")
                    Text("Plumb uses the camera to measure a supported exercise from the side. Camera frames and pose points stay on this iPhone.")
                    Text("One camera view cannot assess your whole technique or prevent injury.")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved results").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Measured set summaries are saved on this iPhone so you can review previous sets.")
                    Text("Saved summaries may be included in your device backup.")
                    Text("Delete saved sessions in History.")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional audio").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Tap to hear an observation through your iPhone or headphones. Plumb does not record sound or use the microphone.")
                }
                if model.hasExerciseClassifier {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optional exercise recognition").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("When you turn it on in Options, an on-device model reads pose points after a set to recognize the exercise. Pose points and video stay on this iPhone.")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional explanation").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("On supported iPhones, Apple's on-device model can explain a measured comparison. The camera video is never given to the model.")
                }
                Link("Full privacy policy", destination: URL(string: "https://james8464.github.io/hackathon-project/privacy.html")!)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Privacy")
    }

    private var optionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercise recognition").font(.headline).accessibilityAddTraits(.isHeader)
                    if model.hasExerciseClassifier {
                        Toggle("Recognize the exercise automatically", isOn: Binding(
                            get: { model.recognizesExercise },
                            set: { model.recognizesExercise = $0 }
                        ))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("options.recognizeExercise")
                        Text("After each set, an on-device model trained by the Plumb team guesses the exercise from your pose points. If it isn’t confident, Plumb uses the exercise you chose. Its accuracy is still being tested.")
                    } else {
                        Text("This build has no trained recognition model, so Plumb uses the exercise you choose on the first screen.")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle("Options")
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
            Text("Plumb couldn’t recognize the exercise confidently, so it used your choice: \(chosen).")
                .font(.subheadline)
                .accessibilityIdentifier("result.recognition")
        }
    }

    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.previewSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                #if DEBUG
                if isDemo {
                    Text("DEMO INPUT")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(.yellow, in: Capsule())
                }
                #endif
                status
                Spacer()
                if model.stage == .framing {
                    Text("\u{00A0}\(captureCopy.framingPrompt)\u{00A0}")
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(captureCopy.framingPrompt)
                    Button { Task { await model.beginSet() } } label: {
                        Text("Start set").foregroundStyle(.black)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white)
                } else if model.stage == .capturing {
                    Text("Move at your own pace")
                    Button("Stop set") {
                        let tappedAt = ContinuousClock.now
                        Task { await model.endSet(tappedAt: tappedAt) }
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color(red: 198 / 255, green: 40 / 255, blue: 40 / 255))
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
                    Text(captureCopy.showJoints)
                case .landmarksVisible:
                    Image(systemName: "checkmark.circle.fill")
                    Text(captureCopy.jointsVisible)
                }
            } else {
                Image(systemName: "viewfinder")
                Text("Get ready")
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.68), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button("Done") {
                        observationSpeaker.stop()
                        Task { await model.finishSession() }
                    }
                        .font(.body)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                if let result = model.result {
                    switch result {
                    case .measured(let analysis, let cue):
                        Text("Set reviewed").font(.largeTitle.bold())
                        Text("\(analysis.reps.count) measured reps")
                            .font(.title2.weight(.semibold)).monospacedDigit()
                        recognitionNote
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
                            if model.cueDismissed {
                                Text("Observation marked not relevant.").font(.title3)
                            } else {
                                Text(cue.observation).font(.title3.weight(.semibold))
                                Text("Observed in reps \(cue.repNumbers.map(String.init).joined(separator: " and ")).")
                                Text(cue.nextAction)
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
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                            }
                        } else {
                            if analysis.reps.count < 4 {
                                Text("Plumb needs at least four measured reps before it can show an observation.")
                                    .font(.title3)
                            } else {
                                Text("No clear pattern to call out in this set.").font(.title3)
                            }
                            Text("This is a camera measurement, not a full technique assessment.")
                        }
                        if let comparison = model.comparison {
                            comparisonView(comparison)
                        } else if let gap = model.comparisonGap {
                            Text(gap == .differentExercise
                                 ? "Plumb compares sets of the same exercise. Do another set of this exercise to compare."
                                 : "These sets used different camera views, so Plumb can’t compare them reliably.")
                                .foregroundStyle(.secondary)
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
                        .accessibilityIdentifier("result.shareSummary")
                        .accessibilityHint("Shares the measured summary without video")
                    case .insufficientView(let reason):
                        Text("Couldn’t assess this set").font(.largeTitle.bold())
                        recognitionNote
                        Text(reason)
                        Text(model.resultExercise.definition.copy.retakeHint)
                            .foregroundStyle(.secondary)
                    case .failed(let reason):
                        Text("Couldn’t review this set").font(.largeTitle.bold())
                        Text(reason)
                    case .interrupted:
                        Text("Set interrupted").font(.largeTitle.bold())
                        Text("Camera capture stopped before the set was complete.")
                    }
                }
                #if DEBUG
                if isValidationMode, let milliseconds = model.lastStopToResultMilliseconds {
                    Text("Validation timing · Stop to result: \(milliseconds) ms")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("validation.stopToResult")
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                observationSpeaker.stop()
                Task { await model.startPreview() }
            } label: {
                Text(retakeLabel)
                    .foregroundStyle(primaryButtonLabelColor)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { observationSpeaker.stop() }
    }

    private var retakeLabel: String {
        if case .insufficientView = model.result { return "Retake set" }
        if case .measured(_, let cue) = model.result, cue != nil { return "Try this next set" }
        return "Try another set"
    }

    private var historyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                historySection
                Button(role: .destructive) {
                    deleteAllRequested = true
                } label: {
                    Text("Delete all local data")
                        .font(.subheadline)
                        .foregroundStyle(destructiveLabelColor)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle("History")
    }

    @ViewBuilder private var historySection: some View {
        if model.historyIssue == .corrupted {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t read saved history").font(.headline)
                Text("You can move the damaged file aside and start a new local history.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Recover history") { model.recoverHistory() }
                    .buttonStyle(.bordered)
            }
        } else if model.historyIssue == .unavailable {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.hasPendingDeletion ? "Deletion couldn’t finish" : "History temporarily unavailable")
                    .font(.headline)
                Text(model.hasPendingDeletion
                     ? "Tap Try again to finish removing the local data."
                     : "The saved file could not be accessed. Unlock this iPhone, then try again.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Try again") { model.retryHistory() }
                    .buttonStyle(.bordered)
            }
        } else if !model.history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved sessions").font(.headline)
                ForEach(model.history) { session in
                    HStack(spacing: 16) {
                        NavigationLink { historyDetail(session) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    Text("\(session.sets.count) measured sets")
                                        .font(.subheadline)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("history.session")
                        .accessibilityHint("Review measured sets")
                        Button {
                            deleteCandidate = session.id
                        } label: {
                            Text("Delete")
                                .frame(minWidth: 70, minHeight: 44, alignment: .trailing)
                                .contentShape(Rectangle())
                        }
                            .font(.subheadline)
                            .accessibilityLabel("Delete session from \(session.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Divider()
                }
            }
        } else {
            Text("No saved sessions yet.")
        }
    }

    private func historyDetail(_ session: WorkoutSessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(session.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.title2.weight(.semibold))
                ForEach(session.sets.indices, id: \.self) { index in
                    let set = session.sets[index]
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set \(index + 1)").font(.headline)
                        Text(set.exercise.definition.copy.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(set.analysis.reps.count) measured reps")
                            .monospacedDigit()
                        if let cue = set.cue {
                            if set.cueResponse == .notRelevant {
                                Text("Observation marked not relevant.")
                            } else {
                                Text(cue.observation)
                                Text(cue.nextAction)
                            }
                        } else {
                            Text("No clear pattern to call out in this set.")
                        }
                        DisclosureGroup("Rep details") {
                            repList(set.analysis.reps, exercise: set.exercise)
                        }
                    }
                    if index < session.sets.count - 1 { Divider() }
                }
                Text("These are camera measurements from one view, not a full technique assessment.")
                    .font(.footnote)
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
                    .font(.caption).foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 20) {
                Text(issue.title).font(.largeTitle.bold())
                Text(issue.message)
                    .fixedSize(horizontal: false, vertical: true)
                if issue.offersSettings {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text("Open Settings").foregroundStyle(primaryButtonLabelColor)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if issue.offersSettings {
                    Button("Try again") {
                        Task { await model.cancel(); await model.startPreview() }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { await model.cancel(); await model.startPreview() }
                    } label: {
                        Text("Try again").foregroundStyle(primaryButtonLabelColor)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}
