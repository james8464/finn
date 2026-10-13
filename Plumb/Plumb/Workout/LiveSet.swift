import Foundation

/// Hands-free start: the athlete has stood in position, still, for `hold` seconds. On a real phone
/// propped a few steps away nobody can tap Start from their spot, so the set starts by itself.
nonisolated struct StartReadiness: Equatable {
    /// How long the athlete holds still in position before the countdown starts.
    static let hold: TimeInterval = 1.5
    /// How far the planted joint may move while holding still, as a share of the frame.
    static let stillRadius = 0.04
    /// Frames in a row Vision may miss a joint without restarting the hold.
    static let toleratedMisses = 3

    private var since: TimeInterval?
    private var anchorX = 0.0
    private var anchorY = 0.0
    private var side: BodySide?
    private var misses = 0
    /// From 0 when not in position to 1 when the set can start.
    private(set) var progress = 0.0

    var isReady: Bool { progress >= 1 }

    mutating func reset() { self = StartReadiness() }

    /// Takes the next framing frame and returns the updated progress.
    @discardableResult
    mutating func update(with frame: PoseFrame, definition: ExerciseDefinition) -> Double {
        let requirement = definition.evidence
        let sides: [BodySide] = side.map { $0 == .left ? [.left, .right] : [.right, .left] } ?? [.left, .right]
        guard let visibleSide = sides.first(where: { SetWindow.visible(frame, requirement: requirement, side: $0) }),
              Self.isStartingPosture(frame, definition: definition, side: visibleSide),
              let anchor = frame.joints[requirement.anchor.joint(on: visibleSide)] else {
            misses += 1
            if misses > Self.toleratedMisses {
                since = nil
                side = nil
                progress = 0
            }
            return progress
        }
        misses = 0
        if let since, visibleSide == side,
           abs(anchor.x - anchorX) <= Self.stillRadius, abs(anchor.y - anchorY) <= Self.stillRadius {
            progress = min(1, max(0, (frame.time - since) / Self.hold))
        } else {
            since = frame.time
            anchorX = anchor.x
            anchorY = anchor.y
            side = visibleSide
            progress = 0
        }
        return progress
    }

    /// The exercise's starting position. Standing for the squat, lunge and deadlift. For the
    /// push-up, a plank: the torso closer to horizontal than vertical and the hands below the
    /// shoulders. A person standing with their arms down shows the same shoulder, elbow and wrist,
    /// and must not start a push-up set.
    static func isStartingPosture(_ frame: PoseFrame, definition: ExerciseDefinition, side: BodySide) -> Bool {
        guard definition.kind == .pushUp else { return true }
        func clear(_ role: JointRole) -> JointPoint? {
            guard let point = frame.joints[role.joint(on: side)],
                  point.confidence >= EvidenceRubric.minimumJointConfidence else { return nil }
            return point
        }
        guard let shoulder = clear(.shoulder), let hip = clear(.hip), let wrist = clear(.wrist) else { return false }
        let horizontal = abs(shoulder.x - hip.x)
        let vertical = abs(shoulder.y - hip.y) * frame.aspectRatio
        return horizontal > vertical && wrist.y > shoulder.y
    }
}

/// What Plumb says or shows while a set is running. Every event is measured on this set and
/// compared with the person's own first reps, never with a universal target.
nonisolated enum LiveSetEvent: Equatable, Sendable {
    /// A rep was counted; the total so far.
    case repCounted(Int)
    /// This rep took clearly less time than the person's first reps.
    case fasterThanFirstReps(rep: Int)
    /// This rep's range was clearly shorter than the person's first reps.
    case shorterThanFirstReps(rep: Int)

    /// A few words to say aloud, short enough to hear mid-rep.
    func spoken(for definition: ExerciseDefinition) -> String {
        switch self {
        case .repCounted(let count): "\(count)"
        case .fasterThanFirstReps: "Faster than your first reps"
        case .shorterThanFirstReps: definition.copy.liveShorterCue
        }
    }

    /// The line shown on the camera screen.
    func caption(for definition: ExerciseDefinition) -> String? {
        switch self {
        case .repCounted: nil
        case .fasterThanFirstReps(let rep): "Rep \(rep) was faster than your first reps"
        case .shorterThanFirstReps(let rep): "Rep \(rep): \(definition.copy.rangeNoun) shorter than your first reps"
        }
    }
}

/// Follows a set while it runs: counts reps with the same analysis as the result, notices when a
/// rep is clearly faster or shorter than the person's own first reps, and tells when the set is
/// over (the athlete walked away, or stopped moving after their reps).
nonisolated struct LiveSetMonitor {
    /// Seconds of frames between two analyses; a rep takes about a second or more.
    static let analysisInterval: TimeInterval = 0.4
    /// A rep this much shorter in time than the median of the first three is "faster".
    static let fasterShare = 0.7
    /// A rep with this share or less of the first two reps' range is "shorter", the same 85% as the
    /// end-of-set observation (`CueSelector`).
    static let shorterShare = 0.85
    /// The same cue is not repeated within this many reps.
    static let cueSpacing = 3
    /// After at least one rep, away from the spot this long means the athlete walked away.
    static let leftAfter: TimeInterval = 2.0
    /// After at least one rep, no new rep for this long means the set is over.
    static let idleAfter: TimeInterval = 8.0

    let definition: ExerciseDefinition
    private(set) var reps: [RepMetric] = []
    private(set) var countedReps = 0
    /// The set looks over (see `shouldStop`), as of the latest analysis.
    private(set) var isOver = false
    private var lastAnalysisTime = -Double.infinity
    private var lastFasterCue = Int.min / 2
    private var lastShorterCue = Int.min / 2

    init(definition: ExerciseDefinition) {
        self.definition = definition
    }

    /// Takes every frame of the set so far and returns what happened since the last call. The
    /// analysis runs every `analysisInterval` seconds of frames, not on every frame.
    mutating func update(with frames: [PoseFrame]) -> [LiveSetEvent] {
        guard let last = frames.last, last.time - lastAnalysisTime >= Self.analysisInterval else { return [] }
        lastAnalysisTime = last.time
        var events: [LiveSetEvent] = []
        if case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: definition, viewCheck: .ignore) {
            reps = analysis.reps
            // A later analysis can merge or split a rep at the set's edge; the count never goes back.
            while countedReps < reps.count {
                countedReps += 1
                events.append(.repCounted(countedReps))
                events.append(contentsOf: cues(forRep: countedReps))
            }
        }
        isOver = shouldStop(frames)
        return events
    }

    /// True when the set should end by itself.
    func shouldStop(_ frames: [PoseFrame]) -> Bool {
        guard countedReps > 0, let last = frames.last else { return false }
        if let lastRep = reps.last, last.time - lastRep.endTime >= Self.idleAfter { return true }
        // Away from the spot, not merely with a joint unclear at it (`SetWindow.presence`).
        guard let present = SetWindow.presence(frames, requirement: definition.evidence) else { return false }
        guard let lastIndex = present.lastIndex(of: true) else { return true }
        return last.time - frames[lastIndex].time >= Self.leftAfter
    }

    private mutating func cues(forRep number: Int) -> [LiveSetEvent] {
        guard reps.indices.contains(number - 1) else { return [] }
        let rep = reps[number - 1]
        var events: [LiveSetEvent] = []
        if number >= 4, number - lastFasterCue >= Self.cueSpacing {
            let first = reps.prefix(3).map(\.duration).sorted()[1]
            if first > 0, rep.duration < Self.fasterShare * first {
                events.append(.fasterThanFirstReps(rep: number))
                lastFasterCue = number
            }
        }
        if number >= 3, number - lastShorterCue >= Self.cueSpacing {
            let first = (reps[0].relativeRange + reps[1].relativeRange) / 2
            if first > 0, rep.relativeRange <= Self.shorterShare * first {
                events.append(.shorterThanFirstReps(rep: number))
                lastShorterCue = number
            }
        }
        return events
    }
}

/// Says live set events aloud: through AirPods or other headphones when connected, otherwise the
/// iPhone speaker. Tests record the phrases instead.
@MainActor
protocol LiveAnnouncing: AnyObject {
    func announce(_ text: String)
}
