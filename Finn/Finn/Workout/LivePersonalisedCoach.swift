import Foundation

/// Optional context influences which recorded cue is useful; it never supplies a new diagnosis.
nonisolated struct LiveCoachContext: Equatable, Sendable {
    var onboardingNote: String = ""
    /// Populate only from Health data the person has enabled for personalisation.
    var consentedHealthSummary: String = ""
    var priorAcceptedChecks: Set<FormCheck> = []

    static func acceptedChecks(in sessions: [WorkoutSessionSummary], exercise: ExerciseKind) -> Set<FormCheck> {
        var checks: Set<FormCheck> = []
        for session in sessions.prefix(32) {
            for set in session.sets where set.exercise == exercise && set.cueResponse != .notRelevant {
                for measurement in FormTrend.eligibleMeasurements(in: set) where measurement.faulty >= 2 {
                    checks.insert(measurement.check)
                }
            }
        }
        return checks
    }
}

nonisolated struct LiveCoachChoice: Equatable, Sendable {
    let id: String
    let text: String
}

nonisolated enum LiveCoachChoices {
    static func make(event: LiveSetEvent, reps: [RepMetric], definition: ExerciseDefinition,
                     canCompareRange: Bool, context: LiveCoachContext,
                     language: CoachLanguage) -> [LiveCoachChoice] {
        guard let base = WatchCoachRules.line(for: event, reps: reps, definition: definition,
                                              canCompareRange: canCompareRange) else { return [] }
        var choices = [LiveCoachChoice(id: "base:\(event.key)", text: base)]
        switch event {
        case .formFault(let check, let rep):
            guard check.exercise == definition.kind, rep > 0, rep <= reps.count else { return [] }
            choices.append(LiveCoachChoice(id: "action:\(check.rawValue)", text: check.liveCue))
            if context.priorAcceptedChecks.contains(check) {
                let prefix: String
                switch language {
                case .english: prefix = "This came up in your earlier sets too."
                case .french: prefix = "Ce point apparaissait aussi dans tes séries précédentes."
                case .spanish: prefix = "Esto también apareció en tus series anteriores."
                }
                choices.append(LiveCoachChoice(id: "history:\(check.rawValue)",
                                               text: prefix + " " + check.liveCue))
            }
        case .fasterThanFirstReps(let rep), .shorterThanFirstReps(let rep):
            guard rep > 0, rep <= reps.count else { return [] }
            choices.append(LiveCoachChoice(id: "action:\(event.key)", text: event.spoken(for: definition)))
        case .repCounted(let count):
            guard count > 0, count <= reps.count else { return [] }
            // Neutral encouragement is useful even when the camera cannot establish good form.
            let text: String
            switch language {
            case .english: text = "One rep at a time. Stay with me."
            case .french: text = "Une répétition à la fois. On continue ensemble."
            case .spanish: text = "Una repetición a la vez. Seguimos juntos."
            }
            choices.append(LiveCoachChoice(id: "encouragement", text: text))
        case .repCountRevised:
            return []
        }
        return choices
    }

    static func selected(_ index: Int?, from choices: [LiveCoachChoice]) -> LiveCoachChoice? {
        guard let index, choices.indices.contains(index) else { return nil }
        return choices[index]
    }
}

private extension LiveSetEvent {
    nonisolated var key: String {
        switch self {
        case .repCounted: "count"
        case .repCountRevised: "revision"
        case .fasterThanFirstReps: "pace"
        case .shorterThanFirstReps: "range"
        case .formFault(let check, _): check.rawValue
        }
    }
}

@MainActor
protocol LiveCoachSelecting: AnyObject {
    var available: Bool { get }
    func prepare(language: CoachLanguage)
    func reset()
    func select(from choices: [LiveCoachChoice], context: LiveCoachContext,
                language: CoachLanguage) async throws -> Int
}

extension LiveCoachSelecting {
    func prepare(language: CoachLanguage) {}
    func reset() {}
}

/// One bounded request per coaching interval, with immediate local wording and strict freshness.
/// Every event invalidates an older answer, even when that event has no spoken coaching line.
@MainActor
final class LivePersonalisedCoach {
    private let selector: any LiveCoachSelecting
    private let generation = ModelGenerationGate<Int>()
    private let now: @MainActor () -> TimeInterval
    private let minimumModelInterval: TimeInterval
    private var lastModelRequest: TimeInterval?
    private var requestID = UUID()
    private var task: Task<Void, Never>?
    private var recentChoices: [String] = []

    init(selector: (any LiveCoachSelecting)? = nil, minimumModelInterval: TimeInterval = 12,
         now: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.selector = selector ?? AppleLiveCoachSelector()
        self.minimumModelInterval = max(0, minimumModelInterval)
        self.now = now
    }

    func prepare(language: CoachLanguage = .current()) {
        guard selector.available else { return }
        selector.prepare(language: language)
    }

    func reset() {
        requestID = UUID()
        task?.cancel()
        task = nil
        lastModelRequest = nil
        recentChoices = []
        selector.reset()
    }

    func update(event: LiveSetEvent, reps: [RepMetric], definition: ExerciseDefinition,
                canCompareRange: Bool, context: LiveCoachContext,
                language: CoachLanguage = .current(), onLine: @escaping @MainActor (String) -> Void) {
        requestID = UUID()
        let currentRequest = requestID
        task?.cancel()
        task = nil
        let allChoices = LiveCoachChoices.make(event: event, reps: reps, definition: definition,
                                              canCompareRange: canCompareRange, context: context,
                                              language: language)
        guard !allChoices.isEmpty else { return }
        let freshChoices = allChoices.filter { !recentChoices.contains($0.id) }
        let choices = freshChoices.isEmpty ? allChoices : freshChoices
        guard let fallback = choices.first else { return }
        remember(fallback.id)
        onLine(fallback.text)

        if case .repCounted = event {
            return
        }
        let instant = now()
        guard selector.available,
              lastModelRequest.map({ instant - $0 >= minimumModelInterval }) ?? true else { return }
        lastModelRequest = instant
        task = Task { @MainActor [weak self, selector, generation] in
            let index = await generation.response(timeout: .seconds(2)) {
                try await selector.select(from: choices, context: context, language: language)
            }
            guard let self, !Task.isCancelled, self.requestID == currentRequest,
                  let choice = LiveCoachChoices.selected(index, from: choices) else { return }
            self.remember(choice.id)
            if choice.text != fallback.text { onLine(choice.text) }
        }
    }

    private func remember(_ id: String) {
        recentChoices.removeAll { $0 == id }
        recentChoices.append(id)
        if recentChoices.count > 4 { recentChoices.removeFirst() }
    }
}
