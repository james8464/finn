import Foundation

/// a device that can join a Plumb set besides the iPhone. Neither one measures anything today:
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

/// one thing an accessory does during a set. None of them is a measurement.
nonisolated enum AccessoryFeature: String, CaseIterable, Equatable, Sendable {
    /// hear the countdown, each counted rep and live observations in your ears
    case hearCountdownRepsAndObservations
    /// see the running rep count and the latest live observation on the wrist
    case seeRepCount
    /// feel a tap on each counted rep, and a distinct tap for a live observation
    case feelRepTaps
    /// start and stop the set from the wrist
    case startStopFromWrist
}

/// what one accessory adds to one exercise today
nonisolated struct AccessoryRole: Equatable, Sendable {
    let accessory: Accessory
    let exercise: ExerciseKind
    /// whether the exercise needs this accessory. False for every exercise: the iPhone camera
    /// measures the set, its speaker says the reps and its screen shows them.
    let isRequired: Bool
    let features: [AccessoryFeature]
    /// why a feature is left out for this exercise, if one is
    let limitation: String?

    var isUsed: Bool { !features.isEmpty }

    func offers(_ feature: AccessoryFeature) -> Bool { features.contains(feature) }
}

/// per exercise, what AirPods (or other headphones) and an Apple Watch add
nonisolated enum AccessoryRoles {
    static func role(of accessory: Accessory, for exercise: ExerciseKind) -> AccessoryRole {
        switch accessory {
        case .headphones:
            return AccessoryRole(accessory: .headphones, exercise: exercise, isRequired: false,
                                 features: [.hearCountdownRepsAndObservations], limitation: nil)
        case .appleWatch where exercise == .pushUp:
            // the hands are planted on the floor: the wrist can feel a tap but not press a button
            return AccessoryRole(accessory: .appleWatch, exercise: exercise, isRequired: false,
                                 features: [.seeRepCount, .feelRepTaps],
                                 limitation: String(localized: "Your hands stay on the floor, so the set starts and stops from the iPhone or hands-free."))
        case .appleWatch:
            return AccessoryRole(accessory: .appleWatch, exercise: exercise, isRequired: false,
                                 features: [.seeRepCount, .feelRepTaps, .startStopFromWrist], limitation: nil)
        }
    }

    static func roles(for exercise: ExerciseKind) -> [AccessoryRole] {
        Accessory.allCases.map { role(of: $0, for: exercise) }
    }
}

/// what the iPhone knows about a paired Apple Watch
nonisolated struct WatchConnection: Equatable, Sendable {
    /// an Apple Watch is paired with this iPhone
    var isPaired = false
    /// Plumb is installed on that watch
    var isAppInstalled = false
    /// Plumb is open on the watch and can receive the set right now
    var isReachable = false

    static let none = WatchConnection()
}

/// the accessories around the iPhone right now
nonisolated struct AccessoryStatus: Equatable, Sendable {
    /// AirPods or other headphones are the current audio output
    var headphonesConnected = false
    var watch = WatchConnection.none

    static let none = AccessoryStatus()

    /// whether the accessory can take part in the next set without anything else to do
    func isConnected(_ accessory: Accessory) -> Bool {
        switch accessory {
        case .headphones: headphonesConnected
        case .appleWatch: watch.isPaired && watch.isAppInstalled && watch.isReachable
        }
    }
}

/// one line for the setup screen about one accessory
nonisolated struct AccessoryLine: Equatable, Sendable {
    let accessory: Accessory
    let text: String
}

nonisolated enum AccessoryGuide {
    /// one short line per accessory that matters right now, headphones first. Empty when neither is
    /// around: Plumb works the same without them.
    static func setupLines(for exercise: ExerciseKind, status: AccessoryStatus,
                           speaksLive: Bool) -> [AccessoryLine] {
        [headphonesLine(status: status, speaksLive: speaksLive),
         watchLine(for: exercise, status: status)].compactMap { $0 }
    }

    static func headphonesLine(status: AccessoryStatus, speaksLive: Bool) -> AccessoryLine? {
        guard status.headphonesConnected else { return nil }
        // the route says Bluetooth or wired headphones, not which model, so the line does not say AirPods
        return AccessoryLine(accessory: .headphones, text: speaksLive
            ? String(localized: "Headphones connected: you will hear each rep.")
            : String(localized: "Headphones connected. Turn on Say reps aloud in Options to hear each rep."))
    }

    static func watchLine(for exercise: ExerciseKind, status: AccessoryStatus) -> AccessoryLine? {
        let watch = status.watch
        guard watch.isPaired else { return nil }
        guard watch.isAppInstalled else {
            return AccessoryLine(accessory: .appleWatch,
                                 text: String(localized: "Apple Watch: install Plumb on your watch to see reps on your wrist."))
        }
        let fromWrist = AccessoryRoles.role(of: .appleWatch, for: exercise).offers(.startStopFromWrist)
        let text: String
        switch (watch.isReachable, fromWrist) {
        case (true, true): text = String(localized: "Apple Watch connected: see each rep and start sets from your wrist.")
        case (true, false): text = String(localized: "Apple Watch connected: see each rep and feel a tap on your wrist.")
        case (false, true): text = String(localized: "Apple Watch: open Plumb on your watch to see reps and start sets from your wrist.")
        case (false, false): text = String(localized: "Apple Watch: open Plumb on your watch to see reps and feel a tap on each one.")
        }
        return AccessoryLine(accessory: .appleWatch, text: text)
    }
}
