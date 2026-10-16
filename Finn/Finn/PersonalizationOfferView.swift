import SwiftUI

/// optional Health access, offered after the first camera-measured set
struct PersonalizationOfferView: View {
    let answer: (Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.largeTitle)
                    .foregroundStyle(DashboardStyle.accent)
                    .accessibilityHidden(true)
                WrappingText(
                    text: String(localized: "Personalize with Health"),
                    style: .title2,
                    weight: .bold
                )
                .accessibilityAddTraits(.isHeader)
                WrappingText(
                    text: String(
                        localized: "Use heart rate, recovery, sleep, workouts, age, weight and height from Health to tailor rest times and suggest lighter days."
                    )
                )
                WrappingText(
                    text: String(localized: "Data stays on this iPhone. Change access anytime in Options."),
                    colour: .secondaryLabel
                )
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button { answer(true) } label: {
                    WrappingText(text: String(localized: "Continue"), colour: .black, alignment: .center)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPageStyle.action)
                .controlSize(.large)
                .accessibilityLabel("Continue")
                .accessibilityIdentifier("offer.personalize")
                Button { answer(false) } label: {
                    WrappingText(text: String(localized: "Later"), alignment: .center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Later")
                .accessibilityIdentifier("offer.later")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(HomeStyle.background)
        .tint(HomeStyle.accent)
        .presentationDragIndicator(.visible)
    }
}
