import Foundation

/// Evidence rules shared by every exercise. They describe tracking quality, not technique.
/// Version 3 of the squat rubric loosened them after real side-view videos showed Vision
/// reporting hips at about 0.5 confidence: the 0.6 floor of version 2 refused every real set.
/// Version 4 follows one athlete: other people no longer refuse a set, and a gap while someone
/// else is in view (usually walking between the athlete and the phone) may last longer.
nonisolated enum EvidenceRubric {
    static let minimumJointConfidence = 0.3
    static let maximumTrackingGap = 0.75
    /// A gap in the athlete's tracking while other people are in view.
    static let maximumOcclusionGap = 3.0
    /// Only for frames that do not follow one athlete (`PoseFrame.athleteTracking == nil`).
    static let maximumBystanderDuration = 0.35
    static let minimumCoverage = 0.8
    /// Between this and `minimumCoverage`, a set is partly visible: Finn counts the reps whose own
    /// frames show the joints clearly, and gives no advice (13 October: a 79% set lost all its reps).
    static let partialCoverage = 0.65
    /// Spread between the 10th and 90th percentile of the still joint's position, so one
    /// misplaced detection does not count as the phone moving.
    static let maximumAnchorMovement = 0.10
    static let minimumSetDuration: TimeInterval = 2
}

nonisolated enum EvidenceGate {
    static func previewStatus(_ frames: [PoseFrame],
                              requirement: EvidenceRequirement = .squat) -> FramingStatus {
        guard frames.count >= 5 else { return .checking }
        let sides: [[BodyJoint]] = [requirement.joints(on: .left), requirement.joints(on: .right)]
        let visible = sides.contains { joints in
            frames.filter { frame in
                frame.athleteVisible && joints.allSatisfy { joint in
                    (frame.joints[joint]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
                }
            }.count >= 4
        }
        return visible ? .landmarksVisible : .adjustPosition
    }

    /// Frames that follow one athlete ignore everyone else. Without that, nobody can tell whose
    /// joints these are, so another person in view refuses the set.
    static func isCrowded(_ frames: [PoseFrame]) -> Bool {
        guard !frames.contains(where: { $0.athleteTracking != nil }) else { return false }
        let bystanderFrames = frames.filter { $0.subjectCount > 1 }.count
        return Double(bystanderFrames) / Double(frames.count) > 0.2
            || longestBystanderRun(frames) >= EvidenceRubric.maximumBystanderDuration
    }

    /// `allowsPartial` lowers the joint coverage needed from `minimumCoverage` to `partialCoverage`;
    /// every other rule stays.
    static func assess(_ frames: [PoseFrame],
                       requirement: EvidenceRequirement = .squat,
                       allowsPartial: Bool = false) -> EvidenceAssessment {
        guard PoseFrame.hasIncreasingTimestamps(frames) else { return .reject(.trackingGap) }
        guard let first = frames.first, let last = frames.last,
              last.time - first.time >= EvidenceRubric.minimumSetDuration else {
            return .reject(.tooShort)
        }

        if isCrowded(frames) { return .reject(.multiplePeople) }

        let best = bestSide(frames, requirement: requirement)
        let total = Double(frames.count)
        let coverage = allowsPartial ? EvidenceRubric.partialCoverage : EvidenceRubric.minimumCoverage
        guard Double(best.complete) / total >= coverage else {
            return .reject(.missingJoints)
        }
        guard Double(best.confident) / total >= coverage else {
            return .reject(.lowConfidence)
        }
        if tooLongGap(frames, joints: best.joints) != nil {
            return .reject(.trackingGap)
        }
        guard anchorMovement(frames, requirement: requirement, side: best.side)
                <= EvidenceRubric.maximumAnchorMovement else {
            return .reject(.unstableFraming)
        }
        return .usable(best.side)
    }

    /// How visible a set refused only for joint coverage was, when it reached `partialCoverage` and
    /// passes every other rule. Nil for a fully visible set or one refused anyway.
    static func partialVisibility(_ frames: [PoseFrame],
                                  requirement: EvidenceRequirement = .squat) -> PartialVisibility? {
        guard case .reject(let reason) = assess(frames, requirement: requirement),
              reason == .missingJoints || reason == .lowConfidence,
              case .usable(let side) = assess(frames, requirement: requirement, allowsPartial: true) else {
            return nil
        }
        let best = bestSide(frames, requirement: requirement)
        let weakest = weakestJoint(frames, requirement: requirement, side: side)
// rounded down, like the refusal message, so 79.8% never reads as the 80% needed.
        return PartialVisibility(coverage: 100 * min(best.complete, best.confident) / max(1, frames.count),
                                 weakest: weakest.role, weakestShare: weakest.share)
    }

    /// Whether the required joints were clear in at least `partialCoverage` of the frames between
    /// `start` and `end`: the test for keeping one rep of a partly visible set. Vision usually loses
    /// a joint in scattered frames all through a set, so a rep needs the set's floor, not the 80%
    /// that advice needs; a rep hidden for most of its frames is left out.
    static func isClear(_ frames: [PoseFrame], requirement: EvidenceRequirement, side: BodySide,
                        from start: TimeInterval, to end: TimeInterval) -> Bool {
        let span = frames[ExerciseAnalyzer.frameRange(from: start, through: end, in: frames)]
        guard !span.isEmpty else { return false }
        let joints = requirement.joints(on: side)
        let clear = span.filter { frame in
            frame.athleteVisible && joints.allSatisfy {
                (frame.joints[$0]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
            }
        }.count
        return Double(clear) / Double(span.count) >= EvidenceRubric.partialCoverage
    }

    /// A sentence with numbers saying why `assess` refused the set, so the app never stays silent.
    static func explanation(for reason: EvidenceReason, frames: [PoseFrame],
                            requirement: EvidenceRequirement = .squat) -> String {
        let total = max(1, frames.count)
        let names = requirement.joints.map(\.rawValue)
        let jointList = names.count > 1
            ? names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
            : names.first ?? "body"
        switch reason {
        case .tooShort:
            let duration = (frames.last?.time ?? 0) - (frames.first?.time ?? 0)
            return String(format: "The set lasted %.1f s. Finn needs at least %.0f s of movement.",
                          duration, EvidenceRubric.minimumSetDuration)
        case .multiplePeople:
            return "Another person was in view. Keep only yourself in frame and try again."
        case .missingJoints, .lowConfidence:
            let best = bestSide(frames, requirement: requirement)
// round down so a rejected 79.8% set never appears to meet the 80% minimum.
            let share = 100 * (reason == .missingJoints ? best.complete : best.confident) / total
            let weakest = weakestJoint(frames, requirement: requirement, side: best.side)
            return "Finn saw your \(jointList) clearly in \(share)% of the set and needs \(Int(EvidenceRubric.minimumCoverage * 100))%. "
                + "Your \(weakest.role.rawValue) was hardest to see (\(weakest.share)% of frames). "
                + "Move the phone so your whole body is in view, with even light."
        case .trackingGap:
            let joints = bestSide(frames, requirement: requirement).joints
            let gap = tooLongGap(frames, joints: joints)
                ?? trackingGaps(frames, joints: joints).max { $0.duration < $1.duration }
                ?? TrackingGap(start: frames.first?.time ?? 0, duration: 0, occluded: false, missing: [])
            let start = gap.start - (frames.first?.time ?? 0)
            if gap.occluded {
                return String(format: "Someone else was in view and Finn lost you for %.1f s, starting %.1f s "
                              + "into the set. Finn ignores other people, but it has to see you: keep a clear "
                              + "line between you and the phone, then try again.", gap.duration, start)
            }
// name only the joints that were lost, in the exercise's order.
            let lostRoles = requirement.joints.filter { role in
                gap.missing.contains(role.joint(on: .left)) || gap.missing.contains(role.joint(on: .right))
            }
            let lostNames = lostRoles.map(\.rawValue)
            let lost = lostNames.isEmpty || lostNames.count == names.count ? jointList
                : lostNames.count > 1 ? lostNames.dropLast().joined(separator: ", ") + " and " + (lostNames.last ?? "")
                : lostNames[0]
            let advice = lostNames.isEmpty || lostNames.count == names.count
                ? "Keep your whole body visible and try again."
                : "Keep your \(lost) in view and in good light, then try again."
            return String(format: "Tracking was lost during the set. %@ "
                          + "Finn lost your %@ for %.1f s, starting %.1f s into the set.",
                          advice, lost, gap.duration, start)
        case .unstableFraming:
            let movement = anchorMovement(frames, requirement: requirement,
                                          side: bestSide(frames, requirement: requirement).side)
// no clear anchor joint at all gives an infinite movement, which has no percentage.
            let moved = movement.isFinite ? "moved \(Int((movement * 100).rounded()))% of the frame" : "was not seen"
            return "Your \(requirement.anchor.rawValue) \(moved) during the set "
                + "(the limit is \(Int(EvidenceRubric.maximumAnchorMovement * 100))%). Keep the phone still and your "
                + "\(requirement.anchor == .wrist ? "hands" : "feet") planted."
        }
    }

    /// The required joint that is least often clear in recent framing frames, when it is the
    /// reason the joints are not all visible: "Hip not clear" rather than "Show hip, knee and
    /// ankle". Nil when nobody is in view or every joint is clear often enough.
    static func unclearJoint(_ frames: [PoseFrame], requirement: EvidenceRequirement = .squat) -> JointRole? {
        let seen = frames.filter { $0.athleteVisible && !$0.joints.isEmpty }
        guard seen.count >= 3 else { return nil }
        let side = bestSide(seen, requirement: requirement).side
        let shares = requirement.joints.map { role -> (JointRole, Double) in
            let clear = seen.filter {
                ($0.joints[role.joint(on: side)]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
            }.count
            return (role, Double(clear) / Double(seen.count))
        }
        guard let weakest = shares.min(by: { $0.1 < $1.1 }), weakest.1 < EvidenceRubric.minimumCoverage else {
            return nil
        }
        return weakest.0
    }

    // MARK: Measurements

    private static func bestSide(_ frames: [PoseFrame], requirement: EvidenceRequirement)
        -> (side: BodySide, joints: [BodyJoint], complete: Int, confident: Int) {
        let sides: [(BodySide, [BodyJoint])] = [
            (.left, requirement.joints(on: .left)),
            (.right, requirement.joints(on: .right)),
        ]
        return sides.map { side, joints in
            let complete = frames.filter { frame in
                frame.athleteVisible && joints.allSatisfy { frame.joints[$0] != nil }
            }
            let confident = complete.filter { frame in
                joints.allSatisfy {
                    (frame.joints[$0]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
                }
            }
            return (side: side, joints: joints, complete: complete.count, confident: confident.count)
        }.sorted { $0.confident > $1.confident }[0]
    }

    private static func longestBystanderRun(_ frames: [PoseFrame]) -> TimeInterval {
        var longest = 0.0
        var start: TimeInterval?
        for frame in frames {
            if frame.subjectCount > 1 {
                let runStart = start ?? frame.time
                start = runStart
                longest = max(longest, frame.time - runStart)
            } else if frame.subjectCount == 1 {
                start = nil
            }
        }
        return longest
    }

    private struct TrackingGap {
        let start: TimeInterval
        let duration: TimeInterval
        /// Someone else stood in front of the athlete while they were missing.
        let occluded: Bool
        /// The required joints that were unclear during the gap.
        let missing: Set<BodyJoint>
        var limit: TimeInterval {
            occluded ? EvidenceRubric.maximumOcclusionGap : EvidenceRubric.maximumTrackingGap
        }
    }

    /// Stretches without the athlete's required joints, from the set's start to its end. A gap is
    /// occluded only when another person stands where the athlete was last seen: someone at the far
    /// side of the room does not excuse a long loss of the athlete.
    private static func trackingGaps(_ frames: [PoseFrame], joints: [BodyJoint]) -> [TrackingGap] {
        guard let first = frames.first, let last = frames.last else { return [] }
        var gaps: [TrackingGap] = []
        var lastTracked = first.time
        var occluded = false
        var missing: Set<BodyJoint> = []
        var athleteBox: (minX: Double, maxX: Double, minY: Double, maxY: Double)?
        for frame in frames {
            let unclear = joints.filter { joint in
                (frame.joints[joint]?.confidence ?? 0) < EvidenceRubric.minimumJointConfidence
            }
            if frame.athleteVisible && unclear.isEmpty {
                if frame.time > lastTracked {
                    gaps.append(TrackingGap(start: lastTracked, duration: frame.time - lastTracked,
                                            occluded: occluded, missing: missing))
                }
                lastTracked = frame.time
                occluded = false
                missing = []
// the whole body, not only the measured side's joints: a person in front covers more
                // than the line of the leg.
                let points = frame.joints.values.filter { $0.confidence >= AthleteTracker.jointConfidence }
                if let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                   let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() {
                    athleteBox = (minX, maxX, minY, maxY)
                }
            } else {
                missing.formUnion(frame.athleteVisible ? unclear : joints)
                if frame.athleteTracking != nil, let box = athleteBox,
                   (frame.bystanders ?? []).contains(where: { overlaps($0, box) }) {
                    occluded = true
                }
            }
        }
        if last.time > lastTracked {
            gaps.append(TrackingGap(start: lastTracked, duration: last.time - lastTracked,
                                    occluded: occluded, missing: missing))
        }
        return gaps
    }

    /// Someone's clear joints fall inside the athlete's box, widened on each side by a quarter of the
    /// athlete's size (a side-view body is a thin strip; a person in front is not centred on it).
    private static func overlaps(_ person: [BodyJoint: JointPoint],
                                 _ box: (minX: Double, maxX: Double, minY: Double, maxY: Double)) -> Bool {
        let margin = 0.25 * max(hypot(box.maxX - box.minX, box.maxY - box.minY), 0.05)
        let marginX = margin
        let marginY = margin
        return person.values.contains { point in
            point.confidence >= AthleteTracker.jointConfidence
                && point.x >= box.minX - marginX && point.x <= box.maxX + marginX
                && point.y >= box.minY - marginY && point.y <= box.maxY + marginY
        }
    }

    private static func tooLongGap(_ frames: [PoseFrame], joints: [BodyJoint]) -> TrackingGap? {
        trackingGaps(frames, joints: joints).first { $0.duration > $0.limit }
    }

    private static func anchorMovement(_ frames: [PoseFrame], requirement: EvidenceRequirement,
                                       side: BodySide) -> Double {
        let joint = requirement.anchor.joint(on: side)
        let points = frames.filter(\.athleteVisible).compactMap { $0.joints[joint] }
            .filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        guard !points.isEmpty else { return .infinity }
        return max(spread(points.map(\.x)), spread(points.map(\.y)))
    }

    private static func weakestJoint(_ frames: [PoseFrame], requirement: EvidenceRequirement,
                                     side: BodySide) -> (role: JointRole, share: Int) {
        let shares = requirement.joints.map { role -> (JointRole, Int) in
            let seen = frames.filter {
                $0.athleteVisible && ($0.joints[role.joint(on: side)]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
            }.count
            return (role, Int((100 * Double(seen) / Double(max(1, frames.count))).rounded()))
        }
        let weakest = shares.min { $0.1 < $1.1 } ?? (requirement.anchor, 0)
        return (weakest.0, weakest.1)
    }

    private static func spread(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[Int(Double(sorted.count - 1) * 0.9)] - sorted[Int(Double(sorted.count - 1) * 0.1)]
    }
}

/// A set whose required joints were clear in `partialCoverage` to `minimumCoverage` of its frames.
nonisolated struct PartialVisibility: Equatable, Sendable {
    /// Percent of the set's frames with every required joint clear, rounded down.
    let coverage: Int
    /// The joint least often clear, and the percent of frames where it was.
    let weakest: JointRole
    let weakestShare: Int
}
