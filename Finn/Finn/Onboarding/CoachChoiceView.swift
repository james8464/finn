import SwiftUI

/// the last question: the chosen coach in a large circle, and a wheel beside it to browse the
/// others. Finn comes preselected. At accessibility text sizes the wheel moves under the circle
struct CoachChoiceView: View {
    @Binding var selection: Coach
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: OnboardingMetrics.sectionSpacing))
            : AnyLayout(HStackLayout(spacing: OnboardingMetrics.sectionSpacing))
        layout {
            CoachAvatar(coach: selection, size: OnboardingMetrics.coachPortrait, isSelected: true)
                // one circle per coach, so the change cross-fades
                .id(selection.id)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            Picker("Coach", selection: $selection) {
                ForEach(Coach.all) { coach in
                    Text(verbatim: coach.name).tag(coach)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Coach")
            .accessibilityHint("Swipe up or down to pick another coach")
            .accessibilityIdentifier("onboarding.coach")
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : HomeStyle.spring, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Choose your coach") {
    @Previewable @State var coach = Coach.finn
    CoachChoiceView(selection: $coach)
        .padding(.horizontal, OnboardingMetrics.gutter)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    @Previewable @State var coach = Coach.finn
    CoachChoiceView(selection: $coach)
        .padding(.horizontal, OnboardingMetrics.gutter)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
