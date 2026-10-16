import AVFoundation
import Foundation
import Testing
@testable import Finn

nonisolated struct WatchSyncRulesTests {
    @Test func everyPhoneStageHasAWatchStage() {
        #expect(WatchSyncRules.stage(for: .ready) == .ready)
        #expect(WatchSyncRules.stage(for: .openingCamera) == .ready)
        #expect(WatchSyncRules.stage(for: .error(.interrupted)) == .ready)
        #expect(WatchSyncRules.stage(for: .framing) == .framing)
        #expect(WatchSyncRules.stage(for: .countdown(2)) == .countdown)
        #expect(WatchSyncRules.stage(for: .capturing) == .capturing)
        #expect(WatchSyncRules.stage(for: .analyzing) == .analyzing)
        #expect(WatchSyncRules.stage(for: .result) == .result)
    }

    @Test func stateCarriesOnlyWhatTheStageShows() {
        func state(
            _ stage: WorkoutStage,
            _ exercise: ExerciseKind = .bodyweightSquat,
            result: WorkoutResult? = nil
        ) -> WatchState {
            WatchSyncRules.state(
                stage: stage,
                exercise: exercise,
                liveReps: 4,
                caption: "Rep 4 was faster",
                result: result,
                cueDismissed: false,
                handsFree: true,
                demoInput: false
            )
        }
        #expect(state(.framing) == WatchState(
            stage: .framing,
            exercise: "Squat",
            wristControls: false,
            handsFree: true
        ))
        #expect(state(.countdown(3)).countdown == 3)
        #expect(state(.capturing) == WatchState(
            stage: .capturing,
            exercise: "Squat",
            reps: 4,
            caption: "Rep 4 was faster",
            wristControls: false,
            handsFree: true
        ))
        #expect(state(.capturing, .pushUp).wristControls == false)
        #expect(state(.capturing, .pushUp).exercise == "Push-up")
        let coached = WatchSyncRules.state(
            stage: .capturing,
            exercise: .bodyweightSquat,
            liveReps: 5,
            caption: nil,
            result: nil,
            cueDismissed: false,
            handsFree: false,
            demoInput: false,
            coachMessage: "Five reps counted. Stay with me for the next one."
        )
        #expect(coached.coachMessage?.contains("Five") == true)
        let measured = state(.result, result: .measured(analysis(reps: 6), nil))
        #expect(measured.reps == 6)
        #expect(measured.caption == nil)
        #expect(measured.summary == "6 reps measured.")
        let refused = state(.result, result: .insufficientView("Keep your hip visible."))
        #expect(refused.reps == 0)
        #expect(refused.summary == "Finn couldn’t measure this set. The reason is on your iPhone.")
    }

    @Test func summaryNamesRepsAndTheObservationUnlessDismissed() {
        let cue = Cue(
            kind: .rangeDecreased,
            repNumbers: [5, 6],
            earlierMedian: 0.2,
            laterMedian: 0.1,
            observation: "Your range became shorter in the last two reps.",
            nextAction: "Choose a range you can repeat on each rep."
        )
        #expect(WatchSyncRules.summary(for: .measured(analysis(reps: 6), cue), cueDismissed: false)
            == "6 reps measured. Your range became shorter in the last two reps.")
        #expect(WatchSyncRules.summary(for: .measured(analysis(reps: 6), cue), cueDismissed: true)
            == "6 reps measured.")
        #expect(WatchSyncRules.summary(for: .measured(analysis(reps: 1), nil), cueDismissed: false)
            == "1 rep measured.")
        #expect(WatchSyncRules.summary(for: .interrupted, cueDismissed: false)
            == "The set stopped before it was complete.")
        #expect(WatchSyncRules.summary(for: nil, cueDismissed: false) == nil)
    }

    @Test func sameScreenIgnoresTapAndTime() {
        let state = WatchState(stage: .capturing, reps: 2)
        var tapped = state
        tapped.haptic = .rep
        tapped.sentAt = 99
        #expect(WatchSyncRules.sameScreen(state, tapped))
        var moved = state
        moved.reps = 3
        #expect(!WatchSyncRules.sameScreen(state, moved))
    }

    private func analysis(reps: Int) -> SetAnalysis {
        SetAnalysis(reps: (1 ... reps).map {
            RepMetric(number: $0, startTime: Double($0 - 1) * 2, endTime: Double($0) * 2, relativeRange: 0.2)
        }, confidence: 0.9, rubricVersion: "squat-side-v7")
    }
}

@MainActor
struct WatchSyncSessionTests {
    /// A set run on the iPhone reaches the watch as framing, start, each rep, end, and the result.
    @Test func aSetReachesTheWatchStageByStage() async throws {
        let source = WatchTestPoseSource()
        let model = WorkoutSessionModel(source: source)
        var sent: [WatchState] = []
        var now = 1_000.0
        let sync = WatchSync(model: model, clock: { now += 1
            return now }) { sent.append($0) }
        #expect(sent.map(\.stage) == [.ready])
        #expect(sent.first?.exercise == "Squat")

        await model.startPreview()
        try await waitUntil { sent.last?.stage == .framing }
        await model.beginSet(countdown: 0)
        try await waitUntil { sent.last?.stage == .capturing }
        #expect(sent.last?.haptic == WatchHaptic.none)

        let frames = trace(reps: 6)
        for frame in frames {
            source.emit(frame)
        }
        try await waitUntil { model.frameCount == frames.count }
        try await waitUntil { (sent.last?.reps ?? 0) >= 5 }
        await model.endSet()
        try await waitUntil { sent.last?.stage == .result }

        // observation may fold two quick changes into one update, so reps rise but may skip a number.
        let running = sent.filter { $0.stage == .capturing }
        #expect(running.count >= 2)
        #expect(zip(running, running.dropFirst()).allSatisfy { $1.reps > $0.reps })
        #expect(running.dropFirst().allSatisfy { $0.haptic == .none })
        let lastRunning = try #require(sent.lastIndex { $0.stage == .capturing })
        #expect(sent[lastRunning + 1].haptic == .none)
        let result = try #require(sent.last)
        #expect(result.reps == 6)
        #expect(result.summary?.hasPrefix("6 reps measured.") == true)
        #expect(result.haptic == .none)
        // Each state is newer than the one before it, so the watch never rewinds.
        #expect(zip(sent, sent.dropFirst()).allSatisfy { $1.isNewer(than: $0) })
        #expect(sync.current?.haptic == WatchHaptic.none)
        #expect(sync.current?.stage == .result)
    }

    @Test func demoInputIsMarkedOnTheWatch() async throws {
        let model = WorkoutSessionModel(source: WatchTestPoseSource())
        var sent: [WatchState] = []
        _ = WatchSync(model: model, demoInput: true) { sent.append($0) }
        #expect(sent.last?.demoInput == true)
    }

    @Test func heartbeatKeepsSetAliveWithoutAnotherTap() async throws {
        let source = WatchTestPoseSource()
        let model = WorkoutSessionModel(source: source)
        var sent: [WatchState] = []
        let sync = WatchSync(model: model) { sent.append($0) }
        await model.startPreview()
        try await waitUntil { sent.last?.stage == .framing }
        await model.beginSet(countdown: 0)
        try await waitUntil { sent.last?.stage == .capturing }
        let before = try #require(sent.last)
        sync.heartbeat()
        let after = try #require(sent.last)
        #expect(after.setID == before.setID)
        #expect(after.sentAt > before.sentAt)
        #expect(after.haptic == .none)
        await model.cancel()
    }

    @Test func turningOffPhoneHapticsDuringCaptureUpdatesTheWatch() async throws {
        let suite = "WatchSyncTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = WorkoutSessionModel(
            source: WatchTestPoseSource(),
            preferences: FinnPreferences(defaults: defaults)
        )
        var sent: [WatchState] = []
        let sync = WatchSync(model: model) { sent.append($0) }
        await model.startPreview()
        try await waitUntil { sent.last?.stage == .framing }
        await model.beginSet(countdown: 0)
        try await waitUntil { sent.last?.stage == .capturing }
        #expect(sent.last?.hapticsEnabled == true)
        model.hapticFeedback = .off
        try await waitUntil { sent.last?.hapticsEnabled == false }
        #expect(sync.current?.hapticsEnabled == false)
        #expect(sent.last?.stage == .capturing)
        await model.cancel()
    }

    /// Returns as soon as the condition holds. The limit only bounds a real hang: on a loaded CI
    /// simulator, with many main-actor tests running at once, the live analysis of a whole set can
    /// take several seconds.
    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        timeout: Duration = .seconds(30)
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the watch state")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func trace(reps: Int) -> [PoseFrame] {
        (0 ... (reps * 20)).map { index in
            let phase = Double(index % 20) / 20
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: [
                .leftHip: JointPoint(x: 0.47, y: hipY, confidence: 0.99),
                .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: 0.99),
                .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.99),
                .rightHip: JointPoint(x: 0.53, y: hipY, confidence: 0.99),
                .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: 0.99),
                .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: 0.99),
            ])
        }
    }
}

@MainActor
private final class WatchTestPoseSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) {
        continuation?.yield(frame)
    }
}
