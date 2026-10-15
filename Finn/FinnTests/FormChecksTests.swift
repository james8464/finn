import Foundation
import Testing
@testable import Finn

/// The side-view form checks on synthetic poses: a clean rep gives no advice, a rep with one fault
/// gives that advice, and a check that cannot see its joints says so instead of guessing.
struct FormChecksTests {
    // MARK: Geometry

    @Test func segmentsReadAnglesAndBodyLine() {
// a plank seen from the side, elbow bent square, hip 0.05 below the shoulder-ankle line.
        let frame = PoseFrame(time: 0, subjectCount: 1, joints: [
            .leftWrist: point(0.30, 0.80), .leftElbow: point(0.30, 0.66), .leftShoulder: point(0.44, 0.66),
            .leftHip: point(0.64, 0.71), .leftKnee: point(0.79, 0.70), .leftAnkle: point(0.94, 0.66),
        ])
        let body = BodySegments(frame: frame, side: .left)
        #expect(abs((body.elbowAngle ?? 0) - 90) < 0.5)
        #expect((body.hipOffsetFromBodyLine ?? 0) > 0.2)
        #expect((body.torsoTilt ?? 0) > 70)

// standing tall: torso and shins upright, knee straight, thigh far above level.
        let standing = BodySegments(frame: squatFrame(depth: 0, thighAtBottom: 0, extraLean: 0, time: 0), side: .left)
        #expect((standing.kneeAngle ?? 0) > 175)
        #expect((standing.torsoTilt ?? 90) < 1)
        #expect((standing.thighAboveLevel ?? 0) > 85)
        // Too unsure of a joint: everything that needs it is unknown.
        let unsure = BodySegments(frame: frame, side: .left, minimumConfidence: 0.99)
        #expect(unsure.elbowAngle == nil && unsure.hipOffsetFromBodyLine == nil)
    }

    // MARK: Squat

    @Test func cleanSquatsGetNoAdvice() throws {
        let review = try reviewed(squats(thighAtBottom: -5, extraLean: 5), .squat)
        #expect(review.findings.isEmpty, "\(review.findings)")
        #expect(review.notes.isEmpty, "\(review.notes)")
    }

    @Test func shallowSquatsAreToldToSitLower() throws {
        let review = try reviewed(squats(thighAtBottom: 45, extraLean: 5), .squat)
        let finding = try #require(review.findings.first)
        #expect(finding.check == .squatDepth)
        #expect(finding.reps.count == 6)
        #expect(review.measurements.first(where: { $0.check == .squatDepth })?.faulty == 6)
        #expect(review.measurements.first(where: { $0.check == .squatDepth })?.judged == 6)
        #expect(finding.cue.observation.hasPrefix("Your hips stayed above your knees at the bottom in rep 1"))
        #expect(finding.cue.nextAction == FormCheck.squatDepth.nextAction)
    }

    @Test func chestDroppingForwardIsPointedOut() throws {
        let review = try reviewed(squats(thighAtBottom: -5, extraLean: 55), .squat)
        #expect(review.findings.map(\.check) == [.squatChestDrop])
    }

    @Test func oneShallowSquatIsNotAdvice() throws {
// only the fourth rep stays high: a fault on one rep is not a pattern.
        let frames = squats(thighAtBottom: -5, extraLean: 5, faultyRep: 3, faultyThigh: 45)
        #expect(try reviewed(frames, .squat).findings.isEmpty)
    }

    @Test func squatWithoutShoulderSaysWhatItCouldNotCheck() throws {
        let frames = squats(thighAtBottom: 45, extraLean: 5).map { frame in
            frame.with(joints: frame.joints.filter { $0.key != .leftShoulder && $0.key != .rightShoulder })
        }
        let review = try reviewed(frames, .squat)
        #expect(review.findings.map(\.check) == [.squatDepth])
        #expect(review.notes == ["Finn couldn’t check your chest position: your shoulder wasn’t clear enough at the bottom of the reps."])
    }

    @Test func angledSquatGetsNoFormAdvice() throws {
        let frames = squats(thighAtBottom: 45, extraLean: 55).map { $0.with(deviation: 45) }
        let analysis = try measured(frames, .squat)
        let review = FormChecks.review(analysis, frames: frames, definition: .squat)
        #expect(review.findings.isEmpty && review.notes.isEmpty)
        // The person's camera-angle option off: they say their side faces the camera.
        let trusted = FormChecks.review(analysis, frames: frames, definition: .squat, viewCheck: .ignore)
        #expect(trusted.findings.first?.check == .squatChestDrop)
    }

    // MARK: Push-up

    @Test func cleanPushUpsGetNoAdvice() throws {
        let review = try reviewed(pushUps(sag: 0, bottomElbow: 85), .pushUp)
        #expect(review.findings.isEmpty, "\(review.findings)")
        #expect(review.notes.isEmpty, "\(review.notes)")
    }

    @Test func saggingHipsAreToldToLift() throws {
        let review = try reviewed(pushUps(sag: 0.4, bottomElbow: 85), .pushUp)
        #expect(review.findings.map(\.check) == [.pushUpHipsSag])
        #expect(review.findings.first?.observation.contains("sagged below the line from your shoulders to your ankles") == true)
    }

    @Test func pikedHipsAreToldToLower() throws {
        let review = try reviewed(pushUps(sag: -0.4, bottomElbow: 85), .pushUp)
        #expect(review.findings.map(\.check) == [.pushUpHipsPike])
    }

    @Test func shallowPushUpsComeAfterTheBodyLine() throws {
        let shallow = try reviewed(pushUps(sag: 0, bottomElbow: 126), .pushUp)
        #expect(shallow.findings.map(\.check) == [.pushUpDepth])
        // Both faults: the body line is the observation, the depth a fact listed below it.
        let both = try reviewed(pushUps(sag: 0.4, bottomElbow: 126), .pushUp)
        #expect(both.findings.map(\.check) == [.pushUpHipsSag, .pushUpDepth])
        #expect(both.notes.first?.hasPrefix("Your elbows stayed at about") == true)
    }

    @Test func pushUpFromAnAngleSaysItNeedsTheSide() throws {
        let frames = pushUps(sag: 0.4, bottomElbow: 85).map { $0.with(deviation: 50) }
        let analysis = try measured(frames, .pushUp)
        let review = FormChecks.review(analysis, frames: frames, definition: .pushUp)
        #expect(review.findings.isEmpty)
        #expect(review.notes.first?.hasPrefix("Finn checks push-up form from the side only.") == true)
    }

    // MARK: Lunge and stiff-leg deadlift

    @Test func cleanLungesAndHingesGetNoAdvice() throws {
        #expect(try reviewed(lunges(bottomKnee: 95, lean: 5), .staticLunge).findings.isEmpty)
        #expect(try reviewed(hinges(kneeBend: 10, torsoAtBottom: 85), .stiffLegDeadlift).findings.isEmpty)
    }

    @Test func lungeFaultsGetTheirOwnAdvice() throws {
        #expect(try reviewed(lunges(bottomKnee: 128, lean: 5), .staticLunge).findings.map(\.check) == [.lungeFrontKnee])
        #expect(try reviewed(lunges(bottomKnee: 95, lean: 35), .staticLunge).findings.map(\.check) == [.lungeTorsoLean])
    }

    @Test func hingeFaultsGetTheirOwnAdvice() throws {
        #expect(try reviewed(hinges(kneeBend: 45, torsoAtBottom: 85), .stiffLegDeadlift).findings.map(\.check)
            == [.deadliftKneeBend])
        #expect(try reviewed(hinges(kneeBend: 10, torsoAtBottom: 45), .stiffLegDeadlift).findings.map(\.check)
            == [.deadliftHinge])
    }

    // MARK: Generated motion and the live set

    /// The debug motion generator's clean squats and push-ups (random bodies, depths, a camera up
    /// to 10° off the side) never get form advice.
    @Test func generatedCleanSetsGetNoAdvice() {
        var generator = SyntheticRandom(seed: 42)
        var measuredSets = 0
        for label in ["squat", "push_up"] {
            let definition = label == "squat" ? ExerciseDefinition.squat : .pushUp
            for _ in 0..<12 {
                var settings = SyntheticExerciseMotion.Settings()
                settings.maximumYawDegrees = 10
                settings.repDepth = 0.95...1.0
                let frames = SyntheticExerciseMotion.sequence(label: label, settings: settings, using: &generator)
                guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: definition),
                      analysis.reps.count >= 3 else { continue }
                measuredSets += 1
                let review = FormChecks.review(analysis, frames: frames, definition: definition)
                #expect(review.findings.isEmpty, "\(label): \(review.findings.map(\.observation))")
            }
        }
        #expect(measuredSets >= 8)
    }

    @Test func liveSetSaysTheFaultFromItsSecondRep() {
        var monitor = LiveSetMonitor(definition: .pushUp)
        var events: [LiveSetEvent] = []
        let frames = pushUps(sag: 0.4, bottomElbow: 85)
        for end in frames.indices { events += monitor.update(with: Array(frames[...end])) }
        let faults = events.compactMap { event -> (FormCheck, Int)? in
            if case .formFault(let check, let rep) = event { return (check, rep) }
            return nil
        }
        #expect(faults.first?.0 == .pushUpHipsSag)
        #expect(faults.first?.1 == 2)
        // Said again at most every `cueSpacing` reps.
        #expect(faults.map(\.1) == [2, 5])
        #expect(LiveSetEvent.formFault(.pushUpHipsSag, rep: 2).caption(for: .pushUp) == "Lift your hips")
        #expect(LiveSetEvent.phrase(for: [.repCounted(2), .formFault(.pushUpHipsSag, rep: 2)],
                                    definition: .pushUp) == "2. Lift your hips")

        var clean = LiveSetMonitor(definition: .pushUp)
        let cleanFrames = pushUps(sag: 0, bottomElbow: 85)
        var cleanEvents: [LiveSetEvent] = []
        for end in cleanFrames.indices { cleanEvents += clean.update(with: Array(cleanFrames[...end])) }
// the live count analyses every 0.4 s of frames; the trace ends before the last rep is read.
        #expect(clean.countedReps >= 5)
        #expect(!cleanEvents.contains { if case .formFault = $0 { true } else { false } })
    }

    @Test func formFaultIsRememberedForTheFrequentPattern() throws {
        let analysis = try measured(squats(thighAtBottom: 45, extraLean: 5), .squat)
        let review = FormChecks.review(analysis, frames: squats(thighAtBottom: 45, extraLean: 5), definition: .squat)
        let issues = SetIssue.issues(diagnostics: nil, cue: nil, findings: review.findings, spedUp: false)
        #expect(issues == [.squatDepth])
        #expect(SetIssue.squatDepth.title(for: .squat) == "Hips staying above your knees")
        #expect(SetIssue.squatDepth.focus(for: .squat) == FormCheck.squatDepth.nextAction)
    }

    // MARK: Synthetic side views

    private func reviewed(_ frames: [PoseFrame], _ definition: ExerciseDefinition) throws -> FormReview {
        let analysis = try measured(frames, definition)
        #expect(analysis.reps.count == 6)
        return FormChecks.review(analysis, frames: frames, definition: definition)
    }

    private func measured(_ frames: [PoseFrame], _ definition: ExerciseDefinition) throws -> SetAnalysis {
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: definition, viewCheck: .ignore) else {
            Issue.record("Expected a measured set")
            throw TraceError.notMeasured
        }
        return analysis
    }

    private func point(_ x: Double, _ y: Double, _ confidence: Double = 0.95) -> JointPoint {
        JointPoint(x: x, y: y, confidence: confidence)
    }

    /// Both sides at the same place, the far one less sure, as Vision sees a side view.
    private func bothSides(_ near: [JointRole: (Double, Double)]) -> [BodyJoint: JointPoint] {
        var joints: [BodyJoint: JointPoint] = [:]
        for (role, position) in near {
            joints[role.joint(on: .left)] = point(position.0, position.1)
            joints[role.joint(on: .right)] = point(position.0 + 0.01, position.1, 0.4)
        }
        return joints
    }

    /// Depth 0 is standing, 1 the bottom of the rep, with a smooth rise and fall over 20 frames.
    private func depth(_ index: Int) -> Double { (1 - cos(2 * .pi * Double(index % 20) / 20)) / 2 }

    /// Squats with the shins tilting 35° forward at the bottom, the thighs `thighAtBottom` degrees
    /// above level, and the torso `extraLean` degrees beyond the shins.
    private func squats(thighAtBottom: Double, extraLean: Double, faultyRep: Int? = nil,
                        faultyThigh: Double = 0) -> [PoseFrame] {
        (0...120).map { index in
            let thigh = index / 20 == faultyRep ? faultyThigh : thighAtBottom
            return squatFrame(depth: depth(index), thighAtBottom: thigh, extraLean: extraLean, time: Double(index) * 0.1)
        }
    }

    private func squatFrame(depth s: Double, thighAtBottom: Double, extraLean: Double, time: Double) -> PoseFrame {
        let radians = Double.pi / 180
        let ankle = (0.50, 0.90)
        let shin = 35 * s * radians
        let knee = (ankle.0 + 0.2 * sin(shin), ankle.1 - 0.2 * cos(shin))
        let thigh = (90 - (90 - thighAtBottom) * s) * radians
        let hip = (knee.0 - 0.2 * cos(thigh), knee.1 - 0.2 * sin(thigh))
        let lean = (35 + extraLean) * s * radians
        let shoulder = (hip.0 + 0.25 * sin(lean), hip.1 - 0.25 * cos(lean))
        return PoseFrame(time: time, subjectCount: 1, joints: bothSides([
            .ankle: ankle, .knee: knee, .hip: hip, .shoulder: shoulder,
            .elbow: (shoulder.0 + 0.05, shoulder.1 + 0.12), .wrist: (shoulder.0 + 0.15, shoulder.1 + 0.12),
        ]))
    }

    /// Push-ups from the side: hands planted, the elbow closing from 170° to `bottomElbow`, the hips
    /// `sag` torso lengths below the shoulder-to-ankle line (negative: above it).
    private func pushUps(sag: Double, bottomElbow: Double) -> [PoseFrame] {
        (0...120).map { index in
            let elbowAngle = (170 - (170 - bottomElbow) * depth(index)) * .pi / 180
            let wrist = (0.30, 0.80)
            let elbow = (0.30, 0.66)
            let shoulder = (elbow.0 + 0.14 * sin(elbowAngle), elbow.1 + 0.14 * cos(elbowAngle))
            let ankle = (0.95, 0.80)
            let line = (ankle.0 - shoulder.0, ankle.1 - shoulder.1)
            let length = hypot(line.0, line.1)
            var normal = (-line.1 / length, line.0 / length)
            if normal.1 < 0 { normal = (-normal.0, -normal.1) }
            let torso = 0.45 * length
            let hip = (shoulder.0 + 0.45 * line.0 + normal.0 * sag * torso,
                       shoulder.1 + 0.45 * line.1 + normal.1 * sag * torso)
            let knee = (shoulder.0 + 0.72 * line.0 + normal.0 * sag * torso * 0.5,
                        shoulder.1 + 0.72 * line.1 + normal.1 * sag * torso * 0.5)
            return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: bothSides([
                .wrist: wrist, .elbow: elbow, .shoulder: shoulder, .hip: hip, .knee: knee, .ankle: ankle,
            ]))
        }
    }

    /// Static lunges from the side: front shin upright, the front knee closing from 172° to
    /// `bottomKnee`, the torso leaning `lean` degrees forward at the bottom. The back leg is hidden.
    private func lunges(bottomKnee: Double, lean: Double) -> [PoseFrame] {
        (0...120).map { index in
            let s = depth(index)
            let kneeAngle = (172 - (172 - bottomKnee) * s) * .pi / 180
            let ankle = (0.45, 0.90)
            let knee = (0.45, 0.70)
            let hip = (knee.0 + 0.2 * sin(kneeAngle), knee.1 + 0.2 * cos(kneeAngle))
            let tilt = lean * s * .pi / 180
            let shoulder = (hip.0 + 0.25 * sin(tilt), hip.1 - 0.25 * cos(tilt))
            return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: [
                .rightAnkle: point(ankle.0, ankle.1), .rightKnee: point(knee.0, knee.1),
                .rightHip: point(hip.0, hip.1), .rightShoulder: point(shoulder.0, shoulder.1),
            ])
        }
    }

    /// Stiff-leg deadlifts from the side over 25 frames a rep: the torso tipping from upright to
    /// `torsoAtBottom` degrees, the knees bending `kneeBend` degrees at the bottom.
    private func hinges(kneeBend: Double, torsoAtBottom: Double) -> [PoseFrame] {
        (0...150).map { index in
            let s = (1 - cos(2 * .pi * Double(index % 25) / 25)) / 2
            let ankle = (0.50, 0.90)
            let hip = (0.50, 0.55)
// the knee moves forward until the hip-knee-ankle angle has closed by `kneeBend`.
            let knee = (0.50 + 0.175 * tan(kneeBend / 2 * s * .pi / 180), 0.725)
            let tilt = (5 + (torsoAtBottom - 5) * s) * .pi / 180
            let shoulder = (hip.0 + 0.3 * sin(tilt), hip.1 - 0.3 * cos(tilt))
            return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: bothSides([
                .ankle: ankle, .knee: knee, .hip: hip, .shoulder: shoulder,
                .elbow: (shoulder.0, shoulder.1 + 0.12), .wrist: (shoulder.0, shoulder.1 + 0.24),
            ]))
        }
    }
}

private extension PoseFrame {
    func with(joints: [BodyJoint: JointPoint]) -> PoseFrame {
        PoseFrame(time: time, subjectCount: subjectCount, joints: joints, aspectRatio: aspectRatio,
                  profileDeviationDegrees: profileDeviationDegrees)
    }

    func with(deviation: Double) -> PoseFrame {
        PoseFrame(time: time, subjectCount: subjectCount, joints: joints, aspectRatio: aspectRatio,
                  profileDeviationDegrees: deviation)
    }
}
