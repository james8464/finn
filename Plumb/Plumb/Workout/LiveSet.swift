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
    /// The count changed without a new rep to say: the analysis of the whole set so far gave fewer
    /// reps than said (a movement that no longer counts once the set's top settled), or reached
    /// again a number already said. Shown, never spoken.
    case repCountRevised(Int)
    /// This rep took clearly less time than the person's first reps.
    case fasterThanFirstReps(rep: Int)
    /// This rep's range was clearly shorter than the person's first reps.
    case shorterThanFirstReps(rep: Int)
    /// A form check (`FormCheck`) found its fault again on this rep: at least two reps so far.
    case formFault(FormCheck, rep: Int)

    /// A few words to say aloud, short enough to hear mid-rep: an order ("Go lower", "Slow down"),
    /// never a reading, so the athlete knows what to change without thinking.
    func spoken(for definition: ExerciseDefinition) -> String {
        switch self {
        case .repCounted(let count): "\(count)"
        case .repCountRevised: ""
        case .fasterThanFirstReps: String(localized: "Slow down")
        case .shorterThanFirstReps: definition.copy.liveShorterCue
        case .formFault(let check, _): check.liveCue
        }
    }

    /// What to say for one live update: the latest count, then any observation, as one phrase
    /// ("4. Range is shorter"). Queued as separate phrases, a count and two observations made the
    /// announcer drop its backlog when it fell behind, count included.
    static func phrase(for events: [LiveSetEvent], definition: ExerciseDefinition) -> String? {
        var count: String?
        var observations: [String] = []
        for event in events {
            switch event {
            case .repCounted: count = event.spoken(for: definition)
            case .repCountRevised: break
            default: observations.append(event.spoken(for: definition))
            }
        }
        let parts = (count.map { [$0] } ?? []) + observations
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// The line shown on the camera screen, large enough to read from a few steps away: the same
    /// few words that are said.
    func caption(for definition: ExerciseDefinition) -> String? {
        switch self {
        case .repCounted, .repCountRevised: nil
        case .fasterThanFirstReps, .shorterThanFirstReps, .formFault: spoken(for: definition)
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
    /// The reps of the latest accepted analysis of the set so far: what the result would say if the
    /// set ended now. It can go down (see `update`).
    private(set) var countedReps = 0
    /// The highest count said aloud so far, so a number is never announced twice.
    private var highestSaid = 0
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
    /// The latest analysis, its frames and what it noticed, for the form checks.
    private var latestAnalysis: SetAnalysis?
    private var latestFrames: [PoseFrame] = []
    private var latestDiagnostics: MovementDiagnostics?
    /// The rep each form fault was last pointed out on.
    private var lastFormCue: [FormCheck: Int] = [:]
    /// The latest analysis saw the person from the side, with the set's joints clear: the range cue
    /// can be trusted. Filmed at an angle, a 2D range is bent like every other 2D angle, and the
    /// result says it gives no form advice; the live cue must not say otherwise (15 October: "Elbow
    /// bend is smaller" during front-on push-ups, then "no form advice for this set").
    private var rangeAdviceFromSide = true
    /// Only praise consistency when the latest accepted view supports a side-on range comparison.
    var supportsRangeCoaching: Bool { analysisAccepted && rangeAdviceFromSide }

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
            latestAnalysis = analysis
            latestFrames = set
            latestDiagnostics = diagnostics
            rangeAdviceFromSide = diagnostics?.partialVisibility == nil && diagnostics?.countedFromShoulders != true
                && Self.seenFromTheSide(set)
            // The count is the analysis of the whole set so far, the same the result makes at the
            // end. Measured over a longer set, a movement said as a rep can stop counting (on
            // 15 October, fast push-ups: the top the set is measured from settled lower as the set
            // went on, and reps measured from it became too fast or too shallow). The count used
            // to keep every rep ever said: it reached 29 and froze there while the result gave 18.
            // Now it follows the analysis, down as well as up, and a number already said is shown
            // again without being spoken.
            if reps.count < countedReps {
                countedReps = reps.count
                events.append(.repCountRevised(countedReps))
            }
            while countedReps < reps.count {
                countedReps += 1
                if countedReps > highestSaid {
                    highestSaid = countedReps
                    events.append(.repCounted(countedReps))
                    events.append(contentsOf: cues(forRep: countedReps))
                } else {
                    events.append(.repCountRevised(countedReps))
                }
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
        if let fault = formFault(onRep: number) {
            lastFormCue[fault] = number
            return [.formFault(fault, rep: number)]
        }
        var faster = false
        if number >= 4 {
            let first = reps.prefix(3).map(\.duration).sorted()[1]
            faster = first > 0 && rep.duration < Self.fasterShare * first
        }
        if faster { sawFasterRep = true }
        if rangeAdviceFromSide, number >= 3, number - lastShorterCue >= Self.cueSpacing {
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

nonisolated extension LiveSetMonitor {
    /// The same camera-angle reading as the form checks: side-on, or no 3D estimate to say otherwise.
    fileprivate static func seenFromTheSide(_ frames: [PoseFrame]) -> Bool {
        switch ViewCheck.assess(frames, expected: .side) {
        case .matches, .unavailable: true
        case .angled, .mismatch: false
        }
    }

    /// The first form fault, in advice order, that this rep shows and that has shown on at least
    /// `FormCheck.minimumFaultyReps` reps so far, not pointed out in the last `cueSpacing` reps. The
    /// same checks as the result, on the set so far, and silent for a partly visible set, a push-up
    /// counted from the shoulders, or a person filmed at an angle.
    fileprivate func formFault(onRep number: Int) -> FormCheck? {
        guard let analysis = latestAnalysis, latestDiagnostics?.partialVisibility == nil,
              latestDiagnostics?.countedFromShoulders != true else { return nil }
        let analysisSoFar = SetAnalysis(reps: Array(analysis.reps.prefix(number)), confidence: analysis.confidence,
                                        rubricVersion: analysis.rubricVersion)
        let review = FormChecks.review(analysisSoFar, frames: latestFrames, definition: definition)
        return review.findings.first { finding in
            finding.reps.contains(number) && number - (lastFormCue[finding.check] ?? Int.min / 2) >= Self.cueSpacing
        }?.check
    }
}

/// Says live set events aloud: through AirPods or other headphones when connected, otherwise the
/// iPhone speaker. Tests record the phrases instead.
@MainActor
protocol LiveAnnouncing: AnyObject {
    func announce(_ text: String)
}
