import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var model: WorkoutSessionModel

    @MainActor init(source: any PoseStreaming) {
        _model = State(initialValue: WorkoutSessionModel(source: source))
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
            if ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") {
                Text("DEMO INPUT")
                    .font(.caption.bold())
                    .padding(6)
                    .background(.yellow, in: Capsule())
                    .padding(.top, 6)
            }
        }
        .tint(Color(red: 31 / 255, green: 106 / 255, blue: 83 / 255))
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await model.backgrounded() } }
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
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
                Text("Recording · \(model.frameCount) pose samples")
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
                        repList(analysis.reps)
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
                Button("Try another set") { Task { await model.startPreview() } }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Done") { Task { await model.cancel() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
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
