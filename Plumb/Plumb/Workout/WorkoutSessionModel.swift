import AVFoundation
import Foundation
import Observation

nonisolated enum WorkoutStage: Equatable {
    case ready
    case openingCamera
    case framing
    case countdown(Int)
    case capturing
    case analyzing
    case result
    case error(String)
}

nonisolated enum WorkoutResult {
    case measured(SetAnalysis, Cue?)
    case insufficientView(String)
    case failed(String)
    case interrupted
}

@Observable
@MainActor
final class WorkoutSessionModel {
    private let source: any PoseStreaming
    @ObservationIgnored private let store: (any SessionStoring)?
    @ObservationIgnored private let narrator: ComparisonNarrator
    private var collectionTask: Task<Void, Never>?
    private var frames: [PoseFrame] = []
    private var isStopping = false

    private(set) var stage: WorkoutStage = .ready
    private(set) var result: WorkoutResult?
    private(set) var frameCount = 0
    private(set) var cueDismissed = false
    private(set) var currentSession: WorkoutSessionSummary?
    private(set) var comparison: Comparison?
    private(set) var history: [WorkoutSessionSummary] = []
    private(set) var historyError = false
    private(set) var comparisonRecap: Recap?
    private(set) var isGeneratingRecap = false
    var isRecording: Bool { stage == .capturing }
    var previewSession: AVCaptureSession { source.previewSession }

    init(source: any PoseStreaming, store: (any SessionStoring)? = nil,
         narrator: ComparisonNarrator? = nil) {
        self.source = source
        self.store = store
        self.narrator = narrator ?? ComparisonNarrator()
        if let store {
            do { history = try store.load() }
            catch { historyError = true }
        }
    }

    func startPreview() async {
        guard stage == .ready || stage == .result else { return }
        stage = .openingCamera
        result = nil
        cueDismissed = false
        frames = []
        frameCount = 0
        do {
            let stream = try await source.start()
            guard stage == .openingCamera else {
                await source.stop()
                return
            }
            stage = .framing
            isStopping = false
            collectionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await frame in stream {
                    if (self.stage == .capturing || (self.stage == .analyzing && self.isStopping)) &&
                        self.frames.count < 1_800 {
                        self.frames.append(frame)
                        self.frameCount = self.frames.count
                    }
                }
                guard !self.isStopping else { return }
                if self.stage == .capturing && self.source.endedAtLimit {
                    self.stage = .analyzing
                    self.completeAnalysis()
                } else if self.stage == .capturing {
                    self.result = .interrupted
                    self.stage = .result
                } else if self.stage == .framing || self.isCountingDown {
                    self.stage = .error("Camera capture was interrupted. Try again.")
                }
                await self.source.stop()
            }
        } catch CameraSourceError.denied {
            if stage == .openingCamera { stage = .error("Allow camera access in Settings to record a set.") }
        } catch CameraSourceError.unavailable {
            if stage == .openingCamera { stage = .error("This iPhone camera is unavailable. Try again when it is free.") }
        } catch {
            if stage == .openingCamera { stage = .error("The camera could not start. Try again.") }
        }
    }

    func beginSet(countdown: Int = 3) async {
        guard stage == .framing else { return }
        frames = []
        frameCount = 0
        for remaining in stride(from: max(0, countdown), through: 1, by: -1) {
            stage = .countdown(remaining)
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard stage == .countdown(remaining) else { return }
        }
        guard stage == .framing || stage == .countdown(1) else { return }
        await source.prepareForSet()
        guard stage == .framing || stage == .countdown(1) else { return }
        stage = .capturing
    }

    func endSet() async {
        guard stage == .capturing else { return }
        isStopping = true
        stage = .analyzing
        await source.stop()
        await collectionTask?.value
        collectionTask = nil
        completeAnalysis()
    }

    func dismissCue() {
        cueDismissed = true
        guard var session = currentSession, session.sets.last?.cue != nil else { return }
        session.sets[session.sets.count - 1].cueResponse = .notRelevant
        currentSession = session
        save(session)
    }

    private func completeAnalysis() {
        switch SquatAnalyzer.analyze(frames) {
        case .analyzed(let analysis):
            let cue = CueSelector.select(from: analysis)
            result = .measured(analysis, cue)
            record(analysis: analysis, cue: cue)
        case .insufficientView(let reason):
            result = .insufficientView(reason)
        case .failed(let reason):
            result = .failed(reason)
        }
        stage = .result
    }

    func finishSession() async {
        await cancel()
        currentSession = nil
        comparison = nil
        comparisonRecap = nil
    }

    func deleteHistory(id: UUID) {
        guard let store else { return }
        do {
            try store.delete(id: id)
            history = try store.load()
            if currentSession?.id == id { currentSession = nil; comparison = nil }
        } catch { historyError = true }
    }

    func recoverHistory() {
        guard let store else { return }
        do {
            _ = try store.recoverCorruptStore()
            history = try store.load()
            historyError = false
        } catch { historyError = true }
    }

    private func record(analysis: SetAnalysis, cue: Cue?) {
        guard case .usable(let side) = EvidenceGate.assess(frames) else { return }
        var session = currentSession ?? WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [])
        session.sets.append(SetSummary(
            id: UUID(), sessionID: session.id, capturedAt: .now,
            bodySide: side, analysis: analysis, cue: cue, cueResponse: .unanswered
        ))
        currentSession = session
        comparisonRecap = nil
        if session.sets.count >= 2 {
            comparison = SetComparison.compare(session.sets[session.sets.count - 2], session.sets.last!)
        }
        save(session)
    }

    func explainComparison() async {
        guard let comparison, !isGeneratingRecap else { return }
        isGeneratingRecap = true
        let recap = await narrator.recap(for: comparison)
        if self.comparison == comparison { comparisonRecap = recap }
        isGeneratingRecap = false
    }

    private func save(_ session: WorkoutSessionSummary) {
        guard let store else { return }
        do {
            try store.save(session)
            history = try store.load().sorted { $0.startedAt > $1.startedAt }
            historyError = false
        } catch { historyError = true }
    }

    func cancel() async {
        isStopping = true
        stage = .ready
        await source.stop()
        await collectionTask?.value
        collectionTask = nil
        frames = []
        frameCount = 0
        result = nil
    }

    func backgrounded() async { await cancel() }

    private var isCountingDown: Bool {
        if case .countdown = stage { return true }
        return false
    }
}
