import SwiftUI

/// over Home after Skip on the plan offer: the chosen coach offers one workout for free. A sheet,
/// so a tap outside or a swipe down leaves the person on Home, where Try Finn opens the same workout
struct FreeWorkoutOfferView: View {
    let coach: Coach
    let accept: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize = OnboardingMetrics.coachPortrait / 2

    private var line: String {
        String(localized: "You seem not ready to start training now. I can offer you one training for free.")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OnboardingMetrics.sectionSpacing) {
                CoachAvatar(coach: coach, size: avatarSize)
                Text(line)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(String(localized: "Finn: \(line)"))
                    .accessibilityIdentifier("freeWorkout.line")
                Button(action: accept) {
                    PrimaryActionLabel(title: "Start my free workout")
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Opens your free workout")
                .accessibilityIdentifier("freeWorkout.accept")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, OnboardingMetrics.gutter)
            .padding(.top, OnboardingMetrics.pageTop)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Over Home") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FreeWorkoutOfferView(coach: .finn, accept: {})
                .presentationDetents([.medium])
                .presentationBackground(HomeStyle.background)
        }
        .preferredColorScheme(.dark)
}

#Preview("Portrait coach, accessibility text") {
    FreeWorkoutOfferView(coach: Coach.all[1], accept: {})
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
