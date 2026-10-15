import Foundation

/// The last set Plumb measured, as the home screen widget shows it. Written only when a session is
/// saved in the local history, and never from demo or recorded input. Facts only: an exercise name,
/// a count and a date. No video, no pose points, no Health data.
///
/// This file is compiled into the app and the widget extension, so it depends on Foundation alone.
nonisolated struct LastSetSnapshot: Codable, Equatable, Sendable {
    /// The exercise as the app names it ("Squat", "Push-up").
    let exerciseName: String
    /// `ExerciseKind.rawValue`, so the widget's deep link opens the app on that exercise.
    let exerciseKey: String
    let reps: Int
    let capturedAt: Date
    /// True when the joints were clear in only part of the set: the reps were counted without advice.
    let partlyVisible: Bool

    /// "12 squats", "1 rep" when the name does not pluralize cleanly.
    var repsLine: String {
        reps == 1 ? "1 rep" : "\(reps) reps"
    }
}

/// Where the app and the widget meet: one JSON value in the App Group's shared defaults.
nonisolated struct SharedSetStore: @unchecked Sendable {
    static let appGroupID = "group.ai.mwm.build.challenge.team.08"
    static let key = "lastSetSnapshot"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The store the app and the widget share. Nil only when the App Group container is missing,
    /// which means the entitlement is not in the build; nothing is written then.
    static var appGroup: SharedSetStore? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        return SharedSetStore(defaults: defaults)
    }

    func read() -> LastSetSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(LastSetSnapshot.self, from: data)
    }

    /// Replaces the snapshot, or removes it when `snapshot` is nil (history emptied).
    func write(_ snapshot: LastSetSnapshot?) {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}

/// The widget opens the app with a URL the app recognizes. A plain scheme: no server is involved.
nonisolated enum PlumbDeepLink: Equatable, Sendable {
    static let scheme = "plumb"
    private static let startHost = "start-set"
    private static let exerciseItem = "exercise"

    /// Open the camera for a set, on `exerciseKey` (an `ExerciseKind.rawValue`) when given.
    case startSet(exerciseKey: String?)

    var url: URL {
        switch self {
        case .startSet(let exerciseKey):
            var components = URLComponents()
            components.scheme = Self.scheme
            components.host = Self.startHost
            if let exerciseKey {
                components.queryItems = [URLQueryItem(name: Self.exerciseItem, value: exerciseKey)]
            }
            return components.url ?? URL(string: "\(Self.scheme)://\(Self.startHost)")!
        }
    }

    /// Nil for any URL the app does not know, which is then ignored.
    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              components.host?.lowercased() == Self.startHost else { return nil }
        let key = components.queryItems?.first { $0.name == Self.exerciseItem }?.value
        self = .startSet(exerciseKey: key?.isEmpty == false ? key : nil)
    }
}
