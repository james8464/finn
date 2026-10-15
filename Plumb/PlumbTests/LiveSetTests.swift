import Foundation
import Testing
@testable import Plumb

nonisolated struct StartReadinessTests {
    @Test func holdingStillInPositionStartsAfterTheHold() {
        var readiness = StartReadiness()
        var time = 0.0
        while time < StartReadiness.hold - 0.1 {
            readiness.update(with: CaptureTraces.frame(time: time, hipY: 0.42, ankleX: 0.51, legs: true),
                             definition: .squat)
            time += CaptureTraces.step
        }
        #expect(!readiness.isReady)
        #expect(readiness.progress > 0.8)
        readiness.update(with: CaptureTraces.frame(time: StartReadiness.hold + 0.01, hipY: 0.42, ankleX: 0.51,
                                                   legs: true), definition: .squat)
        #expect(readiness.isReady)
    }

    @Test func aPushUpStartsFromAPlankNotFromStanding() {
        // Standing with the arms down: shoulder, elbow and wrist clear and still.
        var readiness = StartReadiness()
        var time = 0.0
        while time < 2.5 {
            readiness.update(with: PoseFrame(time: time, subjectCount: 1, joints: [
                .leftShoulder: JointPoint(x: 0.50, y: 0.30, confidence: 0.6),
                .leftElbow: JointPoint(x: 0.50, y: 0.42, confidence: 0.6),
                .leftWrist: JointPoint(x: 0.51, y: 0.54, confidence: 0.6),
                .leftHip: JointPoint(x: 0.50, y: 0.55, confidence: 0.6),
            ], athleteTracking: .tracked), definition: .pushUp)
            time += CaptureTraces.step
        }
        #expect(!readiness.isReady)
        // In a plank, the same hold starts the set.
        readiness.reset()
        time = 0
        while time < 2.0 {
            readiness.update(with: CaptureTraces.pushUpFrame(time: time, elbowBend: 0, wristX: 0.62, wristY: 0.86),
                             definition: .pushUp)
            time += CaptureTraces.step
        }
        #expect(readiness.isReady)
    }

    @Test func walkingIntoPlaceDoesNotStart() {
        var readiness = StartReadiness()
        for frame in CaptureTraces.walkIn() {
            readiness.update(with: frame, definition: .squat)
            #expect(!readiness.isReady)
        }
    }

    /// A plank with the right side to the camera: the far (left) arm is clear enough but the far hip
    /// is not. The near side is in a plank, so the set starts; before, the far side was tried first
    /// and every frame counted as a miss.
    @Test func aPlankSeenFromTheRightStartsLikeOneSeenFromTheLeft() {
        func plank(time: Double) -> PoseFrame {
            PoseFrame(time: time, subjectCount: 1, joints: [
                .rightShoulder: JointPoint(x: 0.30, y: 0.70, confidence: 0.85),
                .rightElbow: JointPoint(x: 0.30, y: 0.78, confidence: 0.85),
                .rightWrist: JointPoint(x: 0.30, y: 0.86, confidence: 0.85),
                .rightHip: JointPoint(x: 0.62, y: 0.74, confidence: 0.7),
                .leftShoulder: JointPoint(x: 0.31, y: 0.70, confidence: 0.5),
                .leftElbow: JointPoint(x: 0.31, y: 0.78, confidence: 0.5),
                .leftWrist: JointPoint(x: 0.31, y: 0.86, confidence: 0.5),
                .leftHip: JointPoint(x: 0.62, y: 0.74, confidence: 0.25),
            ], aspectRatio: 1280.0 / 720.0, athleteTracking: .tracked)
        }
        var readiness = StartReadiness()
        var time = 0.0
        while time < StartReadiness.hold + 0.2 {
            readiness.update(with: plank(time: time), definition: .pushUp)
            time += CaptureTraces.step
        }
        #expect(readiness.isReady)
    }

    /// Standing with the right side to the camera; the far side hovers around the confidence floor
    /// and the near knee is unclear now and then. The side seen best is followed, and its odd
    /// unclear frame is a miss, not a switch to the far side that restarted the hold.
    @Test func aFarSideAroundTheConfidenceFloorDoesNotRestartTheHold() {
        func standing(frame index: Int) -> PoseFrame {
            let far = index % 3 == 2 ? 0.25 : 0.35
            let nearKnee = index % 7 == 6 ? 0.25 : 0.6
            return PoseFrame(time: Double(index) * CaptureTraces.step, subjectCount: 1, joints: [
                .rightShoulder: JointPoint(x: 0.46, y: 0.17, confidence: 0.6),
                .rightHip: JointPoint(x: 0.47, y: 0.42, confidence: 0.6),
                .rightKnee: JointPoint(x: 0.49, y: 0.70, confidence: nearKnee),
                .rightAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.6),
                .leftShoulder: JointPoint(x: 0.52, y: 0.17, confidence: far),
                .leftHip: JointPoint(x: 0.53, y: 0.42, confidence: far),
                .leftKnee: JointPoint(x: 0.55, y: 0.70, confidence: far),
                .leftAnkle: JointPoint(x: 0.57, y: 0.90, confidence: far),
            ], athleteTracking: .tracked)
        }
        var readiness = StartReadiness()
        var index = 0
        while Double(index) * CaptureTraces.step < StartReadiness.hold + 0.3 {
            readiness.update(with: standing(frame: index), definition: .squat)
            index += 1
        }
        #expect(readiness.isReady)
    }

    @Test func aFewMissedFramesKeepTheHoldButLeavingRestartsIt() {
        var readiness = StartReadiness()
        var time = 0.0
        func step(legs: Bool, ankleX: Double = 0.51) {
            readiness.update(with: CaptureTraces.frame(time: time, hipY: 0.42, ankleX: ankleX, legs: legs),
                             definition: .squat)
            time += CaptureTraces.step
        }
        for _ in 0..<10 { step(legs: true) }
        for _ in 0..<2 { step(legs: false) }
        for _ in 0..<5 { step(legs: true) }
        #expect(readiness.progress > 0.5)
        for _ in 0..<5 { step(legs: false) }
        #expect(readiness.progress == 0)
        // Moving the planted foot restarts the hold too.
        for _ in 0..<10 { step(legs: true) }
        step(legs: true, ankleX: 0.62)
        #expect(readiness.progress == 0)
    }
}

nonisolated struct LiveSetMonitorTests {
    /// Feeds the frames one by one, as the camera does, and collects every event.
    private func run(_ frames: [PoseFrame], definition: ExerciseDefinition = .squat)
        -> (events: [LiveSetEvent], monitor: LiveSetMonitor, stoppedAt: Double?) {
        var monitor = LiveSetMonitor(definition: definition)
        var events: [LiveSetEvent] = []
        var seen: [PoseFrame] = []
        var stoppedAt: Double?
        for frame in frames {
            seen.append(frame)
            events += monitor.update(with: seen)
            if stoppedAt == nil, monitor.isOver { stoppedAt = frame.time }
        }
        return (events, monitor, stoppedAt)
    }

    @Test func countsEachRepOnceAndInOrder() {
        let result = run(CaptureTraces.squats(reps: 6, from: 0))
        let counts = result.events.compactMap { event -> Int? in
            if case .repCounted(let count) = event { return count }
            return nil
        }
        #expect(counts == [1, 2, 3, 4, 5, 6])
    }

    @Test func liveCountMatchesTheResult() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0)
            + CaptureTraces.walkOut(from: 14.0)
        let result = run(capture)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(capture, as: .squat) else {
            Issue.record("Expected a measured set")
            return
        }
        #expect(result.monitor.countedReps == analysis.reps.count)
    }

    @Test func walkingAwayAfterTheRepsEndsTheSet() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0)
            + CaptureTraces.walkOut(from: 14.0)
        guard let stoppedAt = run(capture).stoppedAt else {
            Issue.record("Expected the set to end once the athlete walked away")
            return
        }
        // Out of position from about 14.3 s; the set ends about two seconds later, not during the reps.
        #expect(stoppedAt > 15.5 && stoppedAt < 17.0)
    }

    @Test func anUnclearAnkleAtTheSpotDoesNotEndTheSet() {
        let reps = CaptureTraces.squats(reps: 3, from: 0, standing: 4).map { frame -> PoseFrame in
            guard frame.time > 6.2 else { return frame }
            return CaptureTraces.frame(time: frame.time, hipY: 0.42, ankleX: 0.51, legs: true, ankle: false)
        }
        #expect(run(reps).stoppedAt == nil)
    }

    /// Someone walks between the phone and the athlete for 2.5 s mid-set: the evidence gate allows
    /// that gap, so hands-free must not end the set.
    @Test func aPasserByHidingTheAthleteDoesNotEndTheSet() {
        // Eight reps, so 2.5 s hidden keeps the 80% coverage the gate needs.
        let frames = CaptureTraces.squats(reps: 8, from: 0).map { frame -> PoseFrame in
            guard frame.time > 5.0 && frame.time < 7.5 else { return frame }
            // The passer-by stands where the athlete is.
            let passerBy = CaptureTraces.frame(time: frame.time, hipY: 0.42, ankleX: 0.53, legs: true).joints
            return PoseFrame(time: frame.time, subjectCount: 1, joints: [:], athleteTracking: .hidden,
                             bystanders: [passerBy])
        }
        #expect(run(frames).stoppedAt == nil)
        guard case .analyzed = ExerciseAnalyzer.analyze(frames, as: .squat) else {
            Issue.record("The gate allows a 2.5 s occlusion by someone in front")
            return
        }
    }

    /// Slow reps with a pause at the top: the idle stop must not cut the set during the next rep.
    @Test func slowRepsWithPausesAreNotIdleness() {
        var frames: [PoseFrame] = []
        var time = 0.0
        while time <= 34.0 {
            // An 8.5 s cycle: 6.5 s down and up, 2 s standing.
            let cycle = time.truncatingRemainder(dividingBy: 8.5)
            let phase = cycle < 6.5 ? cycle / 6.5 : 0
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            frames.append(CaptureTraces.frame(time: time, hipY: hipY, ankleX: 0.51, legs: true))
            time += CaptureTraces.step
        }
        let result = run(frames)
        #expect(result.stoppedAt == nil)
        #expect(result.monitor.countedReps == 4)
    }

    /// The hands-free countdown started but no rep counted (every movement too shallow, or the person
    /// changed their mind), then the athlete walks back to the phone. The set ends as it does after
    /// reps, instead of keeping the camera and the screen on until the 2-minute limit.
    @Test func walkingAwayFromTheSpotWithoutAnyRepEndsTheSet() {
        let capture = CaptureTraces.squats(reps: 0, from: 0, standing: 4) + CaptureTraces.walkOut(from: 4.0, duration: 4.0)
        let result = run(capture)
        #expect(result.monitor.countedReps == 0)
        guard let stoppedAt = result.stoppedAt else {
            Issue.record("Expected the set to end once the athlete walked away")
            return
        }
        #expect(stoppedAt > 5.5 && stoppedAt < 7.0)
    }

    /// Without a rep, being unseen at the spot does not end the set: getting down into a push-up can
    /// hide the athlete from Vision for a moment.
    @Test func beingUnseenWithoutAnyRepDoesNotEndTheSet() {
        let standing = CaptureTraces.squats(reps: 0, from: 0, standing: 3)
        let unseen = (1...90).map { index in
            PoseFrame(time: 3.0 + Double(index) * CaptureTraces.step, subjectCount: 0, joints: [:], athleteTracking: .hidden)
        }
        #expect(run(standing + unseen).stoppedAt == nil)
    }

    @Test func walkingInWithoutAnyRepNeverEndsTheSet() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.walkOut(from: 2.0)
        #expect(run(capture).stoppedAt == nil)
    }

    @Test func standingStillAfterTheRepsEndsTheSet() {
        let capture = CaptureTraces.squats(reps: 3, from: 0, standing: 10)
        guard let stoppedAt = run(capture).stoppedAt else {
            Issue.record("Expected the set to end after standing still")
            return
        }
        #expect(stoppedAt >= 6 + LiveSetMonitor.idleAfter - 1 && stoppedAt < 16.5)
    }

    @Test func aRepMuchFasterThanTheFirstOnesIsSaidOnce() {
        // Three 2 s reps, then three 1 s reps.
        var frames = CaptureTraces.squats(reps: 3, from: 0)
        var time = 6.0 + CaptureTraces.step
        while time <= 9.0 {
            let phase = (time - 6.0).truncatingRemainder(dividingBy: 1.0)
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            frames.append(CaptureTraces.frame(time: time, hipY: hipY, ankleX: 0.51, legs: true))
            time += CaptureTraces.step
        }
        let faster = run(frames).events.filter {
            if case .fasterThanFirstReps = $0 { return true }
            return false
        }
        #expect(faster.count == 1)
        #expect(faster.first?.spoken(for: .squat) == "Faster than your first reps")
    }

    @Test func aRepMuchShorterThanTheFirstOnesIsSaid() {
        // Two deep reps, then shallower ones (hips 0.20 down, then 0.15).
        var frames: [PoseFrame] = []
        var time = 0.0
        while time <= 10.0 {
            let rep = Int(time / 2.0)
            let amplitude = rep < 2 ? 0.20 : 0.15
            let phase = time.truncatingRemainder(dividingBy: 2.0) / 2.0
            let hipY = 0.42 + amplitude * (1 - cos(2 * .pi * phase)) / 2
            frames.append(CaptureTraces.frame(time: time, hipY: hipY, ankleX: 0.51, legs: true))
            time += CaptureTraces.step
        }
        let shorter = run(frames).events.compactMap { event -> Int? in
            if case .shorterThanFirstReps(let rep) = event { return rep }
            return nil
        }
        #expect(shorter.first == 3)
        #expect(LiveSetEvent.shorterThanFirstReps(rep: 3).spoken(for: .squat) == "Range is shorter")
        #expect(LiveSetEvent.shorterThanFirstReps(rep: 3).spoken(for: .pushUp) == "Elbow bend is smaller")
    }

    /// Tired late in a set, a rep can be both quicker and shallower than the first ones. It gets one
    /// observation, so the count and that observation can be said together without cutting each
    /// other off; the quicker reps are still noted for the frequent pattern.
    @Test func aRepBothFasterAndShorterGetsOneCue() {
        let result = run(CaptureTraces.tiringSquats())
        var cuesPerRep: [Int: Int] = [:]
        for event in result.events {
            switch event {
            case .fasterThanFirstReps(let rep), .shorterThanFirstReps(let rep), .formFault(_, let rep):
                cuesPerRep[rep, default: 0] += 1
            case .repCounted, .repCountRevised: break
            }
        }
        #expect(result.monitor.countedReps == 6)
        #expect(!cuesPerRep.isEmpty)
        #expect(cuesPerRep.values.allSatisfy { $0 == 1 }, "\(cuesPerRep)")
        #expect(result.monitor.sawFasterRep)
    }

    /// Fast push-ups whose tops sit below the opening plank (Guilhem, 15 October: the live count
    /// reached 29, the result 18). Measured over the whole set, a movement said as a rep early can
    /// stop counting later. The live count is the analysis of the set so far, so it ends on what
    /// the result says, comes down when it must, and never says a number twice.
    @Test func theLiveCountIsTheWholeSetAnalysisAndNeverSaysANumberTwice() {
        let frames = fastPushUps(plank: 3, reps: 12, cycle: 0.55, topBend: 25, bottomBend: 85)
        let result = run(frames, definition: .pushUp)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: .pushUp, viewCheck: .ignore) else {
            Issue.record("Expected a measured set")
            return
        }
        #expect(result.monitor.countedReps == analysis.reps.count)
        let said = result.events.compactMap { event -> Int? in
            if case .repCounted(let count) = event { return count }
            return nil
        }
        #expect(said == Array(1...max(1, said.count)))
        let revised = result.events.compactMap { event -> Int? in
            if case .repCountRevised(let count) = event { return count }
            return nil
        }
        #expect(!revised.isEmpty, "this trace is one where the whole-set analysis takes reps back")
        #expect(revised.allSatisfy { $0 <= said.count })
        // A revised count is shown, not spoken.
        #expect(LiveSetEvent.phrase(for: [.repCountRevised(3)], definition: .pushUp) == nil)
        #expect(LiveSetEvent.repCountRevised(3).caption(for: .pushUp) == nil)
    }

    /// Push-ups at about 0.5 s a cycle, all complete: every one is said and every one is in the result.
    @Test func fastCompletePushUpsAreCountedLiveAndInTheResult() {
        let frames = fastPushUps(plank: 2, reps: 20, cycle: 0.5, topBend: 20, bottomBend: 80)
        let result = run(frames, definition: .pushUp)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: .pushUp, viewCheck: .ignore) else {
            Issue.record("Expected a measured set")
            return
        }
        #expect(analysis.reps.count == 20)
        #expect(result.monitor.countedReps == 20)
    }

    /// A plank, then reps whose top and bottom bends are given, at 15 fps, then the top held 2 s.
    private func fastPushUps(plank: Double, reps: Int, cycle: Double, topBend: Double, bottomBend: Double)
        -> [PoseFrame] {
        var frames: [PoseFrame] = []
        var time = 0.0
        func add(_ bend: Double) {
            frames.append(CaptureTraces.pushUpFrame(time: time, elbowBend: bend, wristX: 0.62, wristY: 0.86))
            time += CaptureTraces.step
        }
        while time < plank { add(0) }
        let start = time
        while time < start + Double(reps) * cycle {
            let phase = (time - start).truncatingRemainder(dividingBy: cycle) / cycle
            add(topBend + (bottomBend - topBend) * (1 - cos(2 * .pi * phase)) / 2)
        }
        let end = time
        while time < end + 2 { add(topBend) }
        return frames
    }

    @Test func steadyRepsSayOnlyTheCount() {
        let events = run(CaptureTraces.squats(reps: 6, from: 0)).events
        #expect(events.allSatisfy { if case .repCounted = $0 { return true } else { return false } })
    }
}
