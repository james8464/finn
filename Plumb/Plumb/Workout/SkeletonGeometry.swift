import CoreGraphics
import Foundation

/// Where to draw a pose over the camera picture: bones, joints, and the angle at the joint the
/// exercise is measured at. Coordinates are in the view showing the picture with aspect fit.
nonisolated struct SkeletonGeometry: Equatable {
    struct Joint: Equatable {
        let joint: BodyJoint
        let point: CGPoint
        /// Confident enough for the analysis to use (`EvidenceRubric.minimumJointConfidence`).
        let reliable: Bool
    }

    struct Bone: Equatable {
        let from: CGPoint
        let to: CGPoint
        let reliable: Bool
    }

    struct AngleLabel: Equatable {
        let vertex: CGPoint
        let degrees: Int
        let text: String
        let reliable: Bool
    }

    let joints: [Joint]
    let bones: [Bone]
    let angle: AngleLabel?
    /// Other people, drawn greyed out: Plumb ignores them.
    let bystanderBones: [Bone]
    let bystanderJoints: [CGPoint]

    static let boneList: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    init(frame: PoseFrame, exercise: ExerciseDefinition, size: CGSize, mirrored: Bool) {
        let rect = Self.imageRect(aspectRatio: frame.aspectRatio, in: size)
        func place(_ point: JointPoint) -> CGPoint {
            Self.viewPoint(x: point.x, y: point.y, in: rect, mirrored: mirrored)
        }
        func reliable(_ point: JointPoint) -> Bool {
            point.confidence >= EvidenceRubric.minimumJointConfidence
        }
        joints = frame.joints
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { Joint(joint: $0.key, point: place($0.value), reliable: reliable($0.value)) }
        bones = Self.bones(of: frame.joints, place: place)
        let others = frame.bystanders ?? []
        bystanderBones = others.flatMap { Self.bones(of: $0, place: place) }
        bystanderJoints = others.flatMap { person in
            person.values.filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }.map(place)
        }

        let roles = exercise.displayedAngle
        let side = Self.trackedSide(frame, roles: [roles.from, roles.vertex, roles.to])
        if let from = frame.joints[roles.from.joint(on: side)],
           let vertex = frame.joints[roles.vertex.joint(on: side)],
           let to = frame.joints[roles.to.joint(on: side)],
           let degrees = ExerciseAnalyzer.angle(from: from, vertex: vertex, to: to,
                                                aspectRatio: frame.aspectRatio) {
            let rounded = Int(degrees.rounded())
            angle = AngleLabel(vertex: place(vertex), degrees: rounded,
                               text: "\(roles.vertex.rawValue.capitalized) \(rounded)°",
                               reliable: reliable(from) && reliable(vertex) && reliable(to))
        } else {
            angle = nil
        }
    }

    private static func bones(of joints: [BodyJoint: JointPoint],
                              place: (JointPoint) -> CGPoint) -> [Bone] {
        boneList.compactMap { pair in
            guard let a = joints[pair.0], let b = joints[pair.1] else { return nil }
            let reliable = a.confidence >= EvidenceRubric.minimumJointConfidence
                && b.confidence >= EvidenceRubric.minimumJointConfidence
            return Bone(from: place(a), to: place(b), reliable: reliable)
        }
    }

    /// The rectangle a frame with this height-to-width ratio fills when fitted inside `size`.
    static func imageRect(aspectRatio: Double, in size: CGSize) -> CGRect {
        guard aspectRatio > 0, size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let width = min(size.width, size.height / aspectRatio)
        let height = width * aspectRatio
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                      width: width, height: height)
    }

    /// A normalized point (top-left origin) placed in `rect`, flipped left to right when the
    /// picture is shown mirrored.
    static func viewPoint(x: Double, y: Double, in rect: CGRect, mirrored: Bool) -> CGPoint {
        CGPoint(x: rect.minX + (mirrored ? 1 - x : x) * rect.width, y: rect.minY + y * rect.height)
    }

    /// The side whose measured joints Vision is surer of in this frame.
    static func trackedSide(_ frame: PoseFrame, roles: [JointRole]) -> BodySide {
        func total(_ side: BodySide) -> Double {
            roles.reduce(0) { $0 + (frame.joints[$1.joint(on: side)]?.confidence ?? 0) }
        }
        return total(.right) > total(.left) ? .right : .left
    }

    /// A short description for VoiceOver and UI tests.
    var summary: String {
        let reliableCount = joints.filter(\.reliable).count
        var parts = ["\(joints.count) joints", "\(reliableCount) clear"]
        if let angle { parts.append(angle.text) }
        if !bystanderBones.isEmpty || !bystanderJoints.isEmpty { parts.append("other people ignored") }
        return parts.joined(separator: ", ")
    }
}

nonisolated extension ExerciseDefinition {
    /// The joint angle shown on the camera picture. Squat depth is measured from hip travel,
    /// but the knee angle is what a person checks, so the squat shows the knee.
    var displayedAngle: (from: JointRole, vertex: JointRole, to: JointRole) {
        switch signal {
        case .jointBend(let from, let vertex, let to): (from, vertex, to)
        case .verticalTravel: (.hip, .knee, .ankle)
        }
    }
}
