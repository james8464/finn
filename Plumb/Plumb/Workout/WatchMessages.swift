import Foundation

// the messages between Plumb on the iPhone and Plumb on Apple Watch. The watch target compiles this
// one file too, so it uses Foundation only and none of the iPhone's workout types. WatchConnectivity
// carries property-list dictionaries: strings, numbers and booleans here, and never nil.

/// the set's stage as the watch shows it
nonisolated enum WatchStage: String, CaseIterable, Equatable, Sendable {
    /// no camera open on the iPhone
    case ready
    /// the camera is open and the person is getting into position
    case framing
    case countdown
    /// the set is running
    case capturing
    /// the iPhone is reviewing the set
    case analyzing
    case result
}

/// the tap the watch plays when a state arrives live
nonisolated enum WatchHaptic: String, CaseIterable, Equatable, Sendable {
    case none
    /// a rep was counted
    case rep
    /// a live observation, such as a rep faster than the first ones
    case observation
    /// the set started
    case start
    /// the set ended
    case end
}

/// iPhone to watch: everything the watch screen shows. The iPhone sends the whole state each time,
/// so a lost or late message never leaves the watch stuck.
nonisolated struct WatchState: Equatable, Sendable {
    var stage: WatchStage = .ready
    /// seconds left in the countdown; 0 outside it
    var countdown = 0
    /// the exercise's name, such as "Squat"
    var exercise = ""
    /// reps counted so far while the set runs; reps measured once it is reviewed
    var reps = 0
    /// the latest live observation of the running set, measured on the iPhone
    var caption: String?
    var haptic: WatchHaptic = .none
    /// one line about the reviewed set
    var summary: String?
    /// whether Start set and Stop set are offered on the wrist for this exercise
    var wristControls = true
    /// whether the set starts and ends by itself (hands-free on the iPhone)
    var handsFree = false
    /// the iPhone is replaying demo input, not filming a person
    var demoInput = false
    /// the person turned on Personalize with Health: the watch runs a workout session while the
    /// camera is open and sends its heart rate back.
    var measuresHeartRate = false
    /// when the iPhone sent this state, in seconds since 1970. The watch keeps the newest.
    var sentAt = 0.0

    static let messageType = "state"
    /// a saved state older than this, in seconds, is not shown when the watch app opens
    static let staleAfter: TimeInterval = 600

    func message() -> [String: Any] {
        var message: [String: Any] = [
            WatchMessageKey.messageType: Self.messageType,
            WatchMessageKey.version: WatchMessageKey.currentVersion,
            WatchMessageKey.stage: stage.rawValue,
            WatchMessageKey.countdown: countdown,
            WatchMessageKey.exercise: exercise,
            WatchMessageKey.reps: reps,
            WatchMessageKey.haptic: haptic.rawValue,
            WatchMessageKey.wristControls: wristControls,
            WatchMessageKey.handsFree: handsFree,
            WatchMessageKey.demoInput: demoInput,
            WatchMessageKey.measuresHeartRate: measuresHeartRate,
            WatchMessageKey.sentAt: sentAt,
        ]
        if let caption { message[WatchMessageKey.caption] = caption }
        if let summary { message[WatchMessageKey.summary] = summary }
        return message
    }

    /// reads a state message; nil for anything else. Missing optional values take their defaults.
    init?(message: [String: Any]) {
        guard message[WatchMessageKey.messageType] as? String == Self.messageType,
              let rawStage = message[WatchMessageKey.stage] as? String,
              let stage = WatchStage(rawValue: rawStage) else { return nil }
        self.stage = stage
        countdown = WatchMessageKey.integer(message[WatchMessageKey.countdown]) ?? 0
        exercise = message[WatchMessageKey.exercise] as? String ?? ""
        reps = WatchMessageKey.integer(message[WatchMessageKey.reps]) ?? 0
        caption = message[WatchMessageKey.caption] as? String
        haptic = (message[WatchMessageKey.haptic] as? String).flatMap(WatchHaptic.init(rawValue:)) ?? .none
        summary = message[WatchMessageKey.summary] as? String
        wristControls = message[WatchMessageKey.wristControls] as? Bool ?? true
        handsFree = message[WatchMessageKey.handsFree] as? Bool ?? false
        demoInput = message[WatchMessageKey.demoInput] as? Bool ?? false
        measuresHeartRate = message[WatchMessageKey.measuresHeartRate] as? Bool ?? false
        sentAt = WatchMessageKey.number(message[WatchMessageKey.sentAt]) ?? 0
    }

    init(stage: WatchStage = .ready, countdown: Int = 0, exercise: String = "", reps: Int = 0,
         caption: String? = nil, haptic: WatchHaptic = .none, summary: String? = nil,
         wristControls: Bool = true, handsFree: Bool = false, demoInput: Bool = false,
         measuresHeartRate: Bool = false, sentAt: Double = 0) {
        self.stage = stage
        self.countdown = countdown
        self.exercise = exercise
        self.reps = reps
        self.caption = caption
        self.haptic = haptic
        self.summary = summary
        self.wristControls = wristControls
        self.handsFree = handsFree
        self.demoInput = demoInput
        self.measuresHeartRate = measuresHeartRate
        self.sentAt = sentAt
    }

    /// whether this state should replace `shown` on the watch. Only a newer one does, so a late
    /// application context never rewinds the screen and a repeated message never taps twice.
    func isNewer(than shown: WatchState?) -> Bool {
        guard let shown else { return true }
        return sentAt > shown.sentAt
    }

    /// a saved state from a while ago, such as a set the iPhone never finished telling the watch about
    func isStale(now: TimeInterval) -> Bool {
        now - sentAt > Self.staleAfter
    }
}

/// Watch to iPhone
nonisolated enum WatchCommand: String, CaseIterable, Equatable, Sendable {
    case startSet
    case stopSet

    static let messageType = "command"

    func message() -> [String: Any] {
        [WatchMessageKey.messageType: Self.messageType,
         WatchMessageKey.version: WatchMessageKey.currentVersion,
         WatchMessageKey.command: rawValue]
    }

    init?(message: [String: Any]) {
        guard message[WatchMessageKey.messageType] as? String == Self.messageType,
              let raw = message[WatchMessageKey.command] as? String,
              let command = WatchCommand(rawValue: raw) else { return nil }
        self = command
    }
}

/// Watch to iPhone: one heart rate reading from the watch's workout session
nonisolated struct WatchHeartRate: Equatable, Sendable {
    let beatsPerMinute: Double
    /// when the watch measured it, in seconds since 1970
    let measuredAt: Double

    static let messageType = "heartRate"

    func message() -> [String: Any] {
        [WatchMessageKey.messageType: Self.messageType,
         WatchMessageKey.version: WatchMessageKey.currentVersion,
         WatchMessageKey.beatsPerMinute: beatsPerMinute,
         WatchMessageKey.measuredAt: measuredAt]
    }

    init(beatsPerMinute: Double, measuredAt: Double) {
        self.beatsPerMinute = beatsPerMinute
        self.measuredAt = measuredAt
    }

    init?(message: [String: Any]) {
        guard message[WatchMessageKey.messageType] as? String == Self.messageType,
              let beats = WatchMessageKey.number(message[WatchMessageKey.beatsPerMinute]),
              let measuredAt = WatchMessageKey.number(message[WatchMessageKey.measuredAt]) else { return nil }
        self.init(beatsPerMinute: beats, measuredAt: measuredAt)
    }
}

nonisolated enum WatchMessageKey {
    static let currentVersion = 1

    static let messageType = "type"
    static let version = "v"
    static let stage = "stage"
    static let countdown = "countdown"
    static let exercise = "exercise"
    static let reps = "reps"
    static let caption = "caption"
    static let haptic = "haptic"
    static let summary = "summary"
    static let wristControls = "wristControls"
    static let handsFree = "handsFree"
    static let demoInput = "demoInput"
    static let sentAt = "sentAt"
    static let command = "command"
    static let measuresHeartRate = "heartRate"
    static let beatsPerMinute = "bpm"
    static let measuredAt = "measuredAt"

    /// numbers come back as NSNumber on Apple platforms and as Int or Double elsewhere
    static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double, value.isFinite, value == value.rounded() { return Int(value) }
        return nil
    }

    static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }
}
