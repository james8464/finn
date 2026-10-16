import Foundation

#if DEBUG
/// four weeks of past workouts for the Strength chart and its projection
/// (`-finn-ui-progress-demo`, with `-finn-ui-demo`). Demo input only: real history is never touched
enum ProgressDemo {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-finn-ui-progress-demo") }

    /// fills the throwaway demo store when the flag is set, and hands it back
    static func seeded(_ store: LocalSessionStore) -> LocalSessionStore {
        guard isEnabled else { return store }
        for session in sample() { try? store.save(session) }
        return store
    }

    /// best squat set per workout climbing from 6 to 11, a push-up workout every other time
    static func sample(now: Date = .now) -> [WorkoutSessionSummary] {
        let squats = [6, 7, 7, 8, 9, 9, 10, 11]
        return squats.enumerated().map { index, best in
            let date = now.addingTimeInterval(-Double(28 - index * 4) * 86_400)
            let id = UUID()
            var sets = [set(.bodyweightSquat, reps: best - 2, at: date, session: id),
                        set(.bodyweightSquat, reps: best, at: date.addingTimeInterval(120), session: id)]
            if index.isMultiple(of: 2) {
                sets.append(set(.pushUp, reps: 5 + index / 2, at: date.addingTimeInterval(300), session: id))
            }
            return WorkoutSessionSummary(id: id, startedAt: date, sets: sets)
        }
        .reversed()
    }

    private static func set(_ kind: ExerciseKind, reps: Int, at date: Date, session: UUID) -> SetSummary {
        let metrics = (0..<reps).map {
            RepMetric(number: $0 + 1, startTime: Double($0) * 2.4, endTime: Double($0) * 2.4 + 2.2,
                      relativeRange: kind == .bodyweightSquat ? 0.42 : 70)
        }
        return SetSummary(id: UUID(), sessionID: session, capturedAt: date, bodySide: .left,
                          analysis: SetAnalysis(reps: metrics, confidence: 0.9,
                                                rubricVersion: kind.definition.rubricVersion),
                          cue: nil, cueResponse: .unanswered, exercise: kind)
    }
}
#endif
