import Foundation
import Testing
@testable import Finn

nonisolated struct SquatAnalyzerTests {
    @Test func countsSixCompleteReps() {
        let outcome = SquatAnalyzer.analyze(squatTrace(reps: 6))
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == "squat-side-v7")
        #expect(analysis.reps.map(\.number) == [1, 2, 3, 4, 5, 6])
        #expect(analysis.reps.allSatisfy { $0.duration > 1.3 && $0.duration < 2.1 })
        #expect(analysis.reps.allSatisfy { $0.normalizedHipTravel > 0.35 && $0.normalizedHipTravel < 0.5 })
    }

    @Test func incompleteFinalRepIsNotCounted() {
        var frames = squatTrace(reps: 6)
        frames += squatTrace(reps: 1, startTime: 12.1).filter { $0.time <= 13.2 }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect((analysis.reps.last?.endTime ?? 0) < 12.1)
    }

    @Test func droppedFramesDoNotChangeRepCount() {
        let frames = squatTrace(reps: 6).enumerated().compactMap { index, frame in
            index.isMultiple(of: 4) ? nil : frame
        }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect(analysis.reps.allSatisfy { $0.duration > 1.3 && $0.duration < 2.1 })
    }

    @Test func stationaryTraceHasNoReps() {
        let frames = (0...40).map { index in
            frame(time: Double(index) * 0.1, hipY: 0.42)
        }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.isEmpty)
    }

    /// A pause with a small rise on the way down is not the way up: the rep keeps its full depth,
    /// and no "range became shorter" observation is made up.
    @Test func aWobbleOnTheWayDownKeepsTheRepsFullDepth() {
        var frames: [PoseFrame] = []
        var time = 0.0
        for rep in 0..<6 {
            // 30 samples per rep at 0.1 s: down to 0.20 below standing, back up.
            for index in 0..<30 {
                let phase = Double(index) / 30
                var drop = 0.20 * (1 - cos(2 * .pi * phase)) / 2
// reps 5 and 6 stall about halfway down and rise a little before going on.
                if rep >= 4 && index >= 8 && index < 12 { drop = 0.13 - 0.02 * Double(index - 8) }
                frames.append(frame(time: time, hipY: 0.42 + drop))
                time += 0.1
            }
        }
        frames.append(frame(time: time, hipY: 0.42))
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(frames) else {
            Issue.record("Expected a measured set")
            return
        }
        #expect(analysis.reps.count == 6)
        let ranges = analysis.reps.map(\.relativeRange)
        #expect((ranges.min() ?? 0) > 0.9 * (ranges.max() ?? 1), "ranges \(ranges)")
        #expect(CueSelector.select(from: analysis) == nil)
    }

    /// The set opened partway down the first squat (it began during the countdown): that rep is
    /// measured from the set's top, not from where the capture started.
    @Test func aRepUnderWayWhenTheSetStartsKeepsItsDepth() {
        let trace = squatTrace(reps: 6).dropFirst(5).map { $0 }
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(trace) else {
            Issue.record("Expected a measured set")
            return
        }
        let ranges = analysis.reps.map(\.relativeRange)
        #expect(ranges.count == 6, "ranges \(ranges)")
        #expect((ranges.first ?? 0) > 0.9 * (ranges.last ?? 1), "ranges \(ranges)")
    }

    @Test func emptyTraceNeedsAnotherView() {
        let outcome = SquatAnalyzer.analyze([])
        guard case .insufficientView = outcome else {
            Issue.record("An empty trace must not become a measured set")
            return
        }
    }

    private func squatTrace(reps: Int, startTime: Double = 0) -> [PoseFrame] {
        (0...(reps * 20)).map { index in
            let time = startTime + Double(index) * 0.1
            let phase = Double(index % 20) / 20
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            return frame(time: time, hipY: hipY)
        }
    }

    private func frame(time: Double, hipY: Double) -> PoseFrame {
        PoseFrame(
            time: time,
            subjectCount: 1,
            joints: [
                .leftHip: JointPoint(x: 0.47, y: hipY, confidence: 0.99),
                .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: 0.99),
                .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.99),
                .rightHip: JointPoint(x: 0.53, y: hipY, confidence: 0.99),
                .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: 0.99),
                .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: 0.99),
            ]
        )
    }
}
