import Foundation
import Testing
@testable import Plumb

/// A standing person drawn as six joints, `height` tall (normalized), centred at `x`.
nonisolated private func person(x: Double, top: Double = 0.3, height: Double = 0.6,
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

/// A side-view plank under where `person(x: 0.5)` stands.
nonisolated private let plank: [BodyJoint: JointPoint] = [
    .leftShoulder: JointPoint(x: 0.30, y: 0.72, confidence: 0.8),
    .leftElbow: JointPoint(x: 0.31, y: 0.80, confidence: 0.8),
    .leftWrist: JointPoint(x: 0.31, y: 0.88, confidence: 0.8),
    .leftHip: JointPoint(x: 0.55, y: 0.76, confidence: 0.8),
    .leftKnee: JointPoint(x: 0.68, y: 0.80, confidence: 0.8),
    .leftAnkle: JointPoint(x: 0.80, y: 0.86, confidence: 0.8),
]

nonisolated struct AthleteTrackerTests {
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

    /// Getting down into a push-up: Vision misses the athlete for 0.6 s and finds them again in a
    /// plank, far from where they stood. Alone in view and where they were, they are the athlete.
    @Test func lockedTrackerPicksUpTheAthleteAfterAPoseChange() {
        var tracker = AthleteTracker()
        let standing = person(x: 0.5, top: 0.3, height: 0.6)
        _ = tracker.select([standing], aspectRatio: 1, time: 0)
        tracker.lock()
        #expect(tracker.select([], aspectRatio: 1, time: 0.3) == nil)
        // Back in view but far from the remembered joints: not yet.
        #expect(tracker.select([plank], aspectRatio: 1, time: 0.6) == nil)
        // After `reacquireAfter` without a match, the lone person at the athlete's spot is the athlete.
        #expect(tracker.select([plank], aspectRatio: 1, time: 1.2) == 0)
        #expect(tracker.isLocked)
        // And then followed as usual.
        #expect(tracker.select([plank], aspectRatio: 1, time: 1.3) == 0)
    }

    /// A coach stands beyond the head of an athlete in a plank; Vision loses the athlete for a
    /// moment. The coach, already known as someone else, is never taken for the athlete.
    @Test func lockedTrackerDoesNotTakeTheCoachBesideALostAthlete() {
        var tracker = AthleteTracker()
        let coach = person(x: 0.22, top: 0.35, height: 0.45)
        for tenth in 0...10 {
            #expect(tracker.select([plank, coach], aspectRatio: 1, time: Double(tenth) / 10) == 0)
            if tenth == 0 { tracker.lock() }
        }
        // The athlete is not detected; only the coach is.
        for tenth in 11...40 {
            #expect(tracker.select([coach], aspectRatio: 1, time: Double(tenth) / 10) == nil)
        }
        // The athlete is back, and the tracker follows them, not the coach.
        #expect(tracker.select([coach, plank], aspectRatio: 1, time: 4.1) == 1)
    }

    @Test func lockedTrackerDoesNotPickUpAnyoneWhenSeveralPeopleAreInView() {
        var tracker = AthleteTracker()
        _ = tracker.select([person(x: 0.5)], aspectRatio: 1, time: 0)
        tracker.lock()
        // Someone in a plank where the athlete was, and someone else across the room: Plumb cannot tell
        // which one is the athlete, so it waits.
        for tenth in 1...30 {
            #expect(tracker.select([plank, person(x: 0.15)], aspectRatio: 1, time: Double(tenth) / 10) == nil)
        }
        // Alone, that person is picked up.
        #expect(tracker.select([plank], aspectRatio: 1, time: 3.1) == 0)
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

nonisolated struct TrackedSetEvidenceTests {
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
                // Whoever hides the athlete stands in front of them, where the athlete was.
                let inFront = bystanders ? [person(x: 0.52)] : []
                return PoseFrame(time: time, subjectCount: inFront.count, joints: [:],
                                 athleteTracking: .hidden, bystanders: inFront)
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
        #expect(analysis.rubricVersion == "squat-side-v7")
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

    /// Someone standing at the far side of the room does not excuse losing the athlete: only a
    /// person in front of them does.
    @Test func aDistantBystanderKeepsTheShortLimit() {
        let frames = trackedSquat().map { frame -> PoseFrame in
            guard frame.time >= 7.0 && frame.time < 9.8 else { return frame }
            return PoseFrame(time: frame.time, subjectCount: 2, joints: [:], athleteTracking: .hidden,
                             bystanders: [person(x: 0.9)])
        }
        guard case .insufficientView(let reason) = SquatAnalyzer.analyze(frames) else {
            Issue.record("2.8 s without the athlete, with nobody in front of them, must be refused")
            return
        }
        #expect(reason.hasPrefix("Tracking was lost during the set."))
    }

    /// Someone in front of the athlete but a few centimetres off the line of their leg still hides them.
    @Test func someoneInFrontSlightlyOffTheLegStillCountsAsHidingTheAthlete() {
        let frames = trackedSquat().map { frame -> PoseFrame in
            guard frame.time >= 4.5 && frame.time < 6.5 else { return frame }
            return PoseFrame(time: frame.time, subjectCount: 1, joints: [:], athleteTracking: .hidden,
                             bystanders: [person(x: 0.58)])
        }
        guard case .analyzed = SquatAnalyzer.analyze(frames) else {
            Issue.record("A two-second occlusion by someone in front must not cancel the set")
            return
        }
    }

    @Test func aLostAnkleIsNamedAlone() {
        let frames = trackedSquat(bystanders: false).map { frame -> PoseFrame in
            guard frame.time >= 7.0 && frame.time < 9.0 else { return frame }
            var joints = frame.joints
            joints[.leftAnkle] = nil
            joints[.rightAnkle] = nil
            return PoseFrame(time: frame.time, subjectCount: 1, joints: joints, athleteTracking: .tracked)
        }
        guard case .insufficientView(let reason) = SquatAnalyzer.analyze(frames) else {
            Issue.record("Two seconds without the ankle must be refused")
            return
        }
        #expect(reason.contains("Plumb lost your ankle for"), "\(reason)")
        #expect(reason.contains("Keep your ankle in view"), "\(reason)")
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
