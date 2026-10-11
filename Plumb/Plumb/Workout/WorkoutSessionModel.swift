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
    private var collectionTask: Task<Void, Never>?
    private var frames: [PoseFrame] = []
    private var isStopping = false

    private(set) var stage: WorkoutStage = .ready
    private(set) var result: WorkoutResult?
    private(set) var frameCount = 0
    private(set) var cueDismissed = false
    var isRecording: Bool { stage == .capturing }
    var previewSession: AVCaptureSession { source.previewSession }

    init(source: any PoseStreaming) {
        self.source = source
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

    func dismissCue() { cueDismissed = true }

    private func completeAnalysis() {
        switch SquatAnalyzer.analyze(frames) {
        case .analyzed(let analysis):
            result = .measured(analysis, CueSelector.select(from: analysis))
        case .insufficientView(let reason):
            result = .insufficientView(reason)
        case .failed(let reason):
            result = .failed(reason)
        }
        stage = .result
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
