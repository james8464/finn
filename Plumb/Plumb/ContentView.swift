import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var model: WorkoutSessionModel
    @State private var deleteCandidate: UUID?
    @State private var deleteAllRequested = false
    private var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") }
    private var isCaptureStage: Bool {
        switch model.stage {
        case .framing, .countdown, .capturing, .analyzing: return true
        default: return false
        }
    }

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
                case .error(let message): failure(message)
                }
            }
            .navigationTitle("Plumb")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .top) {
            if isDemo && !isCaptureStage {
                Text("DEMO INPUT")
                    .font(.caption.bold())
                    .padding(6)
                    .background(.yellow, in: Capsule())
                    .padding(.top, 6)
            }
        }
        .tint(colorScheme == .dark
              ? Color(red: 143 / 255, green: 225 / 255, blue: 188 / 255)
              : Color(red: 31 / 255, green: 106 / 255, blue: 83 / 255))
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
            VStack(alignment: .leading, spacing: 24) {
                Image("PlumbMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                Text("Find your line.")
                    .font(.largeTitle.bold())
                Text("Review one camera-visible pattern in a bodyweight squat set, then try again.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    Label("Place your iPhone at hip height, a few steps away.", systemImage: "iphone.gen3")
                    Label("Turn sideways and keep your whole body in view.", systemImage: "figure.stand")
                    Label("Your video stays on this iPhone and is not saved.", systemImage: "lock.shield")
                }
                .padding(.vertical, 12)
                Button("Set up camera") { Task { await model.startPreview() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Text("Plumb observes movement from one camera angle. It cannot judge every part of your technique or prevent injury.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    historyPage
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.previewSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                if isDemo {
                    Text("DEMO INPUT")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(.yellow, in: Capsule())
                }
                status
                Spacer()
                if model.stage == .framing {
                    Text("Stand sideways. Keep your head and feet in frame.")
                        .multilineTextAlignment(.center)
                    Button("Start set") { Task { await model.beginSet() } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else if model.stage == .capturing {
                    Text("Move at your own pace")
                    Button("Stop set") { Task { await model.endSet() } }
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

    private var status: some View {
        HStack(spacing: 10) {
            if model.isRecording {
                Circle().fill(.red).frame(width: 11, height: 11)
                Text("Recording")
            } else {
                Image(systemName: "viewfinder")
                Text(model.stage == .framing ? "Position your phone" : "Get ready")
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
                if let result = model.result {
                    switch result {
                    case .measured(let analysis, let cue):
                        Text("Set reviewed").font(.largeTitle.bold())
                        Text("\(analysis.reps.count) measured reps")
                            .font(.title2.weight(.semibold)).monospacedDigit()
                        if let cue, !model.cueDismissed {
                            Text(cue.observation).font(.title3.weight(.semibold))
                            Text("Observed in reps \(cue.repNumbers.map(String.init).joined(separator: " and ")).")
                                .foregroundStyle(.secondary)
                            Text(cue.nextAction)
                            Button("Not relevant") { model.dismissCue() }
                                .buttonStyle(.bordered)
                        } else {
                            Text("No clear change to call out in this set.").font(.title3)
                            Text("This is a camera measurement, not a full technique assessment.")
                                .foregroundStyle(.secondary)
                        }
                        if let comparison = model.comparison {
                            comparisonView(comparison)
                            DisclosureGroup("Rep details") {
                                repList(analysis.reps)
                            }
                        } else if (model.currentSession?.sets.count ?? 0) >= 2 {
                            Text("These sets used different camera views, so Plumb can’t compare them reliably.")
                                .foregroundStyle(.secondary)
                            repList(analysis.reps)
                        } else {
                            repList(analysis.reps)
                        }
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
                Button(retakeLabel) { Task { await model.startPreview() } }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Done") { Task { await model.finishSession() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
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
                Button("Delete all local data", role: .destructive) {
                    deleteAllRequested = true
                }
                .font(.subheadline)
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
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Delete") { deleteCandidate = session.id }
                            .font(.subheadline)
                            .accessibilityLabel("Delete session from \(session.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Divider()
                }
            }
        } else {
            Text("No saved sessions yet.")
                .foregroundStyle(.secondary)
        }
    }

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with your previous set").font(.headline)
            HStack {
                comparisonMetric("Set 1", range: comparison.firstMedianRange,
                                 duration: comparison.firstMedianDuration)
                Spacer()
                comparisonMetric("Set 2", range: comparison.secondMedianRange,
                                 duration: comparison.secondMedianDuration)
            }
            Text(comparisonStatement(comparison.rangeDirection))
            .font(.subheadline.weight(.semibold))
            Text("This comparison describes one camera-visible measure, not overall technique or safety.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Relative range compares hip travel with the leg length seen by the camera. Use it only to compare your own sets from the same view.")
                .font(.footnote).foregroundStyle(.secondary)
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
                    .buttonStyle(.bordered)
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
                HStack {
                    Text("Rep \(rep.number)")
                    Spacer()
                    Text(rep.duration.formatted(.number.precision(.fractionLength(1))) + " s")
                        .monospacedDigit()
                }
                .font(.subheadline)
                ProgressView(value: min(1, rep.normalizedHipTravel / 0.6))
                    .tint(.secondary)
                    .accessibilityLabel("Relative camera-observed range for rep \(rep.number)")
                Divider()
            }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Camera unavailable").font(.largeTitle.bold())
            Text(message)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
            Button("Try again") {
                Task { await model.cancel(); await model.startPreview() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}
