import SwiftUI

/// Optional Health access, offered after the first camera-measured set.
struct PersonalizationOfferView: View {
    let answer: (Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.largeTitle)
                    .foregroundStyle(.pink)
                    .accessibilityHidden(true)
                Text("Make Plumb more personal?")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Use heart rate, recovery, sleep, workouts, age, weight and height from Health to tailor rest times and suggest lighter days.")
                Text("Your data stays on this iPhone. Each tip explains what it uses. Turn this off anytime in Options.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button { answer(true) } label: {
                    Text("Yes, personalize").frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomeStyle.filledAccent)
                .controlSize(.large)
                .accessibilityIdentifier("offer.personalize")
                Button("Later") { answer(false) }
                    .frame(maxWidth: .infinity, minHeight: 44)
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
