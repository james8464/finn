import SwiftUI

/// the floating pink button that opens the selection step before a workout
struct LaunchWorkoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Launch workout", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(minHeight: 52)
                .foregroundStyle(.black)
                .background(DashboardStyle.accent, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Choose an exercise before the camera opens")
        .accessibilityIdentifier("workout.launch")
    }
}
