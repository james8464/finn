import AppIntents

/// "Start a push-up set in Plumb": opens the app on the set screen with that exercise chosen. The
/// camera itself starts only in the app, with its usual permission flow; Siri never films.
struct StartSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Set"
    static let description = IntentDescription(
        "Opens Plumb on the set screen with the exercise you choose. The camera starts in the app, as usual.",
        categoryName: "Sets")
    static let openAppWhenRun = true

    @Parameter(title: "Exercise")
    var exercise: ExerciseChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$exercise) set")
    }

    init() {}

    init(exercise: ExerciseChoice) {
        self.exercise = exercise
    }

    func perform() async throws -> some IntentResult {
        let kind = exercise.kind
        await MainActor.run { SiriLaunchRequests.shared.pending = .startSet(kind) }
        return .result()
    }
}
