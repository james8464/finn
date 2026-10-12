import Foundation
import Testing
@testable import Plumb

/// A standing person drawn as six joints, `height` tall (normalized), centred at `x`.
private func person(x: Double, top: Double = 0.3, height: Double = 0.6,
                    confidence: Double = 0.9) -> [BodyJoint: JointPoint] {
    let hip = top + height * 0.5
    let knee = top + height * 0.75
    let ankle = top + height
    return [
        .leftShoulder: JointPoint(x: x - 0.02, y: top, confidence: confidence),
        .leftHip: JointPoint(x: x - 0.02, y: hip, confidence: confidence),
        .leftKnee: JointPoint(x: x, y: knee, confidence: confidence),
        .leftAnkle: JointPoint(x: x + 0.02, y: ankle, confidence: confidence),
        .rightHip: JointPoint(x: x + 0.02, y: hip, confidence: confidence),
        .rightAnkle: JointPoint(x: x + 0.04, y: ankle, confidence: confidence),
    ]
}

struct AthleteTrackerTests {
    @Test func picksTheLargePersonNearTheCentre() {
        var tracker = AthleteTracker()
        let small = person(x: 0.15, top: 0.4, height: 0.3)
        let athlete = person(x: 0.5)
        #expect(tracker.select([small, athlete], aspectRatio: 16.0 / 9, time: 0) == 1)
    }

    @Test func followsTheAthleteWhileSomeoneWalksAcross() {
        var tracker = AthleteTracker()
        #expect(tracker.select([person(x: 0.5)], aspectRatio: 16.0 / 9, time: 0) == 0)
        tracker.lock()
        // A slightly larger passer-by walks from the left edge to the right edge behind the athlete.
        for step in 0...20 {
            let walker = person(x: 0.05 + 0.045 * Double(step), top: 0.25, height: 0.62)
            let order = step.isMultiple(of: 2) ? [walker, person(x: 0.5)] : [person(x: 0.5), walker]
            let picked = tracker.select(order, aspectRatio: 16.0 / 9, time: 0.1 * Double(step + 1))
            if let picked {
                // Whenever the tracker answers, it is the athlete, never the walker.
                #expect(abs((order[picked][.leftKnee]?.x ?? 0) - 0.5) < 0.001, "step \(step)")
            }
        }
        // Once the walker has left, the athlete is found again.
        #expect(tracker.select([person(x: 0.5)], aspectRatio: 16.0 / 9, time: 3) == 0)
    }

    @Test func lockedTrackerWaitsForTheAthleteInsteadOfJumping() {
        var tracker = AthleteTracker()
        _ = tracker.select([person(x: 0.5)], aspectRatio: 1, time: 0)
        tracker.lock()
        // The athlete is hidden; only someone across the room is visible, for five seconds.
        for tenth in 1...50 {
            #expect(tracker.select([person(x: 0.15)], aspectRatio: 1, time: Double(tenth) / 10) == nil)
        }
        #expect(tracker.select([person(x: 0.15), person(x: 0.51)], aspectRatio: 1, time: 5.1) == 1)
    }

    @Test func beforeASetAClearlyMoreProminentPersonTakesOver() {
        var tracker = AthleteTracker()
        let early = person(x: 0.25, top: 0.45, height: 0.3)
        #expect(tracker.select([early], aspectRatio: 1, time: 0) == 0)
        // The athlete steps into the middle, much larger than the first person.
        #expect(tracker.select([early, person(x: 0.5, top: 0.2, height: 0.7)], aspectRatio: 1, time: 0.1) == 1)
    }

    @Test func twoPeopleInTheSameSpotGiveNoAnswer() {
        var tracker = AthleteTracker()
        _ = tracker.select([person(x: 0.5)], aspectRatio: 1, time: 0)
        tracker.lock()
        #expect(tracker.select([person(x: 0.49), person(x: 0.51)], aspectRatio: 1, time: 0.1) == nil)
    }

    @Test func aFewUnclearJointsAreNotAPerson() {
        var tracker = AthleteTracker()
        let blur = person(x: 0.5, confidence: 0.05)
        #expect(tracker.select([blur], aspectRatio: 1, time: 0) == nil)
    }
}

struct TrackedSetEvidenceTests {
    /// A tracked 10-rep squat with a bystander in every frame, and the athlete hidden by them
    /// between `hiddenFrom` and `hiddenTo` seconds.
    private func trackedSquat(hiddenFrom: Double = .infinity, hiddenTo: Double = .infinity,
                              bystanders: Bool = true) -> [PoseFrame] {
        (0...300).map { index -> PoseFrame in
            let time = Double(index) / 15
            let hipY = 0.42 + 0.2 * (1 - cos(2 * .pi * time / 2)) / 2
            let athlete = squatFrame(time: time, hipY: hipY)
            let others = bystanders ? [person(x: 0.15 + 0.03 * time.truncatingRemainder(dividingBy: 10))] : []
            if time >= hiddenFrom && time < hiddenTo {
                return PoseFrame(time: time, subjectCount: others.count, joints: [:],
                                 athleteTracking: .hidden, bystanders: others)
            }
            return PoseFrame(time: time, subjectCount: 1 + others.count, joints: athlete.joints,
                             athleteTracking: .tracked, bystanders: others)
        }
    }

    @Test func otherPeopleInViewNoLongerRefuseATrackedSet() throws {
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(trackedSquat()) else {
            Issue.record("A tracked set with a bystander must be measured")
            return
        }
        #expect(analysis.reps.count == 10)
        #expect(analysis.rubricVersion == "squat-side-v4")
    }

    @Test func someoneWalkingInFrontForTwoSecondsIsBridged() {
        // Hidden from 4.5 s to 6.5 s: across the bottom of one rep and the next.
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(trackedSquat(hiddenFrom: 4.5, hiddenTo: 6.5)) else {
            Issue.record("A two-second occlusion must not cancel the set")
            return
        }
        // No rep is invented while the athlete is hidden; at most the one cut by the gap is lost.
        #expect((9...10).contains(analysis.reps.count), "counted \(analysis.reps.count)")
    }

    @Test func aLongOcclusionIsRefusedWithAClearReason() {
        guard case .insufficientView(let reason) = SquatAnalyzer.analyze(trackedSquat(hiddenFrom: 8, hiddenTo: 12)) else {
            Issue.record("Four seconds without the athlete must be refused")
            return
        }
        // Last seen at frame 119 (7.93 s), seen again at frame 180 (12.0 s).
        #expect(reason.hasPrefix("Someone else was in view and Plumb lost you for 4.1 s, starting 7.9 s into the set."))
    }

    @Test func losingTheAthleteWithNobodyElseKeepsTheShortLimit() {
        let frames = trackedSquat(hiddenFrom: 8, hiddenTo: 9.2, bystanders: false)
        guard case .insufficientView(let reason) = SquatAnalyzer.analyze(frames) else {
            Issue.record("1.2 s without anyone in view must still be refused")
            return
        }
        #expect(reason.hasPrefix("Tracking was lost during the set."))
    }

    @Test func untrackedFramesKeepTheSinglePersonRule() {
        let crowded = trackedSquat().map {
            PoseFrame(time: $0.time, subjectCount: 2, joints: $0.joints)
        }
        #expect(EvidenceGate.assess(crowded) == .reject(.multiplePeople))
    }

    @Test func previewCountsTrackedFramesWithOthersAround() {
        #expect(EvidenceGate.previewStatus(Array(trackedSquat().prefix(6))) == .landmarksVisible)
    }

    @Test func bystandersAreDrawnGreyAndNamedInTheSummary() {
        let frame = trackedSquat()[3]
        let geometry = SkeletonGeometry(frame: frame, exercise: .squat,
                                        size: CGSize(width: 390, height: 844), mirrored: false)
        #expect(!geometry.bystanderBones.isEmpty)
        #expect(geometry.summary.hasSuffix("other people ignored"))
    }
}
