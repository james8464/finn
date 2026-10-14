import AVFoundation
import Foundation
import simd
import Testing
@testable import Plumb

struct ViewCheckTests {
    /// Camera-relative joints of a standing person 2.5 m away, turned `yaw` degrees from a
    /// true profile around the vertical axis. The camera sits slightly above the hips.
    private func body(yaw: Double, offset: SIMD3<Double> = [0.3, -0.1, 2.5],
                      swapSides: Bool = false) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let up = SIMD3<Double>(0, 1, 0)
        let sight = simd_normalize(SIMD3(offset.x, 0, offset.z))
        let angle = yaw * .pi / 180
        // Rotate the line of sight around the vertical axis to get the left-right axis.
        let lateral = simd_normalize(sight * cos(angle) + simd_cross(up, sight) * sin(angle))
        let side = swapSides ? -lateral : lateral
        return (offset + 0.15 * side, offset - 0.15 * side,
                offset + 0.5 * up + 0.2 * side, offset + 0.5 * up - 0.2 * side)
    }

    @Test(arguments: [0.0, 15, 45, 60, 90])
    func deviationFollowsBodyYaw(yaw: Double) throws {
        let (leftHip, rightHip, leftShoulder, rightShoulder) = body(yaw: yaw)
        let deviation = try #require(ViewCheck.profileDeviation(
            leftHip: leftHip, rightHip: rightHip, leftShoulder: leftShoulder, rightShoulder: rightShoulder))
        #expect(abs(deviation - yaw) < 4, "yaw \(yaw) gave \(deviation)")
    }

    @Test func eitherSideAndSwappedLabelsCountAsProfile() throws {
        for (yaw, swap) in [(0.0, true), (180.0, false), (175.0, true)] {
            let (leftHip, rightHip, leftShoulder, rightShoulder) = body(yaw: yaw, swapSides: swap)
            let deviation = try #require(ViewCheck.profileDeviation(
                leftHip: leftHip, rightHip: rightHip, leftShoulder: leftShoulder, rightShoulder: rightShoulder))
            #expect(deviation < 8)
        }
    }

    @Test func degenerateEstimatesGiveNoAngle() {
        let point = SIMD3<Double>(0, 0, 2)
        #expect(ViewCheck.profileDeviation(leftHip: point, rightHip: point) == nil)
        #expect(ViewCheck.profileDeviation(leftHip: [0.1, 0, 0], rightHip: [-0.1, 0, 0]) == nil)
    }

    @Test func setVerdictUsesTheMedianAndNeedsEnoughEstimates() {
        #expect(ViewCheck.assess(frames(deviations: [10, 80, 12, 9, 15]), expected: .side)
                == .matches(medianDeviation: 12, estimates: 5))
        // Off side-on but not clearly frontal: measured, with a tip.
        #expect(ViewCheck.assess(frames(deviations: [50, 60, 12, 70]), expected: .side)
                == .angled(medianDeviation: 60, estimates: 4))
        // Clearly frontal over three seconds: refused.
        #expect(ViewCheck.assess(frames(deviations: [70, 80, 75, 90]), expected: .side)
                == .mismatch(medianDeviation: 80, estimates: 4))
        // Clearly frontal, but only for a second and a half: still measured.
        #expect(ViewCheck.assess(frames(deviations: [70, 80, 75, 90], spacing: 0.5), expected: .side)
                == .angled(medianDeviation: 80, estimates: 4))
        #expect(ViewCheck.assess(frames(deviations: [80, 80, 80]), expected: .side) == .unavailable)
        #expect(ViewCheck.assess(frames(deviations: []), expected: .side) == .unavailable)
    }

    @Test func previewWaitsForThreeEstimates() {
        #expect(!ViewCheck.previewAsksToTurn([80, 85], expected: .side))
        #expect(ViewCheck.previewAsksToTurn([80, 85, 20], expected: .side))
        #expect(!ViewCheck.previewAsksToTurn([10, 85, 20], expected: .side))
    }

    @Test func analyzerRefusesAFrontViewForEveryExercise() {
        let traces: [(ExerciseDefinition, [PoseFrame])] = [
            (.squat, squatTrace()),
            (.staticLunge, lungeTrace(reps: 6)), (.stiffLegDeadlift, hingeTrace(reps: 5)),
        ]
        for (definition, trace) in traces {
            let front = withDeviation(trace, 85)
            guard case .insufficientView(let reason) = ExerciseAnalyzer.analyze(front, as: definition) else {
                Issue.record("\(definition.kind) should refuse a front view")
                continue
            }
            #expect(reason.hasPrefix(ExpectedView.side.wrongViewMessage))
            #expect(reason.contains("85°"))
            guard case .analyzed(let ignored) = ExerciseAnalyzer.analyze(front, as: definition, viewCheck: .ignore)
            else {
                Issue.record("\(definition.kind) should measure when the check is off")
                continue
            }
            #expect(!ignored.reps.isEmpty)
        }
    }

    @Test func aFrontViewPushUpIsCountedFromTheShoulders() {
        let front = withDeviation(pushUpTrace(reps: 6), 85)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(front, as: .pushUp) else {
            Issue.record("A push-up filmed from the front is counted from the shoulders, not refused")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
    }

    @Test func anAngledViewIsMeasuredWithATip() throws {
        let trace = squatTrace()
        let (outcome, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(withDeviation(trace, 45), as: .squat)
        guard case .analyzed(let angled) = outcome, case .analyzed(let plain) = SquatAnalyzer.analyze(trace) else {
            Issue.record("A 45° view must be measured")
            return
        }
        #expect(angled.reps.count == plain.reps.count)
        let tip = try #require(diagnostics?.explanation(for: .squat, counted: angled.reps.count))
        #expect(tip.contains("about 45° from side-on"))
    }

    @Test func aBriefFrontViewDoesNotRefuseTheSet() {
        // Facing the camera for the first two seconds only (while getting into place).
        let trace = squatTrace().enumerated().map { index, frame in
            PoseFrame(time: frame.time, subjectCount: 1, joints: frame.joints,
                      profileDeviationDegrees: index.isMultiple(of: 4) ? (frame.time < 2 ? 85 : 10) : nil)
        }
        guard case .analyzed = SquatAnalyzer.analyze(trace) else {
            Issue.record("Two seconds facing the camera must not refuse the set")
            return
        }
    }

    @Test func sideViewEstimatesLeaveTheSquatUnchanged() {
        let trace = squatTrace()
        #expect(SquatAnalyzer.analyze(withDeviation(trace, 12)) == SquatAnalyzer.analyze(trace))
        // Three estimates are too few to judge, so the 2D rules decide alone.
        #expect(SquatAnalyzer.analyze(withDeviation(trace, 70, every: 50)) == SquatAnalyzer.analyze(trace))
    }

    private func frames(deviations: [Double], spacing: Double = 1) -> [PoseFrame] {
        deviations.enumerated().map {
            PoseFrame(time: Double($0.offset) * spacing, subjectCount: 1, joints: [:],
                      profileDeviationDegrees: $0.element)
        }
    }

    private func squatTrace() -> [PoseFrame] {
        (0...120).map { index in
            squatFrame(time: Double(index) * 0.1,
                       hipY: 0.42 + 0.2 * (1 - cos(2 * .pi * Double(index % 20) / 20)) / 2)
        }
    }
}

/// Adds a 3D profile deviation to every `every`th frame, as the capture driver does.
func withDeviation(_ frames: [PoseFrame], _ degrees: Double, every: Int = 4) -> [PoseFrame] {
    frames.enumerated().map { index, frame in
        PoseFrame(time: frame.time, subjectCount: frame.subjectCount, joints: frame.joints,
                  aspectRatio: frame.aspectRatio, keypoints: frame.keypoints,
                  profileDeviationDegrees: index.isMultiple(of: every) ? degrees : nil)
    }
}

@MainActor
struct ViewCheckSessionTests {
    @Test func framingAsksToTurnFromTheFrontAndClearsWhenSideOn() async throws {
        let (model, source) = makeModel()
        model.selectedExercise = .bodyweightSquat
        await model.startPreview()
        #expect(source.cameraAngleSettings == [true])
        for (index, frame) in withDeviation(squatFrames(count: 12), 80, every: 1).enumerated() where index < 4 {
            source.emit(frame)
        }
        try await waitFor { model.framingStatus == .turnToExpectedView }
        #expect(model.framingStatus == .turnToExpectedView)
        for frame in withDeviation(squatFrames(count: 5, start: 0.4), 10, every: 1) { source.emit(frame) }
        try await waitFor { model.framingStatus == .landmarksVisible }
        #expect(model.framingStatus == .landmarksVisible)
        await model.cancel()
    }

    /// The person walks to their spot with their back to the phone (read as front-on), then stands
    /// side-on and still while 3D estimates stop: a hot phone skips them, and Vision 3D measures only
    /// the person closest to the camera. The old front readings lapse, so the turn tip clears and the
    /// hands-free set starts; before, they stayed and "Turn your side to the camera" was said forever.
    @Test func oldFrontReadingsLapseWhenEstimatesStop() async throws {
        let defaults = try #require(UserDefaults(suiteName: "PlumbViewCheckStale-\(UUID().uuidString)"))
        let source = AngleRecordingSource()
        let model = WorkoutSessionModel(source: source, exerciseClassifier: nil,
                                        preferences: PlumbPreferences(defaults: defaults, handsFreeByDefault: true))
        model.handsFreeCountdown = 0
        await model.startPreview()
        let walking = withDeviation(CaptureTraces.squats(reps: 0, from: 0, standing: 0.6), 85, every: 1)
        let sideOn = CaptureTraces.squats(reps: 0, from: 0.7, standing: 8)
        for frame in walking + sideOn {
            source.emit(frame)
            if model.stage == .capturing { break }
            await Task.yield()
        }
        for _ in 0..<500 where model.stage != .capturing { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.stage == .capturing)
        #expect(model.previewDeviations.count < ViewCheck.minimumPreviewEstimates)
        await model.cancel()
    }

    @Test func aPushUpFromTheFrontIsNeverAskedToTurn() async throws {
        let (model, source) = makeModel()
        model.selectedExercise = .pushUp
        await model.startPreview()
        for frame in withDeviation(squatFrames(count: 12), 85, every: 1) { source.emit(frame) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.framingStatus != .turnToExpectedView)
        await model.cancel()
    }

    @Test func frontViewSetIsRefusedUnlessTheCheckIsOff() async throws {
        let (model, source) = makeModel()
        await capture(model, source, withDeviation(CaptureTraces.squats(reps: 6, from: 0), 75), exercise: .bodyweightSquat)
        #expect({
            if case .insufficientView(let reason) = model.result { return reason.hasPrefix(ExpectedView.side.wrongViewMessage) }
            return false
        }())
        #expect(model.lastViewVerdict == .mismatch(medianDeviation: 75, estimates: 46))
        #expect(model.currentSession == nil)

        model.checksCameraAngle = false
        #expect(source.cameraAngleSettings.last == false)
        await capture(model, source, withDeviation(CaptureTraces.squats(reps: 6, from: 0), 75), exercise: .bodyweightSquat)
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("With the check off, the set should be measured")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    @Test func settingDefaultsOnAndIsRemembered() throws {
        let defaults = try #require(UserDefaults(suiteName: "PlumbViewCheck-\(UUID().uuidString)"))
        let preferences = PlumbPreferences(defaults: defaults)
        let first = WorkoutSessionModel(source: AngleRecordingSource(), exerciseClassifier: nil,
                                        preferences: preferences)
        #expect(first.checksCameraAngle)
        first.checksCameraAngle = false
        let second = WorkoutSessionModel(source: AngleRecordingSource(), exerciseClassifier: nil,
                                         preferences: preferences)
        #expect(!second.checksCameraAngle)
    }

    private func makeModel() -> (WorkoutSessionModel, AngleRecordingSource) {
        let defaults = UserDefaults(suiteName: "PlumbViewCheckSession-\(UUID().uuidString)")!
        let source = AngleRecordingSource()
        return (WorkoutSessionModel(source: source, exerciseClassifier: nil,
                                    preferences: PlumbPreferences(defaults: defaults)), source)
    }

    private func capture(_ model: WorkoutSessionModel, _ source: AngleRecordingSource,
                         _ frames: [PoseFrame], exercise: ExerciseKind) async {
        model.selectedExercise = exercise
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in frames { source.emit(frame) }
        await model.endSet()
    }

    private func squatFrames(count: Int, start: Double = 0) -> [PoseFrame] {
        (0..<count).map { squatFrame(time: start + Double($0) * 0.1, hipY: 0.42) }
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<50 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class AngleRecordingSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private(set) var cameraAngleSettings: [Bool] = []
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func setCameraAngleEstimation(_ enabled: Bool) { cameraAngleSettings.append(enabled) }

    func emit(_ frame: PoseFrame) { continuation?.yield(frame) }
}
