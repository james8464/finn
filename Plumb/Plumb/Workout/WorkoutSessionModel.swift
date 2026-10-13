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
    /// This set or every earlier one of the exercise has fewer than four measured reps.
    case tooFewReps
    /// The earlier sets were filmed from the other side of the body.
    case differentSide
    /// The earlier sets differ in camera view or measurement version.
    case incompatibleSets
    /// This set was only partly visible, so its ranges are not compared.
    case partlyVisible
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
    @ObservationIgnored let preferences: PlumbPreferences
    @ObservationIgnored private let exerciseClassifier: (any ExerciseClassifying)?
    @ObservationIgnored private let angleClassifier: (any AngleWindowClassifying)?
    @ObservationIgnored private let ruleClassifier: (any AngleWindowClassifying)?
    private var collectionTask: Task<Void, Never>?
    private var frames: [PoseFrame] = []
    private var previewFrames: [PoseFrame] = []
    /// Latest Vision 3D profile deviations seen while framing, newest last.
    var previewDeviations: [Double] { previewEstimates.map { $0.deviation } }
    /// The same, with the frame time of each: an estimate older than `previewEstimateLifetime`
    /// no longer counts.
    private var previewEstimates: [(time: TimeInterval, deviation: Double)] = []
    /// Estimates stop when the phone is hot (the 3D request is skipped) or when Vision 3D measures
    /// someone closer to the camera than the athlete; old readings must not keep asking the person
    /// to turn or hold back a hands-free start. New ones arrive about four times a second.
    static let previewEstimateLifetime: TimeInterval = 2
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
    /// Saves finished sessions to Apple Health. Nil for demo and recorded input, which must never
    /// reach Health.
    @ObservationIgnored private let fitness: (any FitnessWorkoutSaving)?
    /// Sessions being saved to Apple Health right now: a session is never saved twice at once.
    @ObservationIgnored private var fitnessSavesInFlight: Set<UUID> = []
    /// Sessions deleted while their save to Apple Health was running: if it fails, there is
    /// nothing left to retry, so it reports nothing.
    @ObservationIgnored private var fitnessSavesOfDeletedSessions: Set<UUID> = []
    /// Sessions saved to Apple Health in this run, kept even if writing history fails.
    @ObservationIgnored private var fitnessRecords: [UUID: FitnessWorkoutRecord] = [:]
    /// The date of a measured set, for the session it joins. Tests replace it.
    @ObservationIgnored let currentDate: () -> Date

    private(set) var stage: WorkoutStage = .ready
    /// The exercise chosen on the setup screen. A capture keeps the exercise it started with. The app
    /// remembers it across launches (`PlumbPreferences.selectedExercise`).
    var selectedExercise: ExerciseKind = .bodyweightSquat {
        didSet { preferences.selectedExercise = selectedExercise }
    }
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
    /// Per-rep facts for the latest measured set (pull-ups: chin above the hands, straight arms,
    /// swing). Empty for exercises without such checks.
    private(set) var formNotes: [String] = []
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
            if !checksCameraAngle { previewEstimates = [] }
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
    /// The camera stopped during the set (another app took it, an interruption); the part captured
    /// before was reviewed.
    private(set) var endedEarly = false
    /// The latest set reached Plumb's 2-minute limit and was stopped there.
    private(set) var endedAtLimit = false
    /// What to change for the next try, matched to why the set was refused; nil when the reason
    /// already says it.
    private(set) var retakeHint: String?
    /// While framing: whether the exercise's joints are clear, whatever the 3D turn tip says.
    @ObservationIgnored private var previewLandmarksVisible = false
    /// While framing hands-free: since when (frame time) the tracked athlete has not been ready,
    /// and when Plumb last said why.
    @ObservationIgnored private var notReadySince: TimeInterval?
    @ObservationIgnored private var lastFramingSpeech = -Double.infinity
    /// While framing: the frame time framing began, and since when nobody has been in view.
    @ObservationIgnored private var framingSince: TimeInterval?
    @ObservationIgnored private var nobodySeenSince: TimeInterval?
    /// Plumb closing the camera because framing went on with no set.
    @ObservationIgnored private var framingCloseTask: Task<Void, Never>?
    /// Why Plumb closed the camera by itself while framing, for the first screen; nil otherwise.
    private(set) var framingClosedNote: String?
    /// The person's most frequent pattern in recent sets of the chosen exercise, shown before a set.
    var focus: MistakeProfile? { MistakeProfile.make(history: history, exercise: selectedExercise) }
    /// The same, for the exercise being captured.
    /// Worked out once per camera screen: the screen reads it on every redraw, and it goes over the
    /// whole history.
    private(set) var captureFocus: MistakeProfile?
    /// Whether the newest pose has the athlete's joints. The camera screen's text reads this rather
    /// than `livePose`, which is new on every frame and redrew the whole screen 15 times a second.
    private(set) var athleteInView = false
    /// The latest set showed the person's most frequent pattern again.
    private(set) var repeatedPattern: MistakeProfile?
    /// Receives each live event of a running set, for a connected Apple Watch.
    @ObservationIgnored var onLiveEvent: ((LiveSetEvent, ExerciseKind) -> Void)?
    /// Whether tapping Done saves the session to Apple Health as a workout, so it appears in the
    /// Fitness app. Off by default; turning it on asks Health for permission (`requestFitnessAccess`).
    var savesToFitness: Bool {
        didSet { preferences.savesToFitness = savesToFitness }
    }
    /// Health's permission for Plumb to save workouts, as last checked. Only read once the option is on.
    private(set) var fitnessAccess: FitnessAuthorization = .notDetermined
    /// The latest save to Apple Health, for the session it concerns.
    private(set) var fitnessSave: FitnessSaveReport?
    /// Personalize with Health (`WorkoutSessionModel+Health.swift`). Nil for demo and recorded
    /// input, which never read Health.
    @ObservationIgnored let health: (any HealthReading)?
    /// Whether Plumb reads Health to adapt its advice. Off by default; turning it on asks Health.
    var personalizesWithHealth: Bool {
        didSet { preferences.personalizesWithHealth = personalizesWithHealth }
    }
    /// What Plumb last read from Health; nil until read, or while the option is off.
    var healthSnapshot: HealthSnapshot?
    /// The one-time "Make Plumb more personal?" offer is on screen.
    var showsPersonalizationOffer = false
    /// The latest heart rate from the Apple Watch, while a set or the rest after it runs.
    var liveHeartRate: Int?
    @ObservationIgnored var liveHeartRateAt: Date?
    /// Watch heart rate readings received while the set ran.
    @ObservationIgnored var setHeartRateReadings: [Double] = []
    /// Heart rate during the latest set, from the Apple Watch.
    var setHeartRate: SetHeartRate?
    /// False for demo and recorded input: those sessions are never saved to Apple Health.
    var offersFitness: Bool { fitness != nil }
    /// A session still open on the first screen: Cancel, or the app going to the background during
    /// a set, comes back there without Done. The first screen offers to finish it (`finishSession`).
    var unfinishedSession: WorkoutSessionSummary? { stage == .ready ? currentSession : nil }

    init(source: any PoseStreaming, store: (any SessionStoring)? = nil,
         narrator: ComparisonNarrator? = nil,
         exerciseClassifier: (any ExerciseClassifying)? = CoreMLExerciseClassifier.bundled(),
         angleClassifier: (any AngleWindowClassifying)? = CoreMLAngleClassifier.bundled(),
         ruleClassifier: (any AngleWindowClassifying)? = AngleRuleClassifier(),
         preferences: PlumbPreferences = .standard,
         announcer: (any LiveAnnouncing)? = nil,
         fitness: (any FitnessWorkoutSaving)? = nil,
         health: (any HealthReading)? = nil,
         currentDate: @escaping () -> Date = { Date() }) {
        self.source = source
        self.store = store
        self.narrator = narrator ?? ComparisonNarrator()
        self.exerciseClassifier = exerciseClassifier
        self.angleClassifier = angleClassifier
        self.ruleClassifier = ruleClassifier
        self.preferences = preferences
        self.announcer = announcer
        self.fitness = fitness
        self.health = health
        self.currentDate = currentDate
        self.handsFree = preferences.handsFree
        self.speaksLive = preferences.speaksLive
        self.recognizesExercise = preferences.recognizesExercise
        self.usesTrainedModel = preferences.usesTrainedModel
        self.checksCameraAngle = preferences.checksCameraAngle
        self.savesToFitness = preferences.savesToFitness
        self.personalizesWithHealth = preferences.personalizesWithHealth
        if let remembered = preferences.selectedExercise { selectedExercise = remembered }
        if let store {
            do { history = try store.load().sorted { $0.startedAt > $1.startedAt } }
            catch { historyIssue = Self.issue(for: error) }
        }
        // iOS terminated Plumb after a set without Done: the session is still open, so the first
        // screen offers to finish it and the next set joins it, as before the relaunch.
        if let latest = history.first, latest.isOpen == true { currentSession = latest }
        refreshFitnessAccess()
    }

    func startPreview() async {
        guard stage == .ready || stage == .result else { return }
        stage = .openingCamera
        await collectionTask?.value
        collectionTask = nil
        guard stage == .openingCamera else { return }
        captureExercise = selectedExercise
        captureFocus = MistakeProfile.make(history: history, exercise: captureExercise)
        recognition = .notAttempted
        framingClosedNote = nil
        // The setup screen's Fitness line was about the session that ended; a save still running keeps it.
        if fitnessSave?.status != .saving { fitnessSave = nil }
        result = nil
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
        setHeartRate = nil
        formNotes = []
        lastStopToResultMilliseconds = nil
        captureStartedAt = nil
        stopTappedAt = nil
        cueDismissed = false
        frames = []
        frameCount = 0
        previewFrames = []
        previewEstimates = []
        lastViewVerdict = .unavailable
        lastPreviewFrameAt = nil
        livePose = nil
        athleteInView = false
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
                        self.previewEstimates = []
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
                    let inView = !(self.livePose?.joints.isEmpty ?? true)
                    if self.athleteInView != inView { self.athleteInView = inView }
                    if self.stage == .framing {
                        self.previewFrames.append(frame)
                        if self.previewFrames.count > 5 { self.previewFrames.removeFirst() }
                        self.lastPreviewFrameAt = .now
                        self.updateFramingStatus(with: frame)
                        self.updateHandsFreeStart(with: frame)
                        self.closeFramingIfIdle(with: frame)
                    }
                    if (self.stage == .capturing || (self.stage == .analyzing && self.isStopping)) &&
                        self.frames.count < 1_800 {
                        // The source picks a frame's clock when it forwards it, and the set starts
                        // here when the frame is read: a frame stamped with the preview clock just
                        // before the countdown ended can arrive first. Set frames count from 0, so
                        // a clock going back means the frames so far were not the set's.
                        if let previous = self.frames.last, frame.time < previous.time {
                            self.frames = []
                            self.liveMonitor = self.liveMonitor.map { LiveSetMonitor(definition: $0.definition) }
                        }
                        self.frames.append(frame)
                        self.frameCount = self.frames.count
                        if self.stage == .capturing { self.followLiveSet() }
                    }
                }
                self.livePose = nil
                self.athleteInView = false
                guard !self.isStopping else { return }
                self.framingWatchdog?.cancel()
                self.framingWatchdog = nil
                if self.stage == .capturing && self.source.endedAtLimit {
                    self.endedAtLimit = true
                    self.stage = .analyzing
                    self.completeAnalysis()
                    self.announceResult()
                } else if self.stage == .capturing,
                          let first = self.frames.first, let last = self.frames.last,
                          last.time - first.time >= EvidenceRubric.minimumSetDuration {
                    // The camera stopped mid-set: review what was captured rather than lose it.
                    self.endedEarly = true
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
        setHeartRateReadings = []
        setHeartRate = nil
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
            // Plumb is sure the person did another exercise than the one chosen: the next sets use
            // it, so they are framed, counted live and stopped hands-free as that exercise.
            if recognized != captureExercise { selectedExercise = recognized }
        } else {
            exercise = captureExercise
        }
        let definition = exercise.definition
        let setFrames = exercise == captureExercise
            ? captured : SetWindow.active(frames, requirement: definition.evidence)
        resultExercise = exercise
        lastViewVerdict = ViewCheck.assess(setFrames, expected: definition.expectedView)
        // Already trimmed to the set: analyze exactly these frames, so the saved set is gated the same.
        let (outcome, measured) = ExerciseAnalyzer.analyzeWithDiagnostics(
            setFrames, as: definition, viewCheck: checksCameraAngle ? .enforce : .ignore, trimsToSet: false)
        var diagnostics = measured
        // Plumb ended the capture (its time limit, or the camera stopping), not the athlete: a
        // movement cut off then is not one they left unfinished, to note or to count in their pattern.
        if endedAtLimit || endedEarly { diagnostics?.unfinished = false }
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
        retakeHint = nil
        // A comparison belongs to the set it was made for; the new set makes its own or none.
        comparison = nil
        comparisonRecap = nil
        formNotes = []
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
            formNotes = FormChecks.sentences(for: analysis, frames: setFrames, definition: definition)
            // A camera angle outside the supported side view can distort relative range.
            // A camera angle outside the supported side view can distort relative range, and a partly
            // visible set is counted but not advised on.
            let cue = diagnostics?.angledView == nil && diagnostics?.partialVisibility == nil
                ? CueSelector.select(from: analysis, exercise: definition) : nil
            let issues = SetIssue.issues(diagnostics: diagnostics, cue: cue,
                                         spedUp: liveMonitor?.sawFasterRep ?? false)
            // Before saving, so "again" compares with the earlier sets only.
            let earlier = MistakeProfile.make(history: history, exercise: exercise)
            repeatedPattern = earlier.flatMap { issues.contains($0.issue) ? $0 : nil }
            result = .measured(analysis, cue)
            setHeartRate = SetHeartRate.make(setHeartRateReadings)
            record(analysis: analysis, cue: cue, exercise: exercise, frames: setFrames, issues: issues,
                   partlyVisible: diagnostics?.partialVisibility != nil)
            offerPersonalizationIfDue()
        case .insufficientView(let reason):
            result = .insufficientView(reason)
            retakeHint = Self.otherExerciseHint(in: frames, chosen: exercise, refusedFrames: setFrames)
                ?? Self.retakeHint(for: setFrames, definition: definition,
                                   viewRefused: lastViewVerdict.isMismatch && checksCameraAngle)
        case .failed(let reason):
            result = .failed(reason)
        }
    }

    /// The general retake advice fits a refusal for joints Plumb could not see; other refusals
    /// already say what to change, and a 3D view refusal points to its switch.
    private static func retakeHint(for frames: [PoseFrame], definition: ExerciseDefinition,
                                   viewRefused: Bool) -> String? {
        if viewRefused {
            return "If your side already faces the camera, turn off Check the camera angle in Options."
        }
        switch EvidenceGate.assess(frames, requirement: definition.evidence) {
        case .reject(.missingJoints), .reject(.lowConfidence): return definition.copy.retakeHint
        default: return nil
        }
    }

    /// When the chosen exercise was refused because its joints were not clear enough, but the same
    /// capture shows clear reps of another exercise (push-ups filmed while Squat was chosen, 13 October):
    /// the person probably picked the wrong exercise, so say which one Plumb saw. The camera angle is
    /// not checked here, since the angle verdict belonged to the wrong exercise.
    static func otherExerciseHint(in frames: [PoseFrame], chosen: ExerciseKind,
                                  refusedFrames: [PoseFrame]) -> String? {
        switch EvidenceGate.assess(refusedFrames, requirement: chosen.definition.evidence) {
        case .reject(.missingJoints), .reject(.lowConfidence): break
        default: return nil
        }
        var best: (kind: ExerciseKind, reps: Int)?
        // Only exercises of the same kind of setup: a bar exercise counts the shoulders' rise, which a
        // squat or push-up also shows, so floor and bar exercises never suggest each other.
        let hanging = chosen.definition.expectedView == .any
        for kind in ExerciseKind.allCases where kind != chosen && (kind.definition.expectedView == .any) == hanging {
            let definition = kind.definition
            let window = SetWindow.active(frames, requirement: definition.evidence)
            guard case .analyzed(let analysis) = ExerciseAnalyzer.analyzeWithDiagnostics(
                window, as: definition, viewCheck: .ignore, trimsToSet: false).outcome,
                analysis.reps.count >= 2, analysis.reps.count > (best?.reps ?? 0) else { continue }
            best = (kind, analysis.reps.count)
        }
        guard let best else { return nil }
        let name = best.kind.definition.copy.name
        return "Plumb counted \(best.reps) \(name.lowercased())s in this set, but \(chosen.definition.copy.name) was chosen. "
            + "If you did \(name.lowercased())s, choose \(name) on the first screen and retake the set."
    }

    private func updateFramingStatus(with frame: PoseFrame) {
        let definition = captureExercise.definition
        if checksCameraAngle, let deviation = frame.profileDeviationDegrees {
            previewEstimates.append((frame.time, deviation))
            if previewEstimates.count > 5 { previewEstimates.removeFirst() }
        }
        // Only when one has lapsed: every change of this list redraws what reads it.
        if let oldest = previewEstimates.first, frame.time - oldest.time > Self.previewEstimateLifetime {
        previewEstimates.removeAll { frame.time - $0.time > Self.previewEstimateLifetime }
        }
        if checksCameraAngle,
           ViewCheck.previewAsksToTurn(previewDeviations, expected: definition.expectedView) {
            framingStatus = .turnToExpectedView
        } else {
            framingStatus = EvidenceGate.previewStatus(previewFrames, requirement: definition.evidence)
        }
        previewLandmarksVisible = framingStatus == .landmarksVisible
            || (framingStatus == .turnToExpectedView
                && EvidenceGate.previewStatus(previewFrames, requirement: definition.evidence) == .landmarksVisible)
        unclearJoint = framingStatus == .adjustPosition
            ? EvidenceGate.unclearJoint(previewFrames, requirement: definition.evidence) : nil
    }

    /// Starts the countdown once the athlete has held still in position (`StartReadiness`).
    private func updateHandsFreeStart(with frame: PoseFrame) {
        guard handsFree, handsFreeTask == nil else { return }
        let progress = startReadiness.update(with: frame, definition: captureExercise.definition)
        // A slight angle only earns a tip, as for a set started by hand; a clear front view does not start.
        let clearlyFront = previewDeviations.count >= ViewCheck.minimumPreviewEstimates
            && previewDeviations.sorted()[previewDeviations.count / 2] >= ViewCheck.clearlyFrontDegrees
        let placed = previewLandmarksVisible && !(checksCameraAngle && clearlyFront)
        handsFreeProgress = placed ? progress : 0
        sayWhyNotReady(frame, placed: placed)
        guard placed, startReadiness.isReady else { return }
        startReadiness.reset()
        handsFreeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.beginSet(countdown: self.handsFreeCountdown)
            self.handsFreeTask = nil
            self.handsFreeProgress = 0
        }
    }

    /// Hands-free, the person is several steps from the screen: when they have stood in view for
    /// `notReadyDelay` seconds without Plumb seeing what it needs, say why, at most every
    /// `framingSpeechInterval` seconds.
    private func sayWhyNotReady(_ frame: PoseFrame, placed: Bool) {
        let tracked = frame.athleteTracking == .tracked && !frame.joints.isEmpty
        guard tracked, !placed || framingStatus == .turnToExpectedView else {
            notReadySince = nil
            return
        }
        let since = notReadySince ?? frame.time
        notReadySince = since
        guard frame.time - since >= Self.notReadyDelay,
              frame.time - lastFramingSpeech >= Self.framingSpeechInterval else { return }
        let phrase: String
        if framingStatus == .turnToExpectedView {
            phrase = "Turn your side to the camera"
        } else if let joint = unclearJoint {
            phrase = "\(joint.rawValue.capitalized) not clear. Step back or add light"
        } else {
            phrase = "Show your whole body"
        }
        lastFramingSpeech = frame.time
        say(phrase)
    }

    static let notReadyDelay: TimeInterval = 3
    static let framingSpeechInterval: TimeInterval = 8
    /// Hands-free, nobody in view this long is said aloud.
    static let nobodySeenDelay: TimeInterval = 5
    /// Framing closes by itself after this long with nobody in view...
    static let nobodySeenLimit: TimeInterval = 60
    /// ...or this long without a set starting.
    static let framingLimit: TimeInterval = 180

    /// The camera screen keeps the screen awake (`ContentView.keepsScreenOn`) and runs the camera
    /// and Vision; left in framing, it ran until the battery or the heat stopped it. Framing now
    /// closes after `framingLimit` without a set, or `nobodySeenLimit` with nobody in view. Hands-free,
    /// the person a few steps away also hears when Plumb sees nobody.
    private func closeFramingIfIdle(with frame: PoseFrame) {
        guard stage == .framing, handsFreeTask == nil, framingCloseTask == nil else { return }
        let since = framingSince ?? frame.time
        framingSince = since
        if frame.athleteVisible && !frame.joints.isEmpty {
            nobodySeenSince = nil
        } else if nobodySeenSince == nil {
            nobodySeenSince = frame.time
        }
        let nobodyFor = nobodySeenSince.map { frame.time - $0 } ?? 0
        let note: String?
        if frame.time - since >= Self.framingLimit {
            note = "Plumb closed the camera after 3 minutes without a set."
        } else if nobodyFor >= Self.nobodySeenLimit {
            note = "Plumb closed the camera after a minute without seeing anyone."
        } else {
            note = nil
        }
        if let note {
            framingCloseTask = Task { @MainActor [weak self] in
                guard let self else { return }
                self.say("Camera closed")
                self.framingClosedNote = note
                await self.cancel()
                self.framingCloseTask = nil
            }
            return
        }
        guard handsFree, nobodyFor >= Self.nobodySeenDelay,
              frame.time - lastFramingSpeech >= Self.framingSpeechInterval else { return }
        lastFramingSpeech = frame.time
        say("Plumb can’t see you. Step into view or add light")
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
            onLiveEvent?(event, definition.kind)
        }
        if let phrase = LiveSetEvent.phrase(for: events, definition: definition) { say(phrase) }
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
            let count = analysis.reps.count == 1 ? "1 rep measured" : "\(analysis.reps.count) reps measured"
            // One phrase: the person may still be exercising and should know why the set ended.
            say(endedAtLimit ? "2-minute limit reached. \(count)" : count)
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
        endedEarly = false
        endedAtLimit = false
        notReadySince = nil
        lastFramingSpeech = -Double.infinity
        framingSince = nil
        nobodySeenSince = nil
        previewLandmarksVisible = false
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

    /// Done on the result, or Finish session on the first screen: ends the session and, when the
    /// person turned it on, saves it to Apple Health once.
    func finishSession() async {
        let finished = currentSession
        await cancel()
        currentSession = nil
        comparison = nil
        comparisonRecap = nil
        guard var session = finished else { return }
        // Ended: a relaunch no longer offers to finish it.
        session.isOpen = nil
        save(session)
        await saveToFitness(session)
    }

    /// Re-reads Health's permission, which the person can change in Settings or Health at any time.
    /// HealthKit is not touched while the option is off.
    func refreshFitnessAccess() {
        guard let fitness, savesToFitness else { return }
        fitnessAccess = fitness.authorization
    }

    /// Asks Health for permission to save workouts, in context: right after the person turns the
    /// option on. Health shows its sheet only while the person has not answered.
    func requestFitnessAccess() async {
        guard let fitness, savesToFitness else { return }
        var access = fitness.authorization
        if access == .notDetermined { access = await fitness.requestAuthorization() }
        fitnessAccess = access
    }

    /// The Apple Health workout saved for a session, if any.
    func fitnessRecord(forSession id: UUID) -> FitnessWorkoutRecord? {
        fitnessRecords[id]
            ?? pendingSessions[id]?.fitnessWorkout
            ?? history.first(where: { $0.id == id })?.fitnessWorkout
            ?? (currentSession?.id == id ? currentSession?.fitnessWorkout : nil)
    }

    /// Whether History may offer to save a session to Apple Health: the option is on, the session
    /// has a measured set and is not saved yet. A session left open on the first screen can be saved,
    /// which finishes it; during a capture the session in progress is saved at Done.
    func canSaveToFitness(_ session: WorkoutSessionSummary) -> Bool {
        offersFitness && savesToFitness && (currentSession?.id != session.id || stage == .ready)
            && fitnessRecord(forSession: session.id) == nil
            && !fitnessSavesInFlight.contains(session.id)
            && FitnessWorkout.make(from: session) != nil
    }

    /// Saves a session from History or after a failed save. Never duplicates a workout: a saved or
    /// saving session is left alone. The session left open on the first screen is finished first, so
    /// no later set is left out of its workout.
    func saveToFitness(sessionID id: UUID) async {
        if currentSession?.id == id {
            guard stage == .ready, fitness != nil, savesToFitness else { return }
            await finishSession()
            return
        }
        guard let session = pendingSessions[id] ?? history.first(where: { $0.id == id }) else { return }
        await saveToFitness(session)
    }

    /// Whether deleting this session in Plumb leaves a workout in Apple Health: it was saved there,
    /// or a save is still running. Plumb never deletes Health data; the delete dialog says so.
    func leavesHealthWorkout(forSession id: UUID) -> Bool {
        fitnessRecord(forSession: id) != nil || fitnessSavesInFlight.contains(id)
    }

    /// Whether deleting all local data leaves workouts in Apple Health, for the same reasons.
    var leavesHealthWorkouts: Bool {
        !fitnessSavesInFlight.isEmpty
            || history.contains { leavesHealthWorkout(forSession: $0.id) }
            || pendingSessions.keys.contains { leavesHealthWorkout(forSession: $0) }
    }

    private func saveToFitness(_ session: WorkoutSessionSummary) async {
        let id = session.id
        guard let fitness, savesToFitness,
              let workout = FitnessWorkout.make(from: session),
              session.fitnessWorkout == nil, fitnessRecord(forSession: id) == nil,
              !fitnessSavesInFlight.contains(id) else { return }
        // Claimed before any suspension, so a second Done or retry cannot start another save.
        fitnessSavesInFlight.insert(id)
        defer {
            fitnessSavesInFlight.remove(id)
            fitnessSavesOfDeletedSessions.remove(id)
        }
        fitnessSave = FitnessSaveReport(sessionID: id, status: .saving)
        var access = fitness.authorization
        if access == .notDetermined { access = await fitness.requestAuthorization() }
        fitnessAccess = access
        switch access {
        case .authorized:
            break
        case .unavailable:
            reportFitnessSave(.unavailable, for: id)
            return
        case .notDetermined, .denied:
            reportFitnessSave(.needsPermission, for: id)
            return
        }
        do {
            let workoutID = try await fitness.save(workout)
            let record = FitnessWorkoutRecord(savedAt: .now, workoutID: workoutID)
            fitnessRecords[id] = record
            remember(record, forSession: id)
            fitnessSave = FitnessSaveReport(sessionID: id, status: .saved)
        } catch FitnessSaveError.notAuthorized {
            fitnessAccess = .denied
            reportFitnessSave(.needsPermission, for: id)
        } catch FitnessSaveError.unavailable {
            fitnessAccess = .unavailable
            reportFitnessSave(.unavailable, for: id)
        } catch {
            reportFitnessSave(.failed, for: id)
        }
    }

    /// Shows how a save ended, unless it did not go through for a session deleted meanwhile.
    private func reportFitnessSave(_ status: FitnessSaveStatus, for id: UUID) {
        guard fitnessSavesOfDeletedSessions.contains(id) else {
            fitnessSave = FitnessSaveReport(sessionID: id, status: status)
            return
        }
        if fitnessSave?.sessionID == id { fitnessSave = nil }
    }

    /// A deleted session's Fitness line goes with it: a failed or refused save has nothing left to
    /// retry, and Try again did nothing. A save still running finishes in Health (the delete dialog
    /// says so), and reports nothing if it fails.
    private func forgetFitnessSaves(where isDeleted: (UUID) -> Bool) {
        fitnessSavesOfDeletedSessions.formUnion(fitnessSavesInFlight.filter(isDeleted))
        if let save = fitnessSave, isDeleted(save.sessionID), save.status != .saving, save.status != .saved {
            fitnessSave = nil
        }
    }

    /// Writes the saved workout into the session's history entry, unless it was deleted meanwhile.
    private func remember(_ record: FitnessWorkoutRecord, forSession id: UUID) {
        if currentSession?.id == id { currentSession?.fitnessWorkout = record }
        guard store != nil, !pendingDeleteAll, !pendingDeleteIDs.contains(id),
              var session = pendingSessions[id] ?? history.first(where: { $0.id == id }) else { return }
        session.fitnessWorkout = record
        save(session)
    }

    func deleteHistory(id: UUID) {
        guard store != nil else { return }
        pendingSessions.removeValue(forKey: id)
        forgetFitnessSaves { $0 == id }
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
        forgetFitnessSaves { _ in true }
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
                        issues: [SetIssue], partlyVisible: Bool = false) {
        guard case .usable(let side) = EvidenceGate.assess(
            frames, requirement: exercise.definition.evidence, allowsPartial: partlyVisible) else { return }
        let now = currentDate()
        // A set long after the previous one starts a new session; the earlier one ends as at Done.
        if var open = currentSession, !open.continues(at: now) {
            currentSession = nil
            open.isOpen = nil
            save(open)
            Task { await self.saveToFitness(open) }
        }
        var session = currentSession ?? WorkoutSessionSummary(id: UUID(), startedAt: now, sets: [])
        session.isOpen = true
        let newSet = SetSummary(
            id: UUID(), sessionID: session.id, capturedAt: now,
            bodySide: side, analysis: analysis, cue: cue, cueResponse: .unanswered,
            exercise: exercise, issues: issues, partlyVisible: partlyVisible ? true : nil
        )
        // The latest earlier set of the exercise that can be compared (not only the very last one).
        let earlier = session.sets.filter { $0.exercise == exercise }.reversed()
        session.sets.append(newSet)
        currentSession = session
        comparisonRecap = nil
        // A partly visible set has reps but too few clear frames to compare ranges with.
        comparison = partlyVisible ? nil
            : earlier.lazy.filter { $0.partlyVisible != true }.compactMap { SetComparison.compare($0, newSet) }.first
        save(session)
    }

    /// Why a measured set has no comparison even though the session has earlier sets.
    var comparisonGap: ComparisonGap? {
        guard comparison == nil, let session = currentSession, session.sets.count >= 2,
              let latest = session.sets.last else { return nil }
        let earlier = session.sets.dropLast().filter { $0.exercise == latest.exercise }
        guard !earlier.isEmpty else { return .differentExercise }
        if latest.partlyVisible == true { return .partlyVisible }
        if latest.analysis.reps.count < SetComparison.minimumReps
            || earlier.allSatisfy({ $0.analysis.reps.count < SetComparison.minimumReps }) {
            return .tooFewReps
        }
        if earlier.allSatisfy({ $0.bodySide != latest.bodySide }) { return .differentSide }
        return .incompatibleSets
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
        // The usual case, history in good order and nothing else waiting: write this session (the
        // store merges it into the file) and update the list in memory, instead of reading the
        // whole history twice more on the main actor after every set.
        if historyIssue == nil, pendingSessions.isEmpty, pendingDeleteIDs.isEmpty, !pendingDeleteAll {
            do {
                try store.save(session)
            } catch {
                pendingSessions[session.id] = session
                historyIssue = Self.issue(for: error)
                return
            }
            if let index = history.firstIndex(where: { $0.id == session.id }) {
                history[index] = session
            } else {
                history.append(session)
                history.sort { $0.startedAt > $1.startedAt }
            }
            return
        }
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
        previewEstimates = []
        lastPreviewFrameAt = nil
        livePose = nil
        athleteInView = false
        framingStatus = .checking
        frameCount = 0
        captureStartedAt = nil
        result = nil
        movementNote = nil
        repExtremes = nil
        repeatedPattern = nil
        formNotes = []
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
