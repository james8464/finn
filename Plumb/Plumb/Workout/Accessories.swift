import Foundation

/// A device that can join a Plumb set besides the iPhone. Neither one measures anything today:
/// every rep, timing and observation comes from the iPhone camera. They bring what the iPhone
/// measured closer to the person, who stands a few steps from the phone.
nonisolated enum Accessory: String, CaseIterable, Equatable, Sendable {
    case appleWatch
    case headphones

    var name: String {
        switch self {
        case .appleWatch: "Apple Watch"
        case .headphones: String(localized: "AirPods or headphones")
        }
    }
}

/// One thing an accessory does during a set. None of them is a measurement.
nonisolated enum AccessoryFeature: String, CaseIterable, Equatable, Sendable {
    /// Hear the countdown, each counted rep and live observations in your ears.
    case hearCountdownRepsAndObservations
    /// See brief coaching lines grounded in iPhone camera observations.
    case seeCoachMessages
    /// An optional Watch-owned tap at the chosen pacing interval.
    case feelRhythmTaps
    /// Kept for older Watch command compatibility; no current exercise offers it.
    case startStopFromWrist
}

/// What one accessory adds to one exercise today.
nonisolated struct AccessoryRole: Equatable, Sendable {
    let accessory: Accessory
    let exercise: ExerciseKind
    /// Whether the exercise needs this accessory. False for every exercise: the iPhone camera
    /// measures the set, its speaker says the reps and its screen shows them.
    let isRequired: Bool
    let features: [AccessoryFeature]
    /// Why a feature is left out for this exercise, if one is.
    let limitation: String?

    var isUsed: Bool { !features.isEmpty }

    func offers(_ feature: AccessoryFeature) -> Bool { features.contains(feature) }
}

/// Per exercise, what AirPods (or other headphones) and an Apple Watch add.
nonisolated enum AccessoryRoles {
    static func role(of accessory: Accessory, for exercise: ExerciseKind) -> AccessoryRole {
        switch accessory {
        case .headphones:
            return AccessoryRole(accessory: .headphones, exercise: exercise, isRequired: false,
                                 features: [.hearCountdownRepsAndObservations], limitation: nil)
        case .appleWatch:
            return AccessoryRole(accessory: .appleWatch, exercise: exercise, isRequired: false,
                                 features: [.seeCoachMessages, .feelRhythmTaps], limitation: nil)
        }
    }

    static func roles(for exercise: ExerciseKind) -> [AccessoryRole] {
        Accessory.allCases.map { role(of: $0, for: exercise) }
    }
}

/// What the iPhone knows about a paired Apple Watch.
nonisolated struct WatchConnection: Equatable, Sendable {
    /// An Apple Watch is paired with this iPhone.
    var isPaired = false
    /// Plumb is installed on that watch.
    var isAppInstalled = false
    /// Plumb is open on the watch and can receive the set right now.
    var isReachable = false

    static let none = WatchConnection()
}

/// The accessories around the iPhone right now.
nonisolated struct AccessoryStatus: Equatable, Sendable {
    /// AirPods or other headphones are the current audio output.
    var headphonesConnected = false
    var watch = WatchConnection.none

    static let none = AccessoryStatus()

    /// Whether the accessory can take part in the next set without anything else to do.
    func isConnected(_ accessory: Accessory) -> Bool {
        switch accessory {
        case .headphones: headphonesConnected
        case .appleWatch: watch.isPaired && watch.isAppInstalled && watch.isReachable
        }
    }
}

/// One line for the setup screen about one accessory.
nonisolated struct AccessoryLine: Equatable, Sendable {
    let accessory: Accessory
    let text: String
}

nonisolated enum AccessoryGuide {
    /// One short line per accessory that matters right now, headphones first. Empty when neither is
    /// around: Plumb works the same without them.
    static func setupLines(for exercise: ExerciseKind, status: AccessoryStatus,
                           speaksLive: Bool) -> [AccessoryLine] {
        [headphonesLine(status: status, speaksLive: speaksLive),
         watchLine(for: exercise, status: status)].compactMap { $0 }
    }

    static func headphonesLine(status: AccessoryStatus, speaksLive: Bool) -> AccessoryLine? {
        guard status.headphonesConnected else { return nil }
        // The route says Bluetooth or wired headphones, not which model, so the line does not say AirPods.
        return AccessoryLine(accessory: .headphones, text: speaksLive
            ? String(localized: "Headphones connected: you will hear each rep.")
            : String(localized: "Headphones connected. Turn on Say reps aloud in Options to hear each rep."))
    }

    static func watchLine(for exercise: ExerciseKind, status: AccessoryStatus) -> AccessoryLine? {
        let watch = status.watch
        guard watch.isPaired else { return nil }
        guard watch.isAppInstalled else {
            return AccessoryLine(accessory: .appleWatch,
                                 text: String(localized: "Apple Watch: install Plumb for coaching messages and optional rhythm taps."))
        }
        let text = watch.isReachable
            ? String(localized: "Apple Watch connected: coaching messages are ready; rhythm is optional.")
            : String(localized: "Apple Watch: open Plumb on your watch for coaching messages and rhythm.")
        return AccessoryLine(accessory: .appleWatch, text: text)
    }
}
