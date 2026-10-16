import Foundation

// the messages between Finn on the iPhone and Finn on Apple Watch. The watch target compiles this
// one file too, so it uses Foundation only and none of the iPhone's workout types. WatchConnectivity
// carries property-list dictionaries: strings, numbers and booleans here, and never nil.

/// The set's stage as the watch shows it.
nonisolated enum WatchStage: String, CaseIterable, Equatable, Sendable {
    /// No camera open on the iPhone.
    case ready
    /// The camera is open and the person is getting into position.
    case framing
    case countdown
    /// The set is running.
    case capturing
    /// The iPhone is reviewing the set.
    case analyzing
    case result
}

/// Legacy live tap values kept readable for older message versions. Current rhythm taps are local.
nonisolated enum WatchHaptic: String, CaseIterable, Equatable, Sendable {
    case none
    /// A rep was counted.
    case rep
    /// A live observation, such as a rep faster than the first ones.
    case observation
    /// The set started.
    case start
    /// The set ended.
    case end
}

/// iPhone to watch: everything the watch screen shows. The iPhone sends the whole state each time,
/// so a lost or late message never leaves the watch stuck.
/// The wrist taps of a set with a rep target (Try Finn): one per counted rep, then a success
/// once the target is reached. Ordinary sets keep the rhythm taps only.
nonisolated enum WatchTargetTaps {
    static func haptic(after shown: WatchState?, for incoming: WatchState) -> WatchHaptic {
        guard let target = incoming.target, incoming.hapticsEnabled,
              incoming.stage == .capturing || incoming.stage == .analyzing,
              let shown, shown.setID == incoming.setID, incoming.reps > shown.reps else { return .none }
        return shown.reps < target && incoming.reps >= target ? .end : .rep
    }
}

nonisolated struct WatchState: Equatable, Sendable {
    var stage: WatchStage = .ready
    /// Seconds left in the countdown; 0 outside it.
    var countdown = 0
    /// The exercise's name, such as "Squat".
    var exercise = ""
    /// Reps counted so far while the set runs; reps measured once it is reviewed.
    var reps = 0
    /// Reps that end the set by themselves (Try Finn's first exercise); nil for an ordinary set.
    var target: Int?
    /// The latest live observation of the running set, measured on the iPhone.
    var caption: String?
    var haptic: WatchHaptic = .none
    /// One line about the reviewed set.
    var summary: String?
    /// Whether Start set and Stop set are offered on the wrist for this exercise.
    var wristControls = true
    /// Whether the set starts and ends by itself (hands-free on the iPhone).
    var handsFree = false
    /// The iPhone is replaying demo input, not filming a person.
    var demoInput = false
    /// The person turned on Personalize with Health: the watch runs a workout session while the
    /// camera is open and sends its heart rate back.
    var measuresHeartRate = false
    /// Stable for one camera set, so the Watch can reset its rhythm on a new set.
    var setID: String?
    /// One phone-authored line based on measured reps or live form events.
    var coachMessage: String?
    var hapticsEnabled = true
    var languageCode = "en-GB"
    /// When the iPhone sent this state, in seconds since 1970. The watch keeps the newest.
    var sentAt = 0.0

    static let messageType = "state"
    /// A saved state older than this, in seconds, is not shown when the watch app opens.
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
            WatchMessageKey.hapticsEnabled: hapticsEnabled,
            WatchMessageKey.languageCode: languageCode,
            WatchMessageKey.sentAt: sentAt,
        ]
        if let setID {
            message[WatchMessageKey.setID] = setID
        }
        if let target {
            message[WatchMessageKey.target] = target
        }
        if let coachMessage {
            message[WatchMessageKey.coachMessage] = coachMessage
        }
        if let caption {
            message[WatchMessageKey.caption] = caption
        }
        if let summary {
            message[WatchMessageKey.summary] = summary
        }
        return message
    }

    /// Reads a state message; nil for anything else. Missing optional values take their defaults.
    init?(message: [String: Any]) {
        guard
            message[WatchMessageKey.messageType] as? String == Self.messageType,
            let rawStage = message[WatchMessageKey.stage] as? String,
            let stage = WatchStage(rawValue: rawStage) else {
            return nil
        }
        self.stage = stage
        countdown = WatchMessageKey.integer(message[WatchMessageKey.countdown]) ?? 0
        exercise = message[WatchMessageKey.exercise] as? String ?? ""
        reps = WatchMessageKey.integer(message[WatchMessageKey.reps]) ?? 0
        target = WatchMessageKey.integer(message[WatchMessageKey.target])
        caption = message[WatchMessageKey.caption] as? String
        haptic = (message[WatchMessageKey.haptic] as? String).flatMap(WatchHaptic.init(rawValue:)) ?? .none
        summary = message[WatchMessageKey.summary] as? String
        wristControls = message[WatchMessageKey.wristControls] as? Bool ?? true
        handsFree = message[WatchMessageKey.handsFree] as? Bool ?? false
        demoInput = message[WatchMessageKey.demoInput] as? Bool ?? false
        measuresHeartRate = message[WatchMessageKey.measuresHeartRate] as? Bool ?? false
        setID = message[WatchMessageKey.setID] as? String
        coachMessage = message[WatchMessageKey.coachMessage] as? String
        hapticsEnabled = message[WatchMessageKey.hapticsEnabled] as? Bool ?? true
        languageCode = message[WatchMessageKey.languageCode] as? String ?? "en-GB"
        sentAt = WatchMessageKey.number(message[WatchMessageKey.sentAt]) ?? 0
    }

    init(
        stage: WatchStage = .ready,
        countdown: Int = 0,
        exercise: String = "",
        reps: Int = 0,
        target: Int? = nil,
        caption: String? = nil,
        haptic: WatchHaptic = .none,
        summary: String? = nil,
        wristControls: Bool = true,
        handsFree: Bool = false,
        demoInput: Bool = false,
        measuresHeartRate: Bool = false,
        sentAt: Double = 0,
        setID: String? = nil,
        coachMessage: String? = nil,
        hapticsEnabled: Bool = true,
        languageCode: String = "en-GB"
    ) {
        self.stage = stage
        self.countdown = countdown
        self.exercise = exercise
        self.reps = reps
        self.target = target
        self.caption = caption
        self.haptic = haptic
        self.summary = summary
        self.wristControls = wristControls
        self.handsFree = handsFree
        self.demoInput = demoInput
        self.measuresHeartRate = measuresHeartRate
        self.sentAt = sentAt
        self.setID = setID
        self.coachMessage = coachMessage
        self.hapticsEnabled = hapticsEnabled
        self.languageCode = languageCode
    }

    /// Whether this state should replace `shown` on the watch. Only a newer one does, so a late
    /// application context never rewinds the screen and a repeated message never taps twice.
    func isNewer(than shown: WatchState?) -> Bool {
        guard let shown else {
            return true
        }
        return sentAt > shown.sentAt
    }

    /// A recently authored context can show coaching while the matching live message is in flight.
    /// Older queued contexts must never restart rhythm after a connection returns.
    func isFreshForLive(now: TimeInterval) -> Bool {
        let age = now - sentAt
        return age >= -2 && age < 15
    }

    /// The live copy of a context already shown may refresh liveness without replaying its screen.
    func matchesShownStateForLive(_ shown: WatchState?, now: TimeInterval) -> Bool {
        guard let shown else {
            return false
        }
        return self == shown && isFreshForLive(now: now)
    }

    /// A saved state from a while ago, such as a set the iPhone never finished telling the watch about.
    func isStale(now: TimeInterval) -> Bool {
        now - sentAt > Self.staleAfter
    }
}

/// A local monotonic schedule: a late wake produces one beat and never replays missed beats.
nonisolated struct WatchRhythmClock: Equatable, Sendable {
    let interval: Int
    private var nextBeat: Double?

    init(interval: Int = 3) {
        self.interval = [2, 3, 4, 5].contains(interval) ? interval : 3
    }

    mutating func resume(now: Double) {
        nextBeat = now + Double(interval)
    }

    mutating func stop() {
        nextBeat = nil
    }

    mutating func shouldTap(now: Double, lastPhoneStateAt: Double, reachable: Bool) -> Bool {
        guard reachable, now - lastPhoneStateAt < 15, let nextBeat else {
            stop()
            return false
        }
        guard now >= nextBeat else {
            return false
        }
        let missed = floor((now - nextBeat) / Double(interval)) + 1
        self.nextBeat = nextBeat + missed * Double(interval)
        return true
    }
}

nonisolated enum WatchRhythmPolicy {
    static func canEnable(permissionGranted: Bool) -> Bool {
        permissionGranted
    }

    static func canTap(
        enabled: Bool,
        masterHapticsEnabled: Bool,
        workoutRunning: Bool,
        capturing: Bool
    ) -> Bool {
        enabled && masterHapticsEnabled && workoutRunning && capturing
    }
}

nonisolated enum WatchLanguage {
    static func resolved(_ identifier: String?) -> String {
        let language = (identifier ?? "").replacingOccurrences(of: "_", with: "-").lowercased()
        if language.hasPrefix("fr") {
            return "fr"
        }
        if language.hasPrefix("es") {
            return "es"
        }
        if language == "en-us" {
            return "en-US"
        }
        return "en-GB"
    }
}

/// Legacy wrist commands kept readable for older message versions; the current Watch UI sends none.
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
        guard
            message[WatchMessageKey.messageType] as? String == Self.messageType,
            let raw = message[WatchMessageKey.command] as? String,
            let command = WatchCommand(rawValue: raw) else {
            return nil
        }
        self = command
    }
}

/// Watch to iPhone: one heart rate reading from the watch's workout session.
nonisolated struct WatchHeartRate: Equatable, Sendable {
    let beatsPerMinute: Double
    /// When the watch measured it, in seconds since 1970.
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
        guard
            message[WatchMessageKey.messageType] as? String == Self.messageType,
            let beats = WatchMessageKey.number(message[WatchMessageKey.beatsPerMinute]),
            let measuredAt = WatchMessageKey.number(message[WatchMessageKey.measuredAt]) else {
            return nil
        }
        self.init(beatsPerMinute: beats, measuredAt: measuredAt)
    }
}

nonisolated enum WatchMessageKey {
    static let currentVersion = 2

    static let messageType = "type"
    static let version = "v"
    static let stage = "stage"
    static let countdown = "countdown"
    static let exercise = "exercise"
    static let reps = "reps"
    static let target = "target"
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
    static let setID = "setID"
    static let coachMessage = "coachMessage"
    static let hapticsEnabled = "hapticsEnabled"
    static let languageCode = "languageCode"

    /// Numbers come back as NSNumber on Apple platforms and as Int or Double elsewhere.
    static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double, value.isFinite, value == value.rounded() {
            return Int(value)
        }
        return nil
    }

    static func number(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        return nil
    }
}
