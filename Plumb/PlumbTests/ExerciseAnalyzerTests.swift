import Foundation
import Testing
@testable import Plumb

struct ExerciseAnalyzerTests {
    // MARK: Squat stays identical

    @Test func squatThroughGenericEngineMatchesFrozenSquatV2OnVariedTraces() {
        var generator = SplitMix64(seed: 20261012)
        var measured = 0
        var abstained = 0
        for _ in 0..<600 {
            let frames = randomSquatTrace(using: &generator)
            let current = SquatAnalyzer.analyze(frames)
            let frozen = FrozenSquatV2.analyze(frames)
            #expect(current == frozen)
            if case .analyzed(let analysis) = current, !analysis.reps.isEmpty { measured += 1 }
            if case .insufficientView = current { abstained += 1 }
        }
        // The traces must exercise both paths, or the comparison proves little.
        #expect(measured > 120)
        #expect(abstained > 60)
    }

    @Test func squatDefinitionKeepsSquatV2Values() {
        let squat = ExerciseDefinition.squat
        #expect(squat.rubricVersion == "squat-side-v2")
        #expect(squat.signal == .verticalTravel(joint: .hip, reference: .ankle))
        #expect(squat.evidence == EvidenceRequirement(joints: [.hip, .knee, .ankle], anchor: .ankle))
        #expect(squat.phases == RepPhases(leaveTop: 0.10, reachBottom: 0.15, returnFromBottom: 0.04,
                                          backAtTop: 0.03, minimumDuration: 0.8, maximumDuration: 8.0))
        #expect(squat.minimumBodyScale == 0.1)
        #expect(squat.copy.observation == "Your range became shorter in the last two reps.")
        #expect(squat.copy.nextAction == "Try a pace you can keep consistent.")
    }

    // MARK: Definitions are consistent data

    @Test func everyExerciseHasOneConsistentDefinition() {
        #expect(ExerciseDefinition.all.map(\.kind) == ExerciseKind.allCases)
        #expect(Set(ExerciseDefinition.all.map(\.rubricVersion)).count == ExerciseDefinition.all.count)
        #expect(Set(ExerciseDefinition.all.map(\.classifierLabel)).count == ExerciseDefinition.all.count)
        for definition in ExerciseDefinition.all {
            #expect(ExerciseDefinition.definition(for: definition.kind) == definition)
            #expect(ExerciseDefinition.definition(forClassifierLabel: definition.classifierLabel) == definition)
            #expect(definition.expectedView == .side)
            for joint in definition.signal.joints + [definition.evidence.anchor] {
                #expect(definition.evidence.joints.contains(joint),
                        "\(definition.kind) must require \(joint) to measure it")
            }
            let phases = definition.phases
            #expect(phases.backAtTop < phases.leaveTop)
            #expect(phases.leaveTop < phases.reachBottom)
            #expect(phases.returnFromBottom > 0)
            #expect(phases.minimumDuration < phases.maximumDuration)
        }
    }

    @Test func angleUsesImageAspectRatio() throws {
        // A right angle in pixels on a 720 × 1280 portrait frame.
        let aspect = 1280.0 / 720.0
        let shoulder = JointPoint(x: 0.5, y: 0.5 - 0.1 / aspect, confidence: 1)
        let elbow = JointPoint(x: 0.5, y: 0.5, confidence: 1)
        let wrist = JointPoint(x: 0.6, y: 0.5, confidence: 1)
        let corrected = try #require(ExerciseAnalyzer.angle(from: shoulder, vertex: elbow, to: wrist,
                                                            aspectRatio: aspect))
        #expect(abs(corrected - 90) < 0.001)
        let skewed = try #require(ExerciseAnalyzer.angle(
            from: JointPoint(x: 0.4, y: 0.4, confidence: 1), vertex: elbow, to: wrist, aspectRatio: aspect))
        #expect(abs(skewed - 90) > 5)
    }

    // MARK: Push-up

    @Test func pushUpCountsSixElbowBendReps() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(pushUpTrace(reps: 6), as: .pushUp))
        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == "push-up-side-v1")
        #expect(analysis.reps.map(\.number) == [1, 2, 3, 4, 5, 6])
        #expect(analysis.reps.allSatisfy { $0.relativeRange > 75 && $0.relativeRange < 95 })
        #expect(analysis.reps.allSatisfy { $0.duration > 1.0 && $0.duration < 2.1 })
    }

    @Test func pushUpOnPortraitFrameUsesPixelAngles() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(
            pushUpTrace(reps: 5, aspectRatio: 1280.0 / 720.0), as: .pushUp))
        #expect(analysis.reps.count == 5)
        #expect(analysis.reps.allSatisfy { $0.relativeRange > 75 && $0.relativeRange < 95 })
    }

    @Test func pushUpIgnoresIncompleteFinalRepAndShallowBends() throws {
        var frames = pushUpTrace(reps: 4)
        frames += pushUpTrace(reps: 1, startTime: 8.1).filter { $0.time <= 9.0 }
        let analysis = try measured(ExerciseAnalyzer.analyze(frames, as: .pushUp))
        #expect(analysis.reps.count == 4)

        let shallow = try measured(ExerciseAnalyzer.analyze(pushUpTrace(reps: 6, bend: 30), as: .pushUp))
        #expect(shallow.reps.isEmpty)
    }

    @Test func pushUpWithoutVisibleWristAbstains() {
        let frames = pushUpTrace(reps: 6).map { frame in
            PoseFrame(time: frame.time, subjectCount: 1, joints: frame.joints.filter {
                $0.key != .leftWrist && $0.key != .rightWrist
            })
        }
        guard case .insufficientView = ExerciseAnalyzer.analyze(frames, as: .pushUp) else {
            Issue.record("A push-up without wrists must not be measured")
            return
        }
    }

    @Test func squatAnalyzedAsPushUpAbstains() {
        let squatOnlyLegs = (0...120).map { index in
            squatFrame(time: Double(index) * 0.1,
                       hipY: 0.42 + 0.2 * (1 - cos(2 * .pi * Double(index % 20) / 20)) / 2)
        }
        guard case .insufficientView = ExerciseAnalyzer.analyze(squatOnlyLegs, as: .pushUp) else {
            Issue.record("Leg-only frames cannot support an elbow measurement")
            return
        }
    }

    @Test func pushUpLateSetCueUsesPushUpWording() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(
            pushUpTrace(reps: 6, lateBend: 55), as: .pushUp))
        let cue = try #require(CueSelector.select(from: analysis, exercise: .pushUp))
        #expect(cue.repNumbers == [5, 6])
        #expect(cue.observation == "Your elbow bend became smaller in the last two reps.")
        #expect(cue.laterMedian < cue.earlierMedian)
    }

    @Test func pushUpRequiresStillHands() {
        let frames = pushUpTrace(reps: 6).enumerated().map { index, frame in
            let drift = Double(index) * 0.002
            return PoseFrame(time: frame.time, subjectCount: 1,
                             joints: frame.joints.mapValues {
                                 JointPoint(x: $0.x + drift, y: $0.y, confidence: $0.confidence)
                             })
        }
        #expect(EvidenceGate.assess(frames, requirement: ExerciseDefinition.pushUp.evidence)
                == .reject(.unstableFraming))
    }

    // MARK: Static lunge and stiff-leg deadlift

    @Test func staticLungeCountsKneeBendReps() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(lungeTrace(reps: 6), as: .staticLunge))
        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == "static-lunge-side-v1")
        #expect(analysis.reps.allSatisfy { $0.relativeRange > 60 && $0.relativeRange < 80 })
    }

    @Test func staticLungeStandingStillHasNoReps() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(lungeTrace(reps: 6, bend: 0),
                                                             as: .staticLunge))
        #expect(analysis.reps.isEmpty)
    }

    @Test func stiffLegDeadliftCountsHipHingeReps() throws {
        let analysis = try measured(ExerciseAnalyzer.analyze(hingeTrace(reps: 5),
                                                             as: .stiffLegDeadlift))
        #expect(analysis.reps.count == 5)
        #expect(analysis.rubricVersion == "stiff-leg-deadlift-side-v1")
        #expect(analysis.reps.allSatisfy { $0.relativeRange > 65 && $0.relativeRange < 85 })
        #expect(analysis.reps.allSatisfy { $0.duration > 1.4 && $0.duration < 2.6 })
    }

    @Test func stiffLegDeadliftNeedsShoulderInView() {
        let frames = hingeTrace(reps: 5).map { frame in
            PoseFrame(time: frame.time, subjectCount: 1, joints: frame.joints.filter {
                $0.key != .leftShoulder && $0.key != .rightShoulder
            })
        }
        guard case .insufficientView = ExerciseAnalyzer.analyze(frames, as: .stiffLegDeadlift) else {
            Issue.record("A hinge without a visible shoulder must not be measured")
            return
        }
    }

    @Test func bystanderAndTrackingRulesApplyToEveryExercise() {
        let crowded = pushUpTrace(reps: 6).map {
            PoseFrame(time: $0.time, subjectCount: 2, joints: $0.joints)
        }
        #expect(ExerciseAnalyzer.analyze(crowded, as: .pushUp) == .insufficientView(
            "Another person was in view. Keep only yourself in frame and try again."))
        let gap = hingeTrace(reps: 5).enumerated().map { index, frame in
            (40...50).contains(index) ? PoseFrame(time: frame.time, subjectCount: 1, joints: [:]) : frame
        }
        #expect(ExerciseAnalyzer.analyze(gap, as: .stiffLegDeadlift) == .insufficientView(
            "Tracking was lost during the set. Keep your whole body visible and try again."))
    }

    // MARK: History compatibility

    @Test func repRangeKeepsSavedHistoryKey() throws {
        let rep = RepMetric(number: 1, startTime: 0, endTime: 2, relativeRange: 0.4)
        let json = try #require(String(data: JSONEncoder().encode(rep), encoding: .utf8))
        #expect(json.contains("\"normalizedHipTravel\""))
        let legacy = Data(#"{"number":2,"startTime":1,"endTime":3,"normalizedHipTravel":0.35}"#.utf8)
        let decoded = try JSONDecoder().decode(RepMetric.self, from: legacy)
        #expect(decoded.relativeRange == 0.35)
        #expect(decoded.normalizedHipTravel == 0.35)
    }

    @Test func historySavedBySquatOnlyBuildStillDecodes() throws {
        let saved = Data("""
            {"id":"00000000-0000-0000-0000-000000000001","sessionID":"00000000-0000-0000-0000-000000000002",
             "capturedAt":782000000,"bodySide":"left","cueResponse":"unanswered",
             "exercise":"bodyweightSquat","cameraView":"side",
             "analysis":{"confidence":0.9,"rubricVersion":"squat-side-v2",
               "reps":[{"number":1,"startTime":0,"endTime":2,"normalizedHipTravel":0.4}]}}
            """.utf8)
        let decoded = try JSONDecoder().decode(SetSummary.self, from: saved)
        #expect(decoded.exercise == .bodyweightSquat)
        #expect(decoded.analysis.reps.first?.relativeRange == 0.4)
    }

    // MARK: Helpers

    private func measured(_ outcome: AnalysisOutcome) throws -> SetAnalysis {
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set, got \(outcome)")
            throw TraceError.notMeasured
        }
        return analysis
    }
}

enum TraceError: Error { case notMeasured }

// MARK: - Synthetic side-view traces

/// Side-view push-up: wrists planted, forearm vertical, the elbow angle closes by `bend` degrees.
func pushUpTrace(reps: Int, startTime: Double = 0, bend: Double = 90, lateBend: Double? = nil,
                 aspectRatio: Double = 1) -> [PoseFrame] {
    (0...(reps * 20)).map { index in
        let repIndex = index / 20
        let depth = repIndex >= reps - 2 ? (lateBend ?? bend) : bend
        let phase = Double(index % 20) / 20
        let elbowAngle = (170 - depth * (1 - cos(2 * .pi * phase)) / 2) * .pi / 180
        // Positions in width units, then y divided by the aspect ratio for normalized coordinates.
        let wrist = (x: 0.30, y: 0.80)
        let elbow = (x: wrist.x, y: wrist.y - 0.14)
        let shoulder = (x: elbow.x + 0.14 * sin(elbowAngle), y: elbow.y + 0.14 * cos(elbowAngle))
        let hip = (x: shoulder.x + 0.25, y: shoulder.y + 0.03)
        let ankle = (x: 0.85, y: 0.80)
        func point(_ p: (x: Double, y: Double)) -> JointPoint {
            JointPoint(x: p.x, y: 0.1 + (p.y - 0.1) / aspectRatio, confidence: 0.95)
        }
        let joints: [BodyJoint: JointPoint] = [
            .leftWrist: point(wrist), .leftElbow: point(elbow), .leftShoulder: point(shoulder),
            .leftHip: point(hip), .leftKnee: point((x: (hip.x + ankle.x) / 2, y: (hip.y + ankle.y) / 2)),
            .leftAnkle: point(ankle),
        ]
        return PoseFrame(time: startTime + Double(index) * 0.1, subjectCount: 1, joints: joints,
                         aspectRatio: aspectRatio)
    }
}

/// Side-view static lunge: ankle planted, shin vertical, the knee angle closes by `bend` degrees.
func lungeTrace(reps: Int, bend: Double = 75) -> [PoseFrame] {
    (0...(reps * 20)).map { index in
        let phase = Double(index % 20) / 20
        let kneeAngle = (172 - bend * (1 - cos(2 * .pi * phase)) / 2) * .pi / 180
        let ankle = (x: 0.45, y: 0.90)
        let knee = (x: ankle.x, y: ankle.y - 0.2)
        let hip = (x: knee.x + 0.2 * sin(kneeAngle), y: knee.y + 0.2 * cos(kneeAngle))
        let shoulder = (x: hip.x, y: hip.y - 0.25)
        let joints: [BodyJoint: JointPoint] = [
            .rightAnkle: JointPoint(x: ankle.x, y: ankle.y, confidence: 0.9),
            .rightKnee: JointPoint(x: knee.x, y: knee.y, confidence: 0.9),
            .rightHip: JointPoint(x: hip.x, y: hip.y, confidence: 0.9),
            .rightShoulder: JointPoint(x: shoulder.x, y: shoulder.y, confidence: 0.9),
        ]
        return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: joints)
    }
}

/// Side-view stiff-leg deadlift: legs still, the shoulder-hip-knee angle closes by `bend` degrees.
func hingeTrace(reps: Int, bend: Double = 80) -> [PoseFrame] {
    (0...(reps * 25)).map { index in
        let phase = Double(index % 25) / 25
        let hipAngle = (175 - bend * (1 - cos(2 * .pi * phase)) / 2) * .pi / 180
        let ankle = (x: 0.50, y: 0.90)
        let knee = (x: 0.50, y: 0.72)
        let hip = (x: 0.50, y: 0.55)
        let shoulder = (x: hip.x + 0.3 * sin(hipAngle), y: hip.y + 0.3 * cos(hipAngle))
        let joints: [BodyJoint: JointPoint] = [
            .leftAnkle: JointPoint(x: ankle.x, y: ankle.y, confidence: 0.9),
            .leftKnee: JointPoint(x: knee.x, y: knee.y, confidence: 0.9),
            .leftHip: JointPoint(x: hip.x, y: hip.y, confidence: 0.9),
            .leftShoulder: JointPoint(x: shoulder.x, y: shoulder.y, confidence: 0.9),
            .leftElbow: JointPoint(x: shoulder.x, y: shoulder.y + 0.12, confidence: 0.9),
            .leftWrist: JointPoint(x: shoulder.x, y: shoulder.y + 0.24, confidence: 0.9),
        ]
        return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: joints)
    }
}

func squatFrame(time: Double, hipY: Double, confidence: Double = 0.99, subjectCount: Int = 1,
                ankleShift: Double = 0) -> PoseFrame {
    PoseFrame(time: time, subjectCount: subjectCount, joints: [
        .leftHip: JointPoint(x: 0.47, y: hipY, confidence: confidence),
        .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: confidence),
        .leftAnkle: JointPoint(x: 0.51 + ankleShift, y: 0.90, confidence: confidence),
        .rightHip: JointPoint(x: 0.53, y: hipY, confidence: confidence),
        .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: confidence),
        .rightAnkle: JointPoint(x: 0.57 + ankleShift, y: 0.90, confidence: confidence),
    ])
}

/// Squat traces with varied depth, tempo, noise, dropped frames, low confidence, bystanders,
/// tracking gaps, drift, and partial reps, so both measured and abstaining paths are compared.
private func randomSquatTrace(using generator: inout SplitMix64) -> [PoseFrame] {
    let reps = Int.random(in: 0...8, using: &generator)
    let framesPerRep = Int.random(in: 8...40, using: &generator)
    let step = [0.0667, 0.1, 0.125].randomElement(using: &generator)!
    // Each disturbance is present in only some traces, so many sets still reach the rep counter.
    func sometimes(_ chance: Double, _ value: () -> Double) -> Double {
        Double.random(in: 0..<1, using: &generator) < chance ? value() : 0
    }
    let amplitude = Double.random(in: 0.02...0.32, using: &generator)
    let fadeLastTwo = Bool.random(using: &generator) ? Double.random(in: 0.5...1, using: &generator) : 1
    let noise = Double.random(in: 0...0.015, using: &generator)
    let dropRate = sometimes(0.4) { Double.random(in: 0...0.3, using: &generator) }
    let lowConfidenceRate = sometimes(0.3) { Double.random(in: 0...0.25, using: &generator) }
    let bystanderRate = sometimes(0.25) { Double.random(in: 0...0.12, using: &generator) }
    let gapStart = Double.random(in: 0..<1, using: &generator) < 0.3
        ? Int.random(in: 0...200, using: &generator) : -1
    let gapLength = Int.random(in: 1...14, using: &generator)
    let drift = sometimes(0.3) { Double.random(in: 0...0.002, using: &generator) }
    let partialTail = Int.random(in: 0...(framesPerRep - 1), using: &generator)
    let count = max(1, reps * framesPerRep + partialTail)
    var frames: [PoseFrame] = []
    for index in 0...count {
        if Double.random(in: 0..<1, using: &generator) < dropRate { continue }
        let time = Double(index) * step
        if index >= gapStart && index < gapStart + gapLength {
            frames.append(PoseFrame(time: time, subjectCount: 1, joints: [:]))
            continue
        }
        let repIndex = framesPerRep > 0 ? index / framesPerRep : 0
        let depth = repIndex >= reps - 2 ? amplitude * fadeLastTwo : amplitude
        let phase = Double(index % framesPerRep) / Double(framesPerRep)
        let hipY = 0.42 + depth * (1 - cos(2 * .pi * phase)) / 2
            + Double.random(in: -noise...noise, using: &generator)
        let confidence = Double.random(in: 0..<1, using: &generator) < lowConfidenceRate
            ? Double.random(in: 0.3..<0.6, using: &generator) : Double.random(in: 0.6...1, using: &generator)
        let subjects = Double.random(in: 0..<1, using: &generator) < bystanderRate ? 2 : 1
        frames.append(squatFrame(time: time, hipY: hipY, confidence: confidence,
                                 subjectCount: subjects, ankleShift: drift * Double(index)))
    }
    return frames
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Frozen squat-side-v2

/// Verbatim copy of the squat-only analyzer and evidence gate at commit 41f4ff3, with its
/// constants written out. The generic engine must reproduce it exactly for the squat.
private enum FrozenSquatV2 {
    private enum Phase {
        case standing
        case descending(start: TimeInterval, peak: Double)
        case ascending(start: TimeInterval, peak: Double)
    }

    private struct Sample {
        let time: TimeInterval
        let hipY: Double
        let ankleY: Double
        let confidence: Double
    }

    static func analyze(_ frames: [PoseFrame]) -> AnalysisOutcome {
        let side: BodySide
        switch assess(frames) {
        case .usable(let acceptedSide): side = acceptedSide
        case .reject(.multiplePeople):
            return .insufficientView("Another person was in view. Keep only yourself in frame and try again.")
        case .reject(.trackingGap):
            return .insufficientView("Tracking was lost during the set. Keep your whole body visible and try again.")
        case .reject:
            return .insufficientView("Move the phone so your full body stays visible.")
        }

        let joints: (BodyJoint, BodyJoint) = side == .left
            ? (.leftHip, .leftAnkle) : (.rightHip, .rightAnkle)
        let samples = frames.compactMap { sample(from: $0, side: joints) }
        guard samples.count >= 5 else {
            return .insufficientView("Keep your hip and ankle visible for the whole set.")
        }

        let opening = Array(samples.prefix(5))
        let standingHipY = median(opening.map(\.hipY))
        let ankleY = median(opening.map(\.ankleY))
        let standingLegLength = ankleY - standingHipY
        guard standingLegLength > 0.1 else {
            return .insufficientView("Move the phone back so your full body is visible.")
        }

        let hipPositions = samples.indices.map { index -> Double in
            let lower = max(0, index - 1)
            let upper = min(samples.count - 1, index + 1)
            let window = samples[lower...upper]
            return window.map(\.hipY).reduce(0, +) / Double(window.count)
        }

        var phase: Phase = .standing
        var lastStandingTime = samples[0].time
        var reps: [RepMetric] = []
        for (index, sample) in samples.enumerated() {
            let travel = max(0, (hipPositions[index] - standingHipY) / standingLegLength)
            switch phase {
            case .standing:
                if travel <= 0.03 { lastStandingTime = sample.time }
                if travel >= 0.10 { phase = .descending(start: lastStandingTime, peak: travel) }
            case .descending(let start, let peak):
                let updatedPeak = max(peak, travel)
                if updatedPeak >= 0.15 && updatedPeak - travel >= 0.04 {
                    phase = .ascending(start: start, peak: updatedPeak)
                } else {
                    phase = .descending(start: start, peak: updatedPeak)
                }
            case .ascending(let start, let peak):
                if travel <= 0.03 {
                    let duration = sample.time - start
                    if (0.8...8.0).contains(duration) {
                        reps.append(RepMetric(number: reps.count + 1, startTime: start,
                                              endTime: sample.time, normalizedHipTravel: peak))
                    }
                    phase = .standing
                }
            }
        }

        let confidence = samples.map(\.confidence).reduce(0, +) / Double(samples.count)
        return .analyzed(SetAnalysis(reps: reps, confidence: confidence, rubricVersion: "squat-side-v2"))
    }

    private static func assess(_ frames: [PoseFrame]) -> EvidenceAssessment {
        guard let first = frames.first, let last = frames.last, last.time - first.time >= 2 else {
            return .reject(.tooShort)
        }
        let bystanderFrames = frames.filter { $0.subjectCount > 1 }.count
        if Double(bystanderFrames) / Double(frames.count) > 0.2 { return .reject(.multiplePeople) }
        var bystanderStart: TimeInterval?
        for frame in frames {
            if frame.subjectCount > 1 && bystanderStart == nil { bystanderStart = frame.time }
            if let bystanderStart, frame.time - bystanderStart >= 0.35 { return .reject(.multiplePeople) }
            if frame.subjectCount == 1 { bystanderStart = nil }
        }
        let sides: [(BodySide, [BodyJoint])] = [
            (.left, [.leftHip, .leftKnee, .leftAnkle]),
            (.right, [.rightHip, .rightKnee, .rightAnkle]),
        ]
        let ranked = sides.map { side, joints in
            let complete = frames.filter { frame in joints.allSatisfy { frame.joints[$0] != nil } }
            let confident = complete.filter { frame in
                joints.allSatisfy { (frame.joints[$0]?.confidence ?? 0) >= 0.6 }
            }
            return (side: side, joints: joints, complete: complete.count, confident: confident.count)
        }.sorted { $0.confident > $1.confident }
        guard let best = ranked.first else { return .reject(.missingJoints) }
        let total = Double(frames.count)
        guard Double(best.complete) / total >= 0.8 else { return .reject(.missingJoints) }
        guard Double(best.confident) / total >= 0.8 else { return .reject(.lowConfidence) }
        var lastTrackedTime = first.time
        for frame in frames where frame.subjectCount == 1 && best.joints.allSatisfy({ joint in
            (frame.joints[joint]?.confidence ?? 0) >= 0.6
        }) {
            if frame.time - lastTrackedTime > 0.75 { return .reject(.trackingGap) }
            lastTrackedTime = frame.time
        }
        if last.time - lastTrackedTime > 0.75 { return .reject(.trackingGap) }
        let ankleJoint: BodyJoint = best.side == .left ? .leftAnkle : .rightAnkle
        let anklePoints = frames.compactMap { $0.joints[ankleJoint] }.filter { $0.confidence >= 0.6 }
        guard let minX = anklePoints.map(\.x).min(), let maxX = anklePoints.map(\.x).max(),
              let minY = anklePoints.map(\.y).min(), let maxY = anklePoints.map(\.y).max(),
              maxX - minX <= 0.08, maxY - minY <= 0.08 else {
            return .reject(.unstableFraming)
        }
        return .usable(best.side)
    }

    private static func sample(from frame: PoseFrame, side: (BodyJoint, BodyJoint)) -> Sample? {
        guard let hip = frame.joints[side.0], let ankle = frame.joints[side.1],
              hip.confidence >= 0.6, ankle.confidence >= 0.6 else { return nil }
        return Sample(time: frame.time, hipY: hip.y, ankleY: ankle.y,
                      confidence: min(hip.confidence, ankle.confidence))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
