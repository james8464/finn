import SwiftUI

/// the last question: how Finn looks. The chosen picture in a large circle, and below it every
/// picture to pick from. The coach is always called Finn; the F comes preselected
struct CoachChoiceView: View {
    @Binding var selection: Coach
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

    /// the pictures to pick from, half the large circle
    private static let thumbnail = OnboardingMetrics.coachPortrait / 2
    /// four a row: three rows that fit the smallest iPhone
    private static let rows = stride(from: 0, to: Coach.all.count, by: 4).map {
        Array(Coach.all[$0 ..< min($0 + 4, Coach.all.count)])
    }

    var body: some View {
        VStack(spacing: OnboardingMetrics.sectionSpacing) {
            CoachAvatar(coach: selection, size: OnboardingMetrics.coachPortrait)
                // one circle per look, so the change cross-fades
                .id(selection.id)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                .frame(maxWidth: .infinity)
            // centred rows, so the last, shorter one stays balanced
            VStack(spacing: OnboardingMetrics.rowSpacing) {
                ForEach(Self.rows, id: \.first?.id) { row in
                    HStack(spacing: OnboardingMetrics.rowSpacing) {
                        ForEach(row) { coach in
                            Button { selection = coach } label: {
                                CoachAvatar(coach: coach, size: Self.thumbnail, isSelected: coach == selection)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(Text(verbatim: coach.look))
                            .accessibilityAddTraits(coach == selection ? .isSelected : [])
                            .accessibilityIdentifier("onboarding.coach.\(coach.id)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Finn's picture")
            .accessibilityIdentifier("onboarding.coach")
        }
        .animation(reduceMotion ? nil : HomeStyle.spring, value: selection)
        .finnFeedback(.selection, trigger: selection)
    }
}

#Preview("Choose your coach") {
    @Previewable @State var coach = Coach.finn
    CoachChoiceView(selection: $coach)
        .padding(.horizontal, OnboardingMetrics.gutter)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    @Previewable @State var coach = Coach.all[2]
    CoachChoiceView(selection: $coach)
        .padding(.horizontal, OnboardingMetrics.gutter)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
