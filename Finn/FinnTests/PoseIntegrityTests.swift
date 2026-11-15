import Foundation
import Testing
@testable import Finn

struct PoseIntegrityTests {
    @Test func projectedTorsoMustBelongToTheTrackedAthlete() {
        let projection: [BodyJoint: SIMD2<Double>] = [
            .leftShoulder: SIMD2(0.40, 0.30), .rightShoulder: SIMD2(0.46, 0.30),
            .leftHip: SIMD2(0.42, 0.51), .rightHip: SIMD2(0.48, 0.51),
        ]
        func joints(shift: Double) -> [BodyJoint: JointPoint] {
            projection.mapValues { JointPoint(x: $0.x + shift, y: $0.y, confidence: 0.95) }
        }
        let tracked = joints(shift: 0.01)
        #expect(ViewCheck.matchesTrackedTorso(projection, athlete: tracked, bystanders: [joints(shift: 0.09)], aspectRatio: 1))
        #expect(!ViewCheck.matchesTrackedTorso(projection, athlete: joints(shift: 0.09), bystanders: [tracked], aspectRatio: 1))
        #expect(!ViewCheck.matchesTrackedTorso(projection, athlete: tracked, bystanders: [joints(shift: 0.012)], aspectRatio: 1))
        let distant = joints(shift: 0.20).filter { $0.key == .leftHip }
        let overlapping = tracked.filter { $0.key == .leftHip }
        #expect(ViewCheck.matchesTrackedTorso(projection, athlete: tracked, bystanders: [distant], aspectRatio: 1))
        #expect(!ViewCheck.matchesTrackedTorso(projection, athlete: tracked, bystanders: [overlapping], aspectRatio: 1))
        #expect(!ViewCheck.matchesTrackedTorso(projection.filter { $0.key == .leftHip }, athlete: tracked,
                                              bystanders: [joints(shift: 0.09)], aspectRatio: 1))
    }

    @Test func aSustainedTurnCannotBeHiddenByTheSetsMedianAngle() {
        func frames(_ deviations: [Double?]) -> [PoseFrame] {
            deviations.enumerated().map {
                PoseFrame(time: Double($0.offset) * 0.27, subjectCount: 1, joints: [:], profileDeviationDegrees: $0.element)
            }
        }
        let turned = frames([5, 7, 58, 62, 6, 5, 7])
        #expect(ViewCheck.assess(turned, expected: .side) == .matches(medianDeviation: 7, estimates: 7))
        #expect(ViewCheck.hasSustainedTurn(turned))
        let rep = RepMetric(number: 1, startTime: 1.0, endTime: 1.6, relativeRange: 0.4)
        #expect(!ViewCheck.hasSustainedTurn(during: [rep], in: turned))
        #expect(!ViewCheck.hasSustainedTurn(frames([5, 7, 60, 6, 5])))
        #expect(!ViewCheck.hasSustainedTurn(frames([5, 59, nil, nil, 62, 6, 7])))
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, -0.01, 1.01])
    func invalidCoordinatesAreMissingEvidence(value: Double) {
        let frame = PoseFrame(time: 0, subjectCount: 1, joints: [
            .leftHip: JointPoint(x: value, y: 0.4, confidence: 0.9),
            .leftKnee: JointPoint(x: 0.5, y: 0.6, confidence: 0.9),
        ])
        #expect(frame.joints[.leftHip] == nil)
        #expect(frame.joints[.leftKnee] != nil)
        #expect(BodySegments(frame: frame, side: .left).thigh == nil)
    }

    @Test(arguments: [Double.nan, .infinity, -1, 0, 11])
    func invalidImageGeometryCannotProduceAngles(aspectRatio: Double) {
        let frame = PoseFrame(
            time: 0,
            subjectCount: 1,
            joints: [.leftHip: point],
            aspectRatio: aspectRatio
        )
        #expect(frame.joints.isEmpty)
    }

    @Test func replayDecodingAppliesTheLiveValidation() throws {
        let data = Data(
            #"{"time":0,"subjectCount":1,"joints":["leftHip",{"x":2,"y":0.5,"confidence":0.9}],"profileDeviationDegrees":200}"#
                .utf8
        )
        let frame = try JSONDecoder().decode(PoseFrame.self, from: data)
        #expect(frame.joints.isEmpty)
        #expect(frame.profileDeviationDegrees == nil)
        #expect(frame.aspectRatio == 1)
    }

    @Test func malformedClassifierFeaturesAreDropped() {
        let short = PoseFrame(time: 0, subjectCount: 1, joints: [:], keypoints: [0, 1])
        let nonFinite = PoseFrame(
            time: 0,
            subjectCount: 1,
            joints: [:],
            keypoints: Array(repeating: .infinity, count: 54)
        )
        #expect(short.keypoints == nil)
        #expect(nonFinite.keypoints == nil)
    }

    @Test(arguments: [Double.nan, .infinity, -1, 0])
    func brokenCaptureClocksCannotBeAnalysed(time: Double) {
        let frames = [standing(at: 0), standing(at: time), standing(at: 4)]
        #expect(!PoseFrame.hasIncreasingTimestamps(frames))
        #expect(EvidenceGate.assess(frames).isRejected)
        if case .analyzed = ExerciseAnalyzer.analyse(frames, as: .squat) {
            Issue.record("A malformed clock was measured")
        }
    }

    @Test func aCameraPauseRestartsTheReadinessHold() {
        var readiness = StartReadiness()
        for index in 0 ... 10 {
            readiness.update(with: standing(at: Double(index) / 10), definition: .squat)
        }
        #expect(readiness.progress > 0)
        readiness.update(with: standing(at: 8), definition: .squat)
        #expect(readiness.progress == 0)
        #expect(!readiness.isReady)
    }

    @Test func hiddenAthletesNeverSupplyFormGeometry() {
        let frame = PoseFrame(time: 0, subjectCount: 2, joints: [.leftHip: point], athleteTracking: .hidden)
        #expect(BodySegments(frame: frame, side: .left).hip == nil)
    }

    @Test func unrepresentableFormReadingsCannotCrashTextFormatting() {
        for value in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            #expect(FormCheck.pushUpHipsSag.observation(reps: [1, 2], typical: value).isEmpty)
        }
    }

    @Test(arguments: [5, 15, 30, 60])
    func verticalCameraMotionCannotBecomeHipOnlySquats(framesPerSecond: Int) {
        let frames = (0 ... (framesPerSecond * 8)).map { index in
            let time = Double(index) / Double(framesPerSecond)
            let shift = 0.08 * sin(2 * .pi * time)
            return PoseFrame(time: time, subjectCount: 1, joints: [
                .leftShoulder: JointPoint(x: 0.5, y: 0.2 + shift, confidence: 0.9),
                .leftHip: JointPoint(x: 0.5, y: 0.45 + shift, confidence: 0.9),
                .leftAnkle: JointPoint(x: 0.5, y: 0.8 + shift, confidence: 0.9)
            ])
        }
        if case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) {
            #expect(analysis.reps.isEmpty, "Rigid camera translation is not a squat")
        }
    }

    @Test(arguments: [5, 15, 30, 60])
    func observedHipOnlySquatsKeepTheirCountAtDifferentFrameRates(framesPerSecond: Int) throws {
        let frames = (0 ... (framesPerSecond * 8)).map { index in
            let time = Double(index) / Double(framesPerSecond)
            let shift = 0.2 * (1 - cos(.pi * time)) / 2
            return PoseFrame(time: time, subjectCount: 1, joints: [
                .leftShoulder: JointPoint(x: 0.5, y: 0.2 + shift, confidence: 0.9),
                .leftHip: JointPoint(x: 0.5, y: 0.45 + shift, confidence: 0.9),
                .leftAnkle: JointPoint(x: 0.5, y: 0.9, confidence: 0.9)
            ])
        }
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) else {
            Issue.record("Clear hip-only squats should remain measurable")
            return
        }
        #expect(analysis.reps.count == 4)
    }

    private var point: JointPoint {
        JointPoint(x: 0.5, y: 0.4, confidence: 0.9)
    }

    private func standing(at time: TimeInterval) -> PoseFrame {
        PoseFrame(time: time, subjectCount: 1, joints: [
            .leftHip: point,
            .leftKnee: JointPoint(x: 0.5, y: 0.6, confidence: 0.9),
            .leftAnkle: JointPoint(x: 0.5, y: 0.8, confidence: 0.9),
        ])
    }
}
