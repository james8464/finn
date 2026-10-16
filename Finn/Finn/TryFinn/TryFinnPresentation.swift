import SwiftUI

extension View {
    /// Try Finn over the current screen while `isPresented`. Try exercise closes it and opens the
    /// app's camera screen on the level's exercise, with its rep target. Once a set has started,
    /// the return to Home sets `hasTriedFinn`
    func tryFinn(isPresented: Binding<Bool>, hasTriedFinn: Binding<Bool>) -> some View {
        modifier(TryFinnPresentation(isPresented: isPresented, hasTriedFinn: hasTriedFinn))
    }
}

private struct TryFinnPresentation: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var hasTriedFinn: Bool
    /// the app's one session model (`ContentView`); nil in previews, where Try exercise only closes
    @Environment(WorkoutSessionModel.self) private var session: WorkoutSessionModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// chosen with Try exercise; the camera opens once the screen has gone
    @State private var chosen: TryFinnExercise?
    @State private var trial: Trial?

    /// a trial on the camera screen
    private struct Trial {
        /// the exercise the Workout tab had before, given back afterwards
        let previousExercise: ExerciseKind
        var setStarted = false
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: beginTrial) {
                TryFinnView(model: TryFinnViewModel(level: session?.preferences.trainingLevel,
                                                    camera: .forThisLaunch),
                            start: { exercise in
                                chosen = exercise
                                isPresented = false
                            },
                            close: { isPresented = false })
            }
            .onChange(of: session?.stage) { _, stage in follow(stage) }
    }

    private func beginTrial() {
        guard let exercise = chosen else { return }
        chosen = nil
        guard let session, session.stage == .ready || session.stage == .result else { return }
        trial = Trial(previousExercise: session.selectedExercise)
        session.selectedExercise = exercise.kind
        session.repTarget = exercise.reps
        Task { await session.startPreview() }
    }

    /// a started set counts as tried, whether it reached the target or not. Leaving the camera
    /// before the set gives Home its Try Finn card back
    private func follow(_ stage: WorkoutStage?) {
        guard var current = trial, let session else { return }
        switch stage {
        case .capturing:
            current.setStarted = true
            trial = current
        case .ready:
            trial = nil
            session.selectedExercise = current.previousExercise
            guard current.setStarted else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : HomeStyle.spring) { hasTriedFinn = true }
        default:
            break
        }
    }
}
