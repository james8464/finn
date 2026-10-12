import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var model: WorkoutSessionModel
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    private var primaryButtonLabelColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .black : .white
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
            if isDemo && !isCaptureStage {
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
            if phase == .background { Task { await model.backgrounded() } }
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
                Image("PlumbMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)
                    .padding(.bottom, 36)
                Text("Check your squat.")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 12)
                Text("Get one observation after a set of squats. Try another set to see what changed.")
                    .font(.body)
                    .padding(.bottom, 40)
                VStack(alignment: .leading, spacing: 18) {
                    Label("Place your iPhone at hip height, a few steps away.", systemImage: "iphone.gen3")
                    Label("Turn sideways and keep your whole body in view.", systemImage: "figure.stand")
                }
                .font(.body)
                .padding(.bottom, 40)
                Text("Analyzed on this iPhone. No video saved.")
                    .font(.footnote)
                    .padding(.bottom, 20)
                Text("Plumb observes one camera view. It cannot assess your whole technique or prevent injury.")
                    .font(.footnote)
                    .padding(.bottom, 32)
                HStack(spacing: 24) {
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
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            }
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

    private var privacyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Video is processed on this iPhone and never saved.")
                    Text("Plumb uses the camera to measure a bodyweight squat from the side. Camera frames and pose points stay on this iPhone.")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved results").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Measured set summaries are saved on this iPhone so you can review previous sets.")
                    Text("Saved summaries may be included in your device backup.")
                    Text("Delete saved sessions in History.")
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
                    Text("\u{00A0}Stand sideways. Show head to toe.\u{00A0}")
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Stand sideways. Show head to toe.")
                    Button { Task { await model.beginSet() } } label: {
                        Text("Start set").foregroundStyle(primaryButtonLabelColor)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
                    Button("Done") { Task { await model.finishSession() } }
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
                        if let cue {
                            if model.cueDismissed {
                                Text("Observation marked not relevant.").font(.title3)
                            } else {
                                Text(cue.observation).font(.title3.weight(.semibold))
                                Text("Observed in reps \(cue.repNumbers.map(String.init).joined(separator: " and ")).")
                                Text(cue.nextAction)
                                Button("Not relevant") { model.dismissCue() }
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
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        } else if (model.currentSession?.sets.count ?? 0) >= 2 {
                            Text("These sets used different camera views, so Plumb can’t compare them reliably.")
                                .foregroundStyle(.secondary)
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        } else {
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        }
                        ShareLink(item: SetShareSummary.text(for: analysis, cue: cue,
                                                              cueDismissed: model.cueDismissed)) {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("result.shareSummary")
                        .accessibilityHint("Shares the measured summary without video")
                    case .insufficientView(let reason):
                        Text("Couldn’t assess this set").font(.largeTitle.bold())
                        Text(reason)
                        Text("Move the phone farther back and keep your hip, knee, and ankle visible.")
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
                        .foregroundStyle(Color(red: 198 / 255, green: 40 / 255, blue: 40 / 255))
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
        if model.historyError {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t read saved history").font(.headline)
                Text("You can move the damaged file aside and start a new local history.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Recover history") { model.recoverHistory() }
                    .buttonStyle(.bordered)
            }
        } else if !model.history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved sessions").font(.headline)
                ForEach(model.history) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Text("\(session.sets.count) measured sets")
                                .font(.subheadline)
                        }
                        Spacer()
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

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with your previous set").font(.headline)
            Text(comparisonStatement(comparison.rangeDirection))
                .font(.title3.weight(.semibold))
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
            if let recap = model.comparisonRecap {
                Text(recap.text)
                    .font(.subheadline)
                if recap.source == .appleIntelligence {
                    Text("Worded with Apple Intelligence")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Comparison note")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if model.isGeneratingRecap {
                ProgressView("Writing comparison note")
            } else {
                Button("Explain comparison") { Task { await model.explainComparison() } }
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
