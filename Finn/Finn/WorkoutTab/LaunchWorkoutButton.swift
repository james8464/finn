import SwiftUI

/// the floating Liquid Glass button that opens the selection step before a workout. Only its
/// label is pink: the glass stays dark on the dark tab
struct LaunchWorkoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Launch workout", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(DashboardStyle.accent)
                .padding(.horizontal, 6)
                .frame(minHeight: 40)
        }
        // the glass's own black tint keeps it dark on the dark tab
        .buttonStyle(.glass(.regular.tint(.black)))
        .controlSize(.large)
        .accessibilityHint("Choose an exercise before the camera opens")
        .accessibilityIdentifier("workout.launch")
    }
}
