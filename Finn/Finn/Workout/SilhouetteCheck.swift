import Foundation

/// A person-segmentation mask in the frame's orientation: one byte per pixel, 0 for background,
/// 255 for a person, rows from the top. `PoseFrameAnalyzer` copies Vision's mask into it.
nonisolated struct PersonMask: Equatable {
    let width: Int
    let height: Int
    /// Row-major bytes, `width` per row.
    let pixels: [UInt8]

    init?(width: Int, height: Int, pixels: [UInt8]) {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func value(x: Int, y: Int) -> UInt8 { pixels[y * width + x] }
}

/// Checks the athlete's joints against the person mask, so a joint Vision guessed behind an
/// obstruction (an ankle behind a bench) is not measured. Vision's skeleton may estimate through an
/// obstruction with good confidence; the mask is independent image evidence.
///
/// The first version looked only two mask pixels around each joint. Vision's fast mask is coarse
/// (each pixel covers several image pixels) and thin at the hands and feet, so a visible ankle or
/// wrist on the silhouette's edge was often rejected and real sets were refused. The search radius
/// now follows the person's size, and a mask with nobody in it at all counts as no check rather
/// than as every joint being hidden.
nonisolated enum SilhouetteCheck {
    enum Verdict: Equatable {
        /// The mask was checked; these joints have person pixels at or near them.
        case checked(supported: Set<BodyJoint>)
        /// No usable mask (none, or nobody segmented at all): the joints keep their 2D evidence.
        case unavailable
    }

    /// Mask value from which a pixel counts as the person.
    static let personThreshold: UInt8 = 128
    /// Search radius around a joint, as a share of the athlete's body size (the diagonal of the box
    /// around their clear joints). About a hand's width on an adult.
    static let radiusShareOfBody = 0.04
    /// Smallest search radius in mask pixels, for the mask's own edge blur.
    static let minimumRadiusPixels = 2

    static func verdict(for joints: [BodyJoint: JointPoint], mask: PersonMask?) -> Verdict {
        guard let mask, !joints.isEmpty,
              mask.pixels.contains(where: { $0 >= personThreshold }) else { return .unavailable }
        let clear = joints.values.filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        let reference = clear.isEmpty ? Array(joints.values) : clear
        let xs = reference.map(\.x)
        let ys = reference.map(\.y)
        let bodyWidth = (xs.max() ?? 0) - (xs.min() ?? 0)
        let bodyHeight = (ys.max() ?? 0) - (ys.min() ?? 0)
        // In normalized units on each axis, so a non-square mask keeps the same physical radius.
        let radiusX = max(Int((radiusShareOfBody * hypot(bodyWidth, bodyHeight) * Double(mask.width)).rounded(.up)),
                          minimumRadiusPixels)
        let radiusY = max(Int((radiusShareOfBody * hypot(bodyWidth, bodyHeight) * Double(mask.height)).rounded(.up)),
                          minimumRadiusPixels)
        let supported = joints.filter { _, point in
            isPerson(near: point, in: mask, radiusX: radiusX, radiusY: radiusY)
        }
        return .checked(supported: Set(supported.keys))
    }

    private static func isPerson(near point: JointPoint, in mask: PersonMask, radiusX: Int, radiusY: Int) -> Bool {
        let x = min(mask.width - 1, max(0, Int(point.x * Double(mask.width))))
        let y = min(mask.height - 1, max(0, Int(point.y * Double(mask.height))))
        for yy in max(0, y - radiusY)...min(mask.height - 1, y + radiusY) {
            for xx in max(0, x - radiusX)...min(mask.width - 1, x + radiusX)
            where mask.value(x: xx, y: yy) >= personThreshold {
                return true
            }
        }
        return false
    }
}
