import Foundation
import Observation

/// the conversation with Finn, kept on this iPhone so it is still there when the app reopens.
/// Holds the turns after Finn's greeting, which is written afresh from the latest sets each time.
/// Lives in the app's defaults, like the planned workouts, and goes with Delete all data
@MainActor
@Observable
final class CoachTranscriptStore {
    private static let key = "coachConversation.v1"
    /// the most turns kept: the conversation's limit, less the greeting
    static let maximumTurns = CoachConversation.maximumMessages - 1

    private let defaults: UserDefaults
    /// oldest first
    private(set) var turns: [CoachMessage]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([CoachMessage].self, from: $0) } ?? []
        turns = Self.kept(saved)
    }

    func save(_ turns: [CoachMessage]) {
        self.turns = Self.kept(turns)
        if let data = try? JSONEncoder().encode(self.turns) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func clear() {
        turns = []
        defaults.removeObject(forKey: Self.key)
    }

    /// the latest turns, without empty or repeated messages
    private static func kept(_ turns: [CoachMessage]) -> [CoachMessage] {
        var seen: Set<UUID> = []
        let valid = turns.filter { !$0.text.isEmpty && seen.insert($0.id).inserted }
        return Array(valid.suffix(maximumTurns))
    }
}
