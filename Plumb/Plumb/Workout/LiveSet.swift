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
        // Once a side is followed, a frame where it is unclear is a miss, not a switch to the far
        // side, which restarted the hold. Before that, the side seen with more confidence is tried
        // first, and each side is checked for the starting position, not only for visibility.
        let sides = side.map { [$0] } ?? Self.sidesByConfidence(frame, requirement: requirement)
        guard let visibleSide = sides.first(where: {
                  SetWindow.visible(frame, requirement: requirement, side: $0)
                      && Self.isStartingPosture(frame, definition: definition, side: $0)
              }),
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

    /// Both sides, the one whose required joints Vision is more confident about first: the side
    /// facing the camera, whichever way the person stands.
    static func sidesByConfidence(_ frame: PoseFrame, requirement: EvidenceRequirement) -> [BodySide] {
        func confidence(_ side: BodySide) -> Double {
            requirement.joints(on: side).reduce(0) { $0 + (frame.joints[$1]?.confidence ?? 0) }
        }
        return confidence(.right) > confidence(.left) ? [.right, .left] : [.left, .right]
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

    /// What to say for one live update: the latest count, then any observation, as one phrase
    /// ("4. Range is shorter"). Queued as separate phrases, a count and two observations made the
    /// announcer drop its backlog when it fell behind, count included.
    static func phrase(for events: [LiveSetEvent], definition: ExerciseDefinition) -> String? {
        var count: String?
        var observations: [String] = []
        for event in events {
            if case .repCounted = event {
                count = event.spoken(for: definition)
            } else {
                observations.append(event.spoken(for: definition))
            }
        }
        let parts = (count.map { [$0] } ?? []) + observations
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
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
    /// Away from the spot this long means the athlete walked away. Before any rep, this counts only
    /// once the athlete has been at their spot for a set's minimum length.
    static let leftAfter: TimeInterval = 2.0
    /// After at least one rep, unseen this long (without being seen walking off) means the athlete left.
    static let hiddenAfter = EvidenceRubric.maximumOcclusionGap + 1
    /// After at least one rep, no new rep for this long (or the exercise's longest rep plus 2 s, if
    /// longer) while the person is at the top means the set is over.
    static let idleAfter: TimeInterval = 8.0

    let definition: ExerciseDefinition
    private(set) var reps: [RepMetric] = []
    private(set) var countedReps = 0
    /// The set looks over (see `shouldStop`), as of the latest analysis.
    private(set) var isOver = false
    /// A rep was clearly faster than the first reps at least once.
    private(set) var sawFasterRep = false
    /// The latest analysis measured the set so far. Right after a gap it may refuse it for a while
    /// (coverage under 80%); reps done then are counted once it measures again.
    private var analysisAccepted = false
    /// The latest analysis ended partway through a movement: a slow rep is under way, not idleness.
    private var midMovement = false
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
        analysisAccepted = false
        // One pass gives both the set's frames and where the athlete is in each, for the count and
        // the stop; this runs over the whole set so far every 0.4 s.
        let layout = SetWindow.layout(frames, requirement: definition.evidence)
        let set = layout.range.map { Array(frames[$0]) } ?? frames
        let (outcome, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(set, as: definition, viewCheck: .ignore,
                                                                             trimsToSet: false)
        if case .analyzed(let analysis) = outcome {
            analysisAccepted = true
            midMovement = diagnostics?.unfinished ?? false
            reps = analysis.reps
            // A later analysis can merge or split a rep at the set's edge; the count never goes back.
            while countedReps < reps.count {
                countedReps += 1
                events.append(.repCounted(countedReps))
                events.append(contentsOf: cues(forRep: countedReps))
            }
        }
        isOver = shouldStop(frames, spots: layout.spots)
        return events
    }

    /// True when the set should end by itself.
    func shouldStop(_ frames: [PoseFrame]) -> Bool {
        shouldStop(frames, spots: SetWindow.spots(frames, requirement: definition.evidence))
    }

    /// `spots` is `SetWindow.spots(frames, ...)`, worked out only when needed.
    private func shouldStop(_ frames: [PoseFrame], spots makeSpots: @autoclosure () -> [SetWindow.Spot]?) -> Bool {
        guard let last = frames.last else { return false }
        // Idle only by a measurement that accepts the set and sees the person at the top, for longer
        // than the slowest rep may take: a refusal after a gap, or a slow rep under way, is not idleness.
        let idleLimit = max(Self.idleAfter, definition.phases.maximumDuration + 2)
        if countedReps > 0, analysisAccepted, !midMovement, let lastRep = reps.last,
           last.time - lastRep.endTime >= idleLimit {
            return true
        }
        // Away from the spot, not merely with a joint unclear at it (`SetWindow.spots`).
        guard let spots = makeSpots() else { return false }
        guard let lastIndex = spots.lastIndex(where: \.isAtSpot) else { return countedReps > 0 }
        let gone = last.time - frames[lastIndex].time
        // Seen walking off: two seconds. Only hidden (someone in front, Vision missing them): longer
        // than the gap the evidence gate allows for a person passing in front, so it does not end a
        // set the gate would measure.
        let seenLeaving = spots[(lastIndex + 1)...].contains(.away)
        guard countedReps > 0 else {
            // No rep counted (every movement too shallow, or the person changed their mind): the set
            // still ends when the athlete, after standing at their spot for a set's minimum length,
            // is seen walking away. Never for being unseen, which getting down into a push-up can
            // cause, and never while walking in and out without stopping at the spot.
            guard seenLeaving, let firstIndex = spots.firstIndex(of: .inPosition),
                  frames[lastIndex].time - frames[firstIndex].time >= EvidenceRubric.minimumSetDuration
            else { return false }
            return gone >= Self.leftAfter
        }
        return gone >= (seenLeaving ? Self.leftAfter : Self.hiddenAfter)
    }

    /// At most one observation per rep, said with its count. A shorter range comes first, the same
    /// reading as the end-of-set observation; a quicker rep not pointed out then is pointed out on
    /// the next one if it is still quicker.
    private mutating func cues(forRep number: Int) -> [LiveSetEvent] {
        guard reps.indices.contains(number - 1) else { return [] }
        let rep = reps[number - 1]
        var faster = false
        if number >= 4 {
            let first = reps.prefix(3).map(\.duration).sorted()[1]
            faster = first > 0 && rep.duration < Self.fasterShare * first
        }
        if faster { sawFasterRep = true }
        if number >= 3, number - lastShorterCue >= Self.cueSpacing {
            let first = (reps[0].relativeRange + reps[1].relativeRange) / 2
            if first > 0, rep.relativeRange <= Self.shorterShare * first {
                lastShorterCue = number
                return [.shorterThanFirstReps(rep: number)]
            }
        }
        if faster, number - lastFasterCue >= Self.cueSpacing {
            lastFasterCue = number
            return [.fasterThanFirstReps(rep: number)]
        }
        return []
    }
}

/// Says live set events aloud: through AirPods or other headphones when connected, otherwise the
/// iPhone speaker. Tests record the phrases instead.
@MainActor
protocol LiveAnnouncing: AnyObject {
    func announce(_ text: String)
}
