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

nonisolated enum ComparisonGap: Equatable {
    /// No earlier set of the same exercise in this session.
    case differentExercise
    /// An earlier set of the same exercise exists but differs in side, rubric, or has too few reps.
    case incompatibleSets
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
    @ObservationIgnored private let preferences: PlumbPreferences
    @ObservationIgnored private let exerciseClassifier: (any ExerciseClassifying)?
    @ObservationIgnored private let angleClassifier: (any AngleWindowClassifying)?
    @ObservationIgnored private let ruleClassifier: (any AngleWindowClassifying)?
    private var collectionTask: Task<Void, Never>?
    private var frames: [PoseFrame] = []
    private var previewFrames: [PoseFrame] = []
    /// Latest Vision 3D profile deviations seen while framing.
    private(set) var previewDeviations: [Double] = []
    private var lastPreviewFrameAt: ContinuousClock.Instant?
    private var framingWatchdog: Task<Void, Never>?
    private var isStopping = false
    @ObservationIgnored private var pendingSessions: [UUID: WorkoutSessionSummary] = [:]
    @ObservationIgnored private var pendingDeleteIDs: Set<UUID> = []
    @ObservationIgnored private var pendingDeleteAll = false
    @ObservationIgnored private var stopTappedAt: ContinuousClock.Instant?
    @ObservationIgnored private let announcer: (any LiveAnnouncing)?
    @ObservationIgnored private var startReadiness = StartReadiness()
    @ObservationIgnored private var liveMonitor: LiveSetMonitor?
    /// A hands-free start or stop on its way; at most one at a time.
    @ObservationIgnored private var handsFreeTask: Task<Void, Never>?

    private(set) var stage: WorkoutStage = .ready
    /// The exercise chosen on the setup screen. A capture keeps the exercise it started with.
    var selectedExercise: ExerciseKind = .bodyweightSquat
    /// The exercise used for the framing check and analysis of the current capture.
    private(set) var captureExercise: ExerciseKind = .bodyweightSquat
    private(set) var result: WorkoutResult?
    /// The exercise whose rubric produced `result`.
    private(set) var resultExercise: ExerciseKind = .bodyweightSquat
    /// Why some movements of a measured set did not count, in numbers; nil when all counted.
    private(set) var movementNote: String?
    /// The deepest and shallowest reps of the latest measured set, drawn on the result. Pose
    /// points only, kept in memory and never saved.
    private(set) var repExtremes: RepExtremes?
    /// What the optional exercise classifier concluded for the latest set.
    private(set) var recognition: ExerciseRecognition = .notAttempted
    /// Whether Plumb recognizes the exercise after a set (joint-angle rules unless the trained
    /// model is switched on). On by default; the chosen exercise stays the fallback.
    var recognizesExercise: Bool {
        didSet { preferences.recognizesExercise = recognizesExercise }
    }
    /// Whether a bundled trained model replaces the rules. Off by default, and only offered when
    /// this build includes a model.
    var usesTrainedModel: Bool {
        didSet { preferences.usesTrainedModel = usesTrainedModel }
    }
    /// True when a trained model (keypoint or angle) ships with this build.
    var hasExerciseClassifier: Bool { exerciseClassifier != nil || angleClassifier != nil }
    var recognitionMethod: RecognitionMethod {
        if usesTrainedModel {
            if exerciseClassifier != nil { return .keypointModel }
            if angleClassifier != nil { return .angleModel }
        }
        if ruleClassifier != nil { return .angleRules }
        return .unavailable
    }
    /// Whether Vision 3D pose may refuse a set filmed from the wrong angle. On by default.
    var checksCameraAngle: Bool {
        didSet {
            preferences.checksCameraAngle = checksCameraAngle
            source.setCameraAngleEstimation(checksCameraAngle)
            if !checksCameraAngle { previewDeviations = [] }
        }
    }
    /// The 3D camera-angle verdict for the latest analyzed set, kept for the validation readout.
    private(set) var lastViewVerdict: ViewCheck.Verdict = .unavailable
    var usesExerciseRecognition: Bool { recognizesExercise && recognitionMethod != .unavailable }
    private(set) var frameCount = 0
    private(set) var framingStatus: FramingStatus = .checking
    /// While framing, the joint that keeps the set from starting cleanly, named on screen.
    private(set) var unclearJoint: JointRole?
    private(set) var lastStopToResultMilliseconds: Int?
    private(set) var captureStartedAt: Date?
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
    /// The frames shown on the camera screen; nil when the source has no picture (demo input).
    var previewFeed: PreviewFeed? { source.previewFeed }
    /// The newest pose while the camera screen is open, for the live skeleton.
    private(set) var livePose: PoseFrame?
    /// Whether the set starts by itself once the athlete holds still in position, and ends when they
    /// walk away or stop moving after their reps. The Start and Stop buttons keep working.
    var handsFree: Bool {
        didSet {
            preferences.handsFree = handsFree
            if !handsFree {
                startReadiness.reset()
                handsFreeProgress = 0
            }
        }
    }
    /// Whether the countdown, each rep, and live observations are said aloud (through AirPods or
    /// other headphones when connected).
    var speaksLive: Bool {
        didSet { preferences.speaksLive = speaksLive }
    }
    /// Countdown of a set started hands-free, in seconds.
    @ObservationIgnored var handsFreeCountdown = 3
    /// While framing hands-free: how far the athlete is through holding position, 0 to 1.
    private(set) var handsFreeProgress = 0.0
    /// Reps counted so far in the running set.
    private(set) var liveRepCount = 0
    /// The latest live observation of the running set, such as a rep faster than the first ones.
    private(set) var liveCaption: String?
    /// The latest set was ended by Plumb (the athlete walked away or stopped), not by a tap.
    private(set) var endedHandsFree = false
    /// The person's most frequent pattern in recent sets of the chosen exercise, shown before a set.
    var focus: MistakeProfile? { MistakeProfile.make(history: history, exercise: selectedExercise) }
    /// The same, for the exercise being captured.
    var captureFocus: MistakeProfile? { MistakeProfile.make(history: history, exercise: captureExercise) }
    /// The latest set showed the person's most frequent pattern again.
    private(set) var repeatedPattern: MistakeProfile?
    /// Receives each live event of a running set, for a connected Apple Watch.
    @ObservationIgnored var onLiveEvent: ((LiveSetEvent, ExerciseKind) -> Void)?

    init(source: any PoseStreaming, store: (any SessionStoring)? = nil,
         narrator: ComparisonNarrator? = nil,
         exerciseClassifier: (any ExerciseClassifying)? = CoreMLExerciseClassifier.bundled(),
         angleClassifier: (any AngleWindowClassifying)? = CoreMLAngleClassifier.bundled(),
         ruleClassifier: (any AngleWindowClassifying)? = AngleRuleClassifier(),
         preferences: PlumbPreferences = .standard,
         announcer: (any LiveAnnouncing)? = nil) {
        self.source = source
        self.store = store
        self.narrator = narrator ?? ComparisonNarrator()
        self.exerciseClassifier = exerciseClassifier
        self.angleClassifier = angleClassifier
        self.ruleClassifier = ruleClassifier
        self.preferences = preferences
        self.announcer = announcer
        self.handsFree = preferences.handsFree
        self.speaksLive = preferences.speaksLive
        self.recognizesExercise = preferences.recognizesExercise
        self.usesTrainedModel = preferences.usesTrainedModel
        self.checksCameraAngle = preferences.checksCameraAngle
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
        captureExercise = selectedExercise
        recognition = .notAttempted
        result = nil
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
        lastStopToResultMilliseconds = nil
        captureStartedAt = nil
        stopTappedAt = nil
        cueDismissed = false
        frames = []
        frameCount = 0
        previewFrames = []
        previewDeviations = []
        lastViewVerdict = .unavailable
        lastPreviewFrameAt = nil
        livePose = nil
        framingStatus = .checking
        framingWatchdog?.cancel()
        framingWatchdog = nil
        resetLiveSet()
        source.setCameraAngleEstimation(checksCameraAngle)
        source.configure(for: captureExercise)
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
                        self.previewDeviations = []
                        self.framingStatus = .checking
                    }
                }
            }
            collectionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await frame in stream {
                    switch self.stage {
                    case .framing, .countdown, .capturing: self.livePose = frame
                    default: self.livePose = nil
                    }
                    if self.stage == .framing {
                        self.previewFrames.append(frame)
                        if self.previewFrames.count > 5 { self.previewFrames.removeFirst() }
                        self.lastPreviewFrameAt = .now
                        self.updateFramingStatus(with: frame)
                        self.updateHandsFreeStart(with: frame)
                    }
                    if (self.stage == .capturing || (self.stage == .analyzing && self.isStopping)) &&
                        self.frames.count < 1_800 {
                        self.frames.append(frame)
                        self.frameCount = self.frames.count
                        if self.stage == .capturing { self.followLiveSet() }
                    }
                }
                self.livePose = nil
                guard !self.isStopping else { return }
                self.framingWatchdog?.cancel()
                self.framingWatchdog = nil
                if self.stage == .capturing && self.source.endedAtLimit {
                    self.stage = .analyzing
                    self.completeAnalysis()
                    self.announceResult()
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
            say("\(remaining)")
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard stage == .countdown(remaining) else { return }
        }
        guard stage == .framing || stage == .countdown(1) else { return }
        await source.prepareForSet()
        guard stage == .framing || stage == .countdown(1) else { return }
        liveMonitor = LiveSetMonitor(definition: captureExercise.definition)
        liveRepCount = 0
        liveCaption = nil
        endedHandsFree = false
        captureStartedAt = .now
        stage = .capturing
        if countdown > 0 { say("Go") }
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
        announceResult()
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
        // The capture includes walking to the spot and back to the phone; only the set is analyzed.
        let captured = SetWindow.active(frames, requirement: captureExercise.definition.evidence)
        let recognition = recognizeExercise(in: captured)
        self.recognition = recognition
        let exercise: ExerciseKind
        if case .recognized(let recognized, _) = recognition {
            exercise = recognized
        } else {
            exercise = captureExercise
        }
        let definition = exercise.definition
        let setFrames = exercise == captureExercise
            ? captured : SetWindow.active(frames, requirement: definition.evidence)
        resultExercise = exercise
        lastViewVerdict = ViewCheck.assess(setFrames, expected: definition.expectedView)
        let (outcome, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(
            setFrames, as: definition, viewCheck: checksCameraAngle ? .enforce : .ignore)
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
        switch outcome {
        case .analyzed(let analysis):
            let explanation = diagnostics?.explanation(for: definition, counted: analysis.reps.count)
            guard !analysis.reps.isEmpty else {
                result = .insufficientView([definition.copy.noCompleteReps, explanation]
                    .compactMap { $0 }.joined(separator: " "))
                return
            }
            movementNote = explanation
            repExtremes = RepExtremes.make(analysis, frames: setFrames, definition: definition)
            let cue = CueSelector.select(from: analysis, exercise: definition)
            let issues = SetIssue.issues(diagnostics: diagnostics, cue: cue,
                                         spedUp: liveMonitor?.sawFasterRep ?? false)
            // Before saving, so "again" compares with the earlier sets only.
            let earlier = MistakeProfile.make(history: history, exercise: exercise)
            repeatedPattern = earlier.flatMap { issues.contains($0.issue) ? $0 : nil }
            result = .measured(analysis, cue)
            record(analysis: analysis, cue: cue, exercise: exercise, frames: setFrames, issues: issues)
        case .insufficientView(let reason):
            result = .insufficientView(reason)
        case .failed(let reason):
            result = .failed(reason)
        }
    }

    private func updateFramingStatus(with frame: PoseFrame) {
        let definition = captureExercise.definition
        if checksCameraAngle, let deviation = frame.profileDeviationDegrees {
            previewDeviations.append(deviation)
            if previewDeviations.count > 5 { previewDeviations.removeFirst() }
        }
        if checksCameraAngle,
           ViewCheck.previewAsksToTurn(previewDeviations, expected: definition.expectedView) {
            framingStatus = .turnToExpectedView
        } else {
            framingStatus = EvidenceGate.previewStatus(previewFrames, requirement: definition.evidence)
        }
        unclearJoint = framingStatus == .adjustPosition
            ? EvidenceGate.unclearJoint(previewFrames, requirement: definition.evidence) : nil
    }

    /// Starts the countdown once the athlete has held still in position (`StartReadiness`).
    private func updateHandsFreeStart(with frame: PoseFrame) {
        guard handsFree, handsFreeTask == nil else { return }
        let progress = startReadiness.update(with: frame, definition: captureExercise.definition)
        let placed = framingStatus == .landmarksVisible
        handsFreeProgress = placed ? progress : 0
        guard placed, startReadiness.isReady else { return }
        startReadiness.reset()
        handsFreeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.beginSet(countdown: self.handsFreeCountdown)
            self.handsFreeTask = nil
            self.handsFreeProgress = 0
        }
    }

    /// Counts reps while the set runs, says them and any live observation, and ends a hands-free
    /// set once the athlete walks away or stops moving after their reps.
    private func followLiveSet() {
        guard var monitor = liveMonitor else { return }
        let events = monitor.update(with: frames)
        liveMonitor = monitor
        let definition = monitor.definition
        for event in events {
            if case .repCounted(let count) = event {
                liveRepCount = count
            } else {
                liveCaption = event.caption(for: definition)
            }
            say(event.spoken(for: definition))
            onLiveEvent?(event, definition.kind)
        }
        guard handsFree, handsFreeTask == nil, monitor.isOver else { return }
        endedHandsFree = true
        handsFreeTask = Task { @MainActor [weak self] in
            await self?.endSet()
            self?.handsFreeTask = nil
        }
    }

    /// After a set ends, says its outcome: the person may be several steps from the screen.
    private func announceResult() {
        switch result {
        case .measured(let analysis, _):
            say(analysis.reps.count == 1 ? "1 rep measured" : "\(analysis.reps.count) reps measured")
        case .insufficientView, .failed:
            say("Plumb couldn’t measure this set. The reason is on screen.")
        case .interrupted, nil:
            break
        }
    }

    private func say(_ text: String) {
        guard speaksLive else { return }
        announcer?.announce(text)
    }

    private func resetLiveSet() {
        handsFreeTask?.cancel()
        handsFreeTask = nil
        startReadiness.reset()
        handsFreeProgress = 0
        liveMonitor = nil
        liveRepCount = 0
        liveCaption = nil
        endedHandsFree = false
    }

    private func recognizeExercise(in frames: [PoseFrame]) -> ExerciseRecognition {
        guard recognizesExercise, !frames.isEmpty else { return .notAttempted }
        switch recognitionMethod {
        case .keypointModel:
            if let exerciseClassifier { return ExerciseRecognizer.recognize(frames, using: exerciseClassifier) }
        case .angleModel:
            if let angleClassifier { return AngleRecognizer.recognize(frames, using: angleClassifier) }
        case .angleRules:
            if let ruleClassifier { return AngleRecognizer.recognize(frames, using: ruleClassifier) }
        case .unavailable:
            break
        }
        return .notAttempted
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

    private func record(analysis: SetAnalysis, cue: Cue?, exercise: ExerciseKind, frames: [PoseFrame],
                        issues: [SetIssue]) {
        guard case .usable(let side) = EvidenceGate.assess(
            frames, requirement: exercise.definition.evidence) else { return }
        var session = currentSession ?? WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [])
        let newSet = SetSummary(
            id: UUID(), sessionID: session.id, capturedAt: .now,
            bodySide: side, analysis: analysis, cue: cue, cueResponse: .unanswered,
            exercise: exercise, issues: issues
        )
        let previousSameExercise = session.sets.last { $0.exercise == exercise }
        session.sets.append(newSet)
        currentSession = session
        comparisonRecap = nil
        if let previousSameExercise {
            comparison = SetComparison.compare(previousSameExercise, newSet)
        } else {
            comparison = nil
        }
        save(session)
    }

    /// Why a measured set has no comparison even though the session has earlier sets.
    var comparisonGap: ComparisonGap? {
        guard comparison == nil, let session = currentSession, session.sets.count >= 2,
              let latest = session.sets.last else { return nil }
        let earlier = session.sets.dropLast()
        return earlier.contains { $0.exercise == latest.exercise } ? .incompatibleSets : .differentExercise
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
        resetLiveSet()
        await source.stop()
        await collectionTask?.value
        collectionTask = nil
        frames = []
        previewFrames = []
        previewDeviations = []
        lastPreviewFrameAt = nil
        livePose = nil
        framingStatus = .checking
        frameCount = 0
        captureStartedAt = nil
        result = nil
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
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
