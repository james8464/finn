import SwiftUI
import UIKit

private enum PlumbStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 43 / 255, green: 132 / 255, blue: 95 / 255, alpha: 1)
            : UIColor(red: 31 / 255, green: 106 / 255, blue: 83 / 255, alpha: 1)
    })
    static let supportingText = Color.primary.opacity(0.72)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: WorkoutSessionModel
    @State private var observationSpeaker = ObservationSpeaker()
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    private let primaryButtonLabelColor = Color.white
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
                    narrator: ComparisonNarrator? = nil) {
        _model = State(initialValue: WorkoutSessionModel(source: source, store: store,
                                                         narrator: narrator))
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
        .tint(PlumbStyle.accent)
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
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                        .padding(.bottom, 32)
                }
                Text("Squat check")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)
                Text("One clear observation after each set.")
                    .font(.body)
                    .foregroundStyle(PlumbStyle.supportingText)
                Divider()
                    .padding(.vertical, 30)
                Text("Before you start")
                    .font(.headline)
                    .padding(.bottom, 20)
                VStack(spacing: 0) {
                    setupStep("Place your iPhone", detail: "At hip height, a few steps away.",
                              symbol: "iphone.gen3")
                    Divider().padding(.leading, 44)
                    setupStep("Stand sideways", detail: "Keep your whole body in view.",
                              symbol: "figure.stand")
                }
                Label("Analyzed on this iPhone. No video saved.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.top, 28)
                Text("Measurements come from one camera view.")
                    .font(.footnote)
                    .foregroundStyle(PlumbStyle.supportingText)
                    .padding(.leading, 27)
                    .padding(.top, 4)
            }
            #if DEBUG
            .padding(.top, isDemo && dynamicTypeSize.isAccessibilitySize ? 64 : 0)
            #endif
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollIndicators(.hidden)
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
                .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { historyPage } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { privacyPage } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
            }
        }
    }

    private func setupStep(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(PlumbStyle.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.body).foregroundStyle(PlumbStyle.supportingText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var privacyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Video is processed on this iPhone and never saved.")
                    Text("Plumb uses the camera to measure a bodyweight squat from the side. Camera frames and pose points stay on this iPhone.")
                    Text("One camera view cannot assess your whole technique or prevent injury.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved results").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Measured set summaries are saved on this iPhone so you can review previous sets.")
                    Text("Saved summaries may be included in your device backup.")
                    Text("Delete saved sessions in History.")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional audio").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Tap to hear an observation through your iPhone or headphones. Plumb does not record sound or use the microphone.")
                }
                Divider()
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

    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.previewSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, .black.opacity(0.76)],
                           startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
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
                    Text("\u{00A0}Stand sideways. Show head to toe.\u{00A0}")
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Stand sideways. Show head to toe.")
                    Button { Task { await model.beginSet() } } label: {
                        Text("Start set").foregroundStyle(.black)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.white)
                } else if model.stage == .capturing {
                    Text("Move at your own pace")
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

    private var status: some View {
        HStack(spacing: 10) {
            if model.isRecording {
                Image(systemName: "viewfinder")
                Text("Analyzing live")
            } else if model.stage == .framing {
                switch model.framingStatus {
                case .checking:
                    Image(systemName: "viewfinder")
                    Text("Checking leg visibility")
                case .adjustPosition:
                    Image(systemName: "viewfinder")
                    Text("Show hip, knee and ankle")
                case .landmarksVisible:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Hip, knee and ankle visible")
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
                        Text("Set reviewed")
                            .font(.largeTitle.bold())
                        Text("\(analysis.reps.count) measured reps")
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundStyle(PlumbStyle.supportingText)
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
                            Divider().padding(.vertical, 8)
                            if model.cueDismissed {
                                Text("Observation marked not relevant.")
                                    .font(.body)
                                    .foregroundStyle(PlumbStyle.supportingText)
                            } else {
                                Text("Observation")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PlumbStyle.supportingText)
                                Text(cue.observation)
                                    .font(.title2.weight(.semibold))
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
                                    .foregroundStyle(PlumbStyle.accent)
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
                            Divider().padding(.vertical, 8)
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
                        Divider().padding(.vertical, 8)
                        if let comparison = model.comparison {
                            comparisonView(comparison)
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        } else if (model.currentSession?.sets.count ?? 0) >= 2 {
                            Text("These sets used different camera views, so Plumb can’t compare them reliably.")
                                .foregroundStyle(PlumbStyle.supportingText)
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        } else {
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        }
                        ShareLink(item: SetShareSummary.text(for: analysis, cue: cue,
                                                              cueDismissed: model.cueDismissed,
                                                              comparison: model.comparison)) {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("result.shareSummary")
                        .accessibilityHint("Shares the measured summary without video")
                    case .insufficientView(let reason):
                        Text("Couldn’t assess this set").font(.largeTitle.bold())
                        Text(reason)
                        Text("Move the phone farther back and keep your hip, knee, and ankle visible.")
                            .foregroundStyle(PlumbStyle.supportingText)
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
                        .foregroundStyle(PlumbStyle.supportingText)
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
                .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { observationSpeaker.stop() }
    }

    private var retakeLabel: String {
        if case .insufficientView = model.result { return "Retake set" }
        if case .measured(_, let cue) = model.result, cue != nil { return "Try this next set" }
        return "Try another set"
    }

    private func nextAction(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PlumbStyle.accent)
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Next set")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PlumbStyle.supportingText)
                Text(text)
                    .font(.body)
            }
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
                                    Text("\(session.sets.count) measured sets")
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
                            repList(set.analysis.reps)
                        }
                        .padding(.top, 8)
                    }
                    if index < session.sets.count - 1 {
                        Divider().padding(.vertical, 28)
                    }
                }
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
            Text(model.comparisonRecap?.text ?? comparisonStatement(comparison.rangeDirection))
                .font(.title3.weight(.semibold))
            if model.comparisonRecap?.source == .appleIntelligence {
                Text("Worded with Apple Intelligence")
                    .font(.caption).foregroundStyle(PlumbStyle.supportingText)
            }
            DisclosureGroup("Set measurements") {
                VStack(alignment: .leading, spacing: 12) {
                    comparisonMetric("Set 1", range: comparison.firstMedianRange,
                                     duration: comparison.firstMedianDuration)
                    comparisonMetric("Set 2", range: comparison.secondMedianRange,
                                     duration: comparison.secondMedianDuration)
                }
            }
            Text("This comparison describes one camera-visible measure, not overall technique or safety.")
                .font(.footnote)
            DisclosureGroup("How range is measured") {
                Text("Relative range compares hip travel with the leg length seen by the camera. Use it only to compare your own sets from the same view.")
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

    private func comparisonMetric(_ title: String, range: Double, duration: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text("Range: \(range.formatted(.number.precision(.fractionLength(2))))")
            Text("Rep time: \(duration.formatted(.number.precision(.fractionLength(1)))) s")
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private func comparisonStatement(_ direction: RangeDirection) -> String {
        switch direction {
        case .longer: return "Camera-measured range was longer in set 2."
        case .shorter: return "Camera-measured range was shorter in set 2."
        case .noClearChange: return "No clear measured range change between sets."
        }
    }

    private func repList(_ reps: [RepMetric]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    ProgressView(value: min(1, rep.normalizedHipTravel / 0.6))
                        .tint(.secondary)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rep \(rep.number), \(rep.duration.formatted(.number.precision(.fractionLength(1)))) seconds, relative camera-observed range \(rep.normalizedHipTravel.formatted(.number.precision(.fractionLength(2))))")
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
                            .foregroundStyle(primaryButtonLabelColor)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Try again") {
                        Task { await model.cancel(); await model.startPreview() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PlumbStyle.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        Task { await model.cancel(); await model.startPreview() }
                    } label: {
                        Text("Try again")
                            .foregroundStyle(primaryButtonLabelColor)
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
