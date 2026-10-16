import SwiftUI

/// The illustration is available without recording. Camera advice is an explicit choice for
/// the current set; self-reported completion never creates measured reps or Health workouts.
struct GuidedWorkoutView: View {
    @Binding var workout: GuidedWorkout?
    let onAdvice: (ExerciseKind) -> Void
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let current = workout {
                        if let exercise = current.next, let stageID = current.stageID {
                            stage(exercise, current: current, stageID: stageID)
                        } else if current.isComplete {
                            completion(current)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .background { HomeBackdrop() }
            .navigationTitle("Follow workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityHint("Your place is saved")
                }
            }
        }
    }

    private func stage(_ exercise: PlannedExercise, current: GuidedWorkout, stageID: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exercise.exercise.definition.copy.name)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("guided.exercise")
            Text("Set \(current.nextSetNumber) of \(exercise.sets) · \(exercise.reps) reps")
                .font(.headline)
                .monospacedDigit()
                .accessibilityIdentifier("guided.prescription")
            ProgressView(value: Double(current.progressedSets), total: Double(max(1, current.totalSets)))
                .tint(DashboardStyle.accent)
                .accessibilityLabel("Workout progress")
                .accessibilityValue(String(localized: "\(current.progressedSets) of \(current.totalSets) sets completed"))
                .accessibilityIdentifier("guided.progress")

            MovementAnimationCard(exercise: exercise.exercise, usesRecordingSkeleton: true)
                .id(exercise.id)
                .accessibilityIdentifier("guided.animation")

            Button {
                // A stale rendered button must not open coaching for a different stage.
                guard workout?.stageID == stageID else { return }
                onAdvice(exercise.exercise)
            } label: {
                Label("Get advice", systemImage: "camera")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("guided.advice")
            Text("Optional: Finn watches this set and gives feedback on what the camera can measure.")
                .font(.footnote)
                .foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let focus = exercise.focus {
                Text(focus)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .modifier(DashboardGlass())
            }
            MovementStepsCard(exercise: exercise.exercise)
            Button {
                guard var updated = workout, updated.advanceManually(stageID: stageID) else { return }
                workout = updated
                FinnHaptics.play(updated.isComplete ? .success : .selection)
            } label: {
                Text(nextTitle(exercise, current: current))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("guided.next")
            Text("Continue when you have finished this set. Reps are measured only when you choose camera advice.")
                .font(.footnote)
                .foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextTitle(_ exercise: PlannedExercise, current: GuidedWorkout) -> String {
        if current.progressedSets + 1 == current.totalSets {
            return String(localized: "Finish workout")
        }
        return current.nextSetNumber < exercise.sets
            ? String(localized: "Next set") : String(localized: "Next exercise")
    }

    private func completion(_ current: GuidedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Workout complete", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DashboardStyle.accent)
                .accessibilityIdentifier("guided.complete")
            Text("\(current.manualSets) sets self-reported · \(current.measuredSets) sets measured")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("guided.summary")
            Text("Camera measurements stay in your workout history. Self-reported sets are kept separate.")
                .font(.footnote)
                .foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done", action: onFinish)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("guided.finish")
        }
    }
}


/// The same bones, joints and angle badge as the camera overlay, driven by the production
/// illustration poses. These drawings are never fed into rep counting or saved as evidence.
struct GuidedExerciseSkeletonView: View {
    let exercise: ExerciseKind
    var animates: Bool
    private let figureBounds: CGRect
    @State private var startedAt = Date.timeIntervalSinceReferenceDate
    @State private var pausedSeconds = 0.0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

    init(exercise: ExerciseKind, animates: Bool) {
        self.exercise = exercise
        self.animates = animates
        figureBounds = ExerciseFigure(kind: exercise).bounds()
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60,
                                paused: reduceMotion || !animates || scenePhase != .active)) { timeline in
            let seconds = animates ? timeline.date.timeIntervalSinceReferenceDate - startedAt : pausedSeconds
            let phase = reduceMotion ? 0.85 : (1 - cos(2 * .pi * seconds / 3.2)) / 2
            Canvas { context, size in
                let frame = illustratedFrame(phase: phase)
                let geometry = SkeletonGeometry(frame: frame, exercise: exercise.definition,
                                                size: size, mirrored: false)
                SkeletonPainter.draw(geometry, in: &context, size: size, clear: .white,
                                     labelText: .black)
            }
        }
        .onChange(of: animates) { _, playing in
            if playing {
                startedAt = Date.timeIntervalSinceReferenceDate - pausedSeconds
            } else {
                pausedSeconds = Date.timeIntervalSinceReferenceDate - startedAt
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Drawing of a \(exercise.definition.copy.shareNoun), seen from the side")
        .accessibilityAddTraits(.isImage)
    }

    private func illustratedFrame(phase: Double) -> PoseFrame {
        let figure = ExerciseFigure(kind: exercise)
        let bounds = figureBounds
        let pose = figure.pose(at: phase)
        let mapping: [(ExerciseFigure.Joint, BodyJoint)] = [
            (.shoulder, .leftShoulder), (.elbow, .leftElbow), (.wrist, .leftWrist),
            (.hip, .leftHip), (.knee, .leftKnee), (.ankle, .leftAnkle), (.head, .nose),
            (.backKnee, .rightKnee), (.backAnkle, .rightAnkle)
        ]
        var joints: [BodyJoint: JointPoint] = [:]
        for (source, target) in mapping {
            guard let point = pose[source] else { continue }
            joints[target] = JointPoint(x: Double((point.x - bounds.minX) / bounds.width),
                                        y: Double((bounds.maxY - point.y) / bounds.height),
                                        confidence: 1)
        }
        if joints[.rightKnee] != nil {
            joints[.rightHip] = joints[.leftHip]
        }
        return PoseFrame(time: 0, subjectCount: 1, joints: joints,
                         aspectRatio: Double(bounds.height / bounds.width))
    }
}
