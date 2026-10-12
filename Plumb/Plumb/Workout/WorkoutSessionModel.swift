import AVFoundation
import Foundation
import Observation

nonisolated enum HistoryIssue: Equatable {
    case corrupted
    case unavailable
}

nonisolated enum WorkoutStage: Equatable {
    case ready
    case openingCamera
    case framing
    case countdown(Int)
    case capturing
    case analyzing
    case result
    case error(CameraIssue)
}

nonisolated enum CameraIssue: Equatable {
    case permissionDenied
    case unavailable
    case interrupted
    case startFailed

    var title: String {
        switch self {
        case .permissionDenied: "Camera access needed"
        case .unavailable: "Camera unavailable"
        case .interrupted: "Camera interrupted"
        case .startFailed: "Couldn’t start camera"
        }
    }

    var message: String {
        switch self {
        case .permissionDenied: "Allow camera access in Settings."
        case .unavailable: "The camera is unavailable right now. Try again in a moment."
        case .interrupted: "Camera capture stopped. Try again."
        case .startFailed: "Try again in a moment."
        }
    }

    var offersSettings: Bool { self == .permissionDenied }
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
    private var previewFrames: [PoseFrame] = []
    private var lastPreviewFrameAt: ContinuousClock.Instant?
    private var framingWatchdog: Task<Void, Never>?
    private var isStopping = false
    @ObservationIgnored private var pendingSessions: [UUID: WorkoutSessionSummary] = [:]
    @ObservationIgnored private var pendingDeleteIDs: Set<UUID> = []
    @ObservationIgnored private var pendingDeleteAll = false
    @ObservationIgnored private var stopTappedAt: ContinuousClock.Instant?

    private(set) var stage: WorkoutStage = .ready
    private(set) var result: WorkoutResult?
    private(set) var frameCount = 0
    private(set) var framingStatus: FramingStatus = .checking
    private(set) var lastStopToResultMilliseconds: Int?
    private(set) var cueDismissed = false
    private(set) var currentSession: WorkoutSessionSummary?
    private(set) var comparison: Comparison?
    private(set) var history: [WorkoutSessionSummary] = []
    private(set) var historyIssue: HistoryIssue?
    private(set) var comparisonRecap: Recap?
    private(set) var isGeneratingRecap = false
    var hasPendingDeletion: Bool { pendingDeleteAll || !pendingDeleteIDs.isEmpty }
    var isRecording: Bool { stage == .capturing }
    var previewSession: AVCaptureSession { source.previewSession }

    init(source: any PoseStreaming, store: (any SessionStoring)? = nil,
         narrator: ComparisonNarrator? = nil) {
        self.source = source
        self.store = store
        self.narrator = narrator ?? ComparisonNarrator()
        if let store {
            do { history = try store.load().sorted { $0.startedAt > $1.startedAt } }
            catch { historyIssue = Self.issue(for: error) }
        }
    }

    func startPreview() async {
        guard stage == .ready || stage == .result else { return }
        stage = .openingCamera
        await collectionTask?.value
        collectionTask = nil
        guard stage == .openingCamera else { return }
        result = nil
        lastStopToResultMilliseconds = nil
        stopTappedAt = nil
        cueDismissed = false
        frames = []
        frameCount = 0
        previewFrames = []
        lastPreviewFrameAt = nil
        framingStatus = .checking
        framingWatchdog?.cancel()
        framingWatchdog = nil
        do {
            let stream = try await source.start()
            guard stage == .openingCamera else {
                await source.stop()
                return
            }
            stage = .framing
            isStopping = false
            framingWatchdog = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                    guard let self, self.stage == .framing else { return }
                    if let lastPreviewFrameAt = self.lastPreviewFrameAt,
                       lastPreviewFrameAt.duration(to: .now) >= .seconds(1) {
                        self.previewFrames = []
                        self.framingStatus = .checking
                    }
                }
            }
            collectionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await frame in stream {
                    if self.stage == .framing {
                        self.previewFrames.append(frame)
                        if self.previewFrames.count > 5 { self.previewFrames.removeFirst() }
                        self.lastPreviewFrameAt = .now
                        self.framingStatus = EvidenceGate.previewStatus(self.previewFrames)
                    }
                    if (self.stage == .capturing || (self.stage == .analyzing && self.isStopping)) &&
                        self.frames.count < 1_800 {
                        self.frames.append(frame)
                        self.frameCount = self.frames.count
                    }
                }
                guard !self.isStopping else { return }
                self.framingWatchdog?.cancel()
                self.framingWatchdog = nil
                if self.stage == .capturing && self.source.endedAtLimit {
                    self.stage = .analyzing
                    self.completeAnalysis()
                } else if self.stage == .capturing {
                    self.result = .interrupted
                    self.stage = .result
                } else if self.stage == .framing || self.isCountingDown {
                    self.stage = .error(.interrupted)
                }
                await self.source.stop()
            }
        } catch CameraSourceError.denied {
            if stage == .openingCamera { stage = .error(.permissionDenied) }
        } catch CameraSourceError.unavailable {
            if stage == .openingCamera { stage = .error(.unavailable) }
        } catch {
            if stage == .openingCamera { stage = .error(.startFailed) }
        }
    }

    func beginSet(countdown: Int = 3) async {
        guard stage == .framing else { return }
        framingWatchdog?.cancel()
        framingWatchdog = nil
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

    func endSet(tappedAt: ContinuousClock.Instant = ContinuousClock.now) async {
        guard stage == .capturing else { return }
        stopTappedAt = tappedAt
        isStopping = true
        stage = .analyzing
        await source.stop()
        await collectionTask?.value
        collectionTask = nil
        guard stage == .analyzing else { return }
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
        defer {
            if let stopTappedAt {
                let parts = stopTappedAt.duration(to: ContinuousClock.now).components
                lastStopToResultMilliseconds = max(0, Int(parts.seconds) * 1_000 +
                                                   Int(parts.attoseconds / 1_000_000_000_000_000))
            }
            stopTappedAt = nil
            stage = .result
        }
        switch SquatAnalyzer.analyze(frames) {
        case .analyzed(let analysis):
            guard !analysis.reps.isEmpty else {
                result = .insufficientView("No complete squat repetitions were measured. Try another set with your full body in view.")
                return
            }
            let cue = CueSelector.select(from: analysis)
            result = .measured(analysis, cue)
            record(analysis: analysis, cue: cue)
        case .insufficientView(let reason):
            result = .insufficientView(reason)
        case .failed(let reason):
            result = .failed(reason)
        }
    }

    func finishSession() async {
        await cancel()
        currentSession = nil
        comparison = nil
        comparisonRecap = nil
    }

    func deleteHistory(id: UUID) {
        guard store != nil else { return }
        pendingSessions.removeValue(forKey: id)
        if !pendingDeleteAll { pendingDeleteIDs.insert(id) }
        if currentSession?.id == id {
            currentSession = nil
            comparison = nil
            comparisonRecap = nil
        }
        retryHistory()
    }

    func deleteAllData() {
        guard store != nil else { return }
        pendingDeleteAll = true
        pendingDeleteIDs = []
        pendingSessions = [:]
        currentSession = nil
        comparison = nil
        comparisonRecap = nil
        retryHistory()
    }

    func recoverHistory() {
        guard let store, historyIssue == .corrupted else { return }
        do {
            _ = try store.recoverCorruptStore()
            retryHistory()
        } catch { historyIssue = Self.issue(for: error) }
    }

    func retryHistory() {
        guard let store else { return }
        do {
            if pendingDeleteAll {
                try store.deleteAll()
                pendingDeleteAll = false
            }
            for id in Array(pendingDeleteIDs) {
                try store.delete(id: id)
                pendingDeleteIDs.remove(id)
            }
            _ = try store.load()
            for session in pendingSessions.values {
                try store.save(session)
            }
            history = try store.load().sorted { $0.startedAt > $1.startedAt }
            pendingSessions = [:]
            historyIssue = nil
        } catch { historyIssue = Self.issue(for: error) }
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
        guard store != nil else { return }
        pendingSessions[session.id] = session
        retryHistory()
    }

    private static func issue(for error: Error) -> HistoryIssue {
        if let storeError = error as? SessionStoreError, storeError == .corrupted {
            return .corrupted
        }
        return .unavailable
    }

    func cancel() async {
        isStopping = true
        stage = .ready
        framingWatchdog?.cancel()
        framingWatchdog = nil
        await source.stop()
        await collectionTask?.value
        collectionTask = nil
        frames = []
        previewFrames = []
        lastPreviewFrameAt = nil
        framingStatus = .checking
        frameCount = 0
        result = nil
        lastStopToResultMilliseconds = nil
        stopTappedAt = nil
    }

    func backgrounded() async {
        switch stage {
        case .openingCamera, .framing, .countdown, .capturing, .analyzing:
            await cancel()
        case .ready, .result, .error:
            break
        }
    }

    private var isCountingDown: Bool {
        if case .countdown = stage { return true }
        return false
    }
}
