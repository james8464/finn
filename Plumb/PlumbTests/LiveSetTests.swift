import Foundation
import Testing
@testable import Plumb

nonisolated struct StartReadinessTests {
    @Test func holdingStillInPositionStartsAfterTheHold() {
        var readiness = StartReadiness()
        var time = 0.0
        while time < StartReadiness.hold - 0.1 {
            readiness.update(with: CaptureTraces.frame(time: time, hipY: 0.42, ankleX: 0.51, legs: true),
                             requirement: .squat)
            time += CaptureTraces.step
        }
        #expect(!readiness.isReady)
        #expect(readiness.progress > 0.8)
        readiness.update(with: CaptureTraces.frame(time: StartReadiness.hold + 0.01, hipY: 0.42, ankleX: 0.51,
                                                   legs: true), requirement: .squat)
        #expect(readiness.isReady)
    }

    @Test func walkingIntoPlaceDoesNotStart() {
        var readiness = StartReadiness()
        for frame in CaptureTraces.walkIn() {
            readiness.update(with: frame, requirement: .squat)
            #expect(!readiness.isReady)
        }
    }

    @Test func aFewMissedFramesKeepTheHoldButLeavingRestartsIt() {
        var readiness = StartReadiness()
        var time = 0.0
        func step(legs: Bool, ankleX: Double = 0.51) {
            readiness.update(with: CaptureTraces.frame(time: time, hipY: 0.42, ankleX: ankleX, legs: legs),
                             requirement: .squat)
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

    @Test func steadyRepsSayOnlyTheCount() {
        let events = run(CaptureTraces.squats(reps: 6, from: 0)).events
        #expect(events.allSatisfy { if case .repCounted = $0 { return true } else { return false } })
    }
}
