import SwiftUI

/// demo 1: the athlete mid-set and, on the iPhone beside him, Finn coaching live. The phone
/// screen is an asset still to come (`OnboardingDemoPhone`)
struct LiveCoachingDemo: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Color.clear
            .frame(height: typeSize.isAccessibilitySize ? 300 : 360)
            .overlay {
                Image("DemoAthlete")
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                OnboardingImageSlot(name: "OnboardingDemoPhone")
                    .frame(width: 116, height: 236)
                    .padding(16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Illustration: a man training while Finn coaches him live on his iPhone.")
            .accessibilityAddTraits(.isImage)
    }
}

/// demo 2: AirPods for the spoken cues and an Apple Watch whose screen shows the workout, for the
/// taps on the wrist. The Watch is an asset still to come (`OnboardingDemoWatch`)
struct WearablesDemo: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            device("AirPods") {
                Image(systemName: "airpodspro")
                    .font(.system(size: 88, weight: .light))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            device("Apple Watch") {
                OnboardingImageSlot(name: "OnboardingDemoWatch")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration: AirPods, and an Apple Watch showing a workout in progress.")
        .accessibilityAddTraits(.isImage)
    }

    private func device<Picture: View>(_ name: LocalizedStringKey,
                                       @ViewBuilder picture: () -> Picture) -> some View {
        VStack(spacing: 12) {
            picture()
                .frame(height: typeSize.isAccessibilitySize ? 200 : 236)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(HomeStyle.supportingText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Demos") {
    VStack(spacing: 24) {
        LiveCoachingDemo()
        WearablesDemo()
    }
    .padding(20)
    .preferredColorScheme(.dark)
}
