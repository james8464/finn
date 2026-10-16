import SwiftUI
import UIKit

/// Try Finn's first screen: Finn names the exercise for the person's level, Posture's drawing and
/// steps show how to move, and Try exercise asks for the camera. Laid out like the onboarding's
/// name screen: Not now at the top, the page, then one filled action at the bottom
struct TryFinnView: View {
    @State private var model: TryFinnViewModel
    /// the camera may open: the presenter closes this screen and starts the set
    let start: (TryFinnExercise) -> Void
    let close: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(model: TryFinnViewModel, start: @escaping (TryFinnExercise) -> Void, close: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.start = start
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TryFinnCoachBubble(lead: String(localized: "Try your first exercise:"),
                                       emphasis: model.exercise.name)
                    MovementAnimationCard(exercise: model.exercise.kind)
                    MovementStepsCard(exercise: model.exercise.kind)
                    target
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            Group {
                if let blocked = model.blockedAccess {
                    cameraBlocked(blocked)
                } else {
                    tryButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .tint(HomeStyle.accent)
        // back from Settings with the camera allowed: Try exercise shows again
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshAccess() }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button(action: close) { Text("Not now").frame(minHeight: 44) }
                .accessibilityIdentifier("tryFinn.close")
        }
    }

    private var target: some View {
        Label {
            Text("Target: \(model.exercise.reps) reps")
        } icon: {
            Image(systemName: "target").foregroundStyle(DashboardStyle.accent)
        }
        .font(.headline)
        .accessibilityIdentifier("tryFinn.target")
    }

    private var tryButton: some View {
        Button {
            Task {
                if await model.tryExercise() { start(model.exercise) }
            }
        } label: {
            PrimaryActionLabel(title: "Try exercise")
        }
        .buttonStyle(PressableStyle())
        .disabled(model.isRequesting)
        .accessibilityHint("Opens the camera. Finn counts your reps and checks your form.")
        .accessibilityIdentifier("tryFinn.tryExercise")
    }

    /// the camera is off or restricted: why Finn needs it, and the way to Settings. Not now, at
    /// the top, still closes the screen
    private func cameraBlocked(_ status: TryFinnCameraAccess.Status) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(status == .restricted ? String(localized: "Camera access is restricted")
                                            : String(localized: "Camera access is off"),
                      systemImage: "video.slash")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(status == .restricted
                     ? String(localized: "Something on this iPhone, such as Screen Time, limits the camera. Finn needs it to count your reps and check your form. Video is not saved.")
                     : String(localized: "Finn needs the camera to count your reps and check your form. Video is not saved. Turn on Camera for Finn in Settings."))
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tryFinn.cameraBlocked")
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                PrimaryActionLabel(title: "Open Settings", symbol: "arrow.up.right")
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens Finn’s page in Settings")
            .accessibilityIdentifier("tryFinn.openSettings")
        }
    }
}

#if DEBUG
#Preview("Beginner") {
    TryFinnView(model: TryFinnViewModel(level: .new, camera: .fixed(.notDetermined)),
                start: { _ in }, close: {})
        .preferredColorScheme(.dark)
}

#Preview("Intermediate") {
    TryFinnView(model: TryFinnViewModel(level: .regular, camera: .fixed(.notDetermined)),
                start: { _ in }, close: {})
        .preferredColorScheme(.dark)
}

#Preview("Advanced") {
    TryFinnView(model: TryFinnViewModel(level: .experienced, camera: .fixed(.notDetermined)),
                start: { _ in }, close: {})
        .preferredColorScheme(.dark)
}

#Preview("No level") {
    TryFinnView(model: TryFinnViewModel(level: nil, camera: .fixed(.notDetermined)),
                start: { _ in }, close: {})
        .preferredColorScheme(.dark)
}

#Preview("Camera denied") {
    let model = TryFinnViewModel(level: .new, camera: .fixed(.denied))
    model.showBlocked(.denied)
    return TryFinnView(model: model, start: { _ in }, close: {})
        .preferredColorScheme(.dark)
}

#Preview("Camera restricted, accessibility text") {
    let model = TryFinnViewModel(level: .experienced, camera: .fixed(.restricted))
    model.showBlocked(.restricted)
    return TryFinnView(model: model, start: { _ in }, close: {})
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

#endif
