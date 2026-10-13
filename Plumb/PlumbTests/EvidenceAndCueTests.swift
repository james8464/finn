import Testing
@testable import Plumb

struct EvidenceAndCueTests {
    @Test func acceptsClearSinglePersonSideView() {
        #expect(EvidenceGate.assess(clearTrace()) == .usable(.left))
    }

    @Test func rejectsMissingRequiredJoint() {
        let frames = clearTrace().map { frame in
            PoseFrame(time: frame.time, subjectCount: 1,
                      joints: frame.joints.filter { $0.key != .leftKnee && $0.key != .rightKnee })
        }
        #expect(EvidenceGate.assess(frames) == .reject(.missingJoints))
        guard case .insufficientView = SquatAnalyzer.analyze(frames) else {
            Issue.record("The analyzer must not count an unverified view")
            return
        }
    }

    @Test func rejectsLowJointConfidence() {
        let frames = clearTrace(confidence: 0.2)
        #expect(EvidenceGate.assess(frames) == .reject(.lowConfidence))
    }

    @Test func rejectedCoverageDoesNotDisplayThePassingThreshold() {
        let frames = clearTrace(sampleCount: 201).enumerated().map { index, frame in
            index < 160 ? frame : PoseFrame(time: frame.time, subjectCount: 1, joints: [:])
        }
        #expect(EvidenceGate.assess(frames) == .reject(.missingJoints))
        let explanation = EvidenceGate.explanation(for: .missingJoints, frames: frames)
        #expect(explanation.contains("79% of the set and needs 80%"))
    }

    @Test func rejectsProminentBystander() {
        let frames = clearTrace(subjectCount: 2)
        #expect(EvidenceGate.assess(frames) == .reject(.multiplePeople))
    }

    @Test func rejectsBriefSustainedBystanderInLongSet() {
        let frames = clearTrace(sampleCount: 101).enumerated().map { index, frame in
            (40...44).contains(index)
                ? PoseFrame(time: frame.time, subjectCount: 2, joints: frame.joints)
                : frame
        }
        #expect(EvidenceGate.assess(frames) == .reject(.multiplePeople))
        #expect(SquatAnalyzer.analyze(frames) == .insufficientView(
            "Another person was in view. Keep only yourself in frame and try again."
        ))
    }

    @Test func isolatedExtraPersonDetectionDoesNotDiscardSet() {
        let frames = clearTrace().enumerated().map { index, frame in
            index == 15 ? PoseFrame(time: frame.time, subjectCount: 2, joints: frame.joints) : frame
        }
        #expect(EvidenceGate.assess(frames) == .usable(.left))
    }

    @Test func noPersonIsNotReportedAsBystander() {
        let frames = clearTrace().map { frame in
            PoseFrame(time: frame.time, subjectCount: 0, joints: [:])
        }
        #expect(EvidenceGate.assess(frames) == .reject(.missingJoints))
    }

    @Test func rejectsShortTrace() {
        #expect(EvidenceGate.assess(Array(clearTrace().prefix(5))) == .reject(.tooShort))
    }

    @Test func rejectsLongTrackingLossDespiteHighOverallCoverage() {
        let frames = clearTrace(sampleCount: 101).enumerated().map { index, frame in
            (40...48).contains(index)
                ? PoseFrame(time: frame.time, subjectCount: 1, joints: [:])
                : frame
        }
        #expect(EvidenceGate.assess(frames).isRejected)
        guard case .insufficientView = SquatAnalyzer.analyze(frames) else {
            Issue.record("A tracking gap must not produce a measured set")
            return
        }
    }

    @Test func rejectsLongTrackingLossAtStart() {
        let frames = clearTrace(sampleCount: 101).enumerated().map { index, frame in
            index < 9 ? PoseFrame(time: frame.time, subjectCount: 1, joints: [:]) : frame
        }
        #expect(EvidenceGate.assess(frames) == .reject(.trackingGap))
    }

    @Test func rejectsLongTrackingLossAtEnd() {
        let frames = clearTrace(sampleCount: 101).enumerated().map { index, frame in
            index > 91 ? PoseFrame(time: frame.time, subjectCount: 1, joints: [:]) : frame
        }
        #expect(EvidenceGate.assess(frames) == .reject(.trackingGap))
    }

    @Test func rejectsUnstableFraming() {
        let frames = clearTrace().enumerated().map { index, frame in
            let drift = Double(index) * 0.006
            let joints = frame.joints.mapValues { point in
                JointPoint(x: point.x + drift, y: point.y, confidence: point.confidence)
            }
            return PoseFrame(time: frame.time, subjectCount: 1, joints: joints)
        }
        #expect(EvidenceGate.assess(frames) == .reject(.unstableFraming))
    }

    @Test func stableRangeEmitsNoCue() {
        #expect(CueSelector.select(from: measuredSet([0.40, 0.41, 0.40, 0.39, 0.40, 0.40])) == nil)
    }

    @Test func laterShorterRangeCitesThoseReps() {
        let cue = CueSelector.select(from: measuredSet([0.42, 0.41, 0.41, 0.40, 0.31, 0.30]))
        #expect(cue?.kind == .rangeDecreased)
        #expect(cue?.repNumbers == [5, 6])
        #expect(cue?.earlierMedian == 0.415)
        #expect(cue?.laterMedian == 0.305)
    }

    @Test func tooFewRepsEmitNoCue() {
        #expect(CueSelector.select(from: measuredSet([0.42, 0.30, 0.25])) == nil)
    }

    private func clearTrace(confidence: Double = 0.99, subjectCount: Int = 1,
                            sampleCount: Int = 31) -> [PoseFrame] {
        (0..<sampleCount).map { index in
            PoseFrame(time: Double(index) * 0.1, subjectCount: subjectCount, joints: [
                .leftHip: JointPoint(x: 0.47, y: 0.42, confidence: confidence),
                .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: confidence),
                .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: confidence),
                .rightHip: JointPoint(x: 0.53, y: 0.42, confidence: confidence),
                .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: confidence),
                .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: confidence),
            ])
        }
    }

    private func measuredSet(_ ranges: [Double]) -> SetAnalysis {
        SetAnalysis(
            reps: ranges.enumerated().map { index, range in
                RepMetric(number: index + 1, startTime: Double(index) * 2,
                          endTime: Double(index + 1) * 2, normalizedHipTravel: range)
            },
            confidence: 0.95,
            rubricVersion: SquatRubric.version
        )
    }
}
