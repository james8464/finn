import SwiftUI

/// Optional Health access, offered after the first camera-measured set.
struct PersonalizationOfferView: View {
    let answer: (Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.largeTitle)
                    .foregroundStyle(DashboardStyle.accent)
                    .accessibilityHidden(true)
                Text("Personalize with Health")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Use heart rate, recovery, sleep, workouts, age, weight and height from Health to tailor rest times and suggest lighter days.")
                Text("Data stays on this iPhone. Change access anytime in Options.")
                    .foregroundStyle(HomeStyle.supportingText)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button { answer(true) } label: {
                    Text("Continue")
                        .foregroundStyle(HomeStyle.onAccent)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomeStyle.filledAccent)
                .controlSize(.large)
                .accessibilityIdentifier("offer.personalize")
                Button { answer(false) } label: {
                    Text("Later").frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
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
