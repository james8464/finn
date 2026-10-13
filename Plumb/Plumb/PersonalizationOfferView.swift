import SwiftUI

/// Asked once, after the first measured set filmed with the camera: whether Plumb may read Health to
/// adapt its advice. "Yes, personalize" opens Health's permission sheet; "Later" leaves everything off
/// (Options keeps the switch).
struct PersonalizationOfferView: View {
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Make Plumb more personal?")
                .font(.title2.bold())
            Text("Plumb can read your heart rate, recovery, sleep, recent workouts, age, weight and height from Health to adapt rest times and suggest lighter days.")
            Text("It stays on this iPhone, each tip says which data it uses, and you can turn it off in Options.")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                answer(true)
            } label: {
                Text("Yes, personalize")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("offer.personalize")
            Button {
                answer(false)
            } label: {
                Text("Later")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("offer.later")
        }
        .padding(24)
    }
}
