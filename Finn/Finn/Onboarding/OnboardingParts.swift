import SwiftUI

/// "‹ Back" at the top left of the onboarding screens; the chevron alone at accessibility text sizes
struct OnboardingBackButton: View {
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            if typeSize.isAccessibilitySize {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            } else {
                Label("Back", systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
        }
        .accessibilityLabel("Back")
    }
}

/// Finn's answer to a choice, between the options and Continue: small LEDs light up one after
/// the other, then the line fades in. With Reduce Motion the screen shows the line straight away
struct FinnReaction: View {
    let line: String
    /// false while the LEDs are still lighting up
    let speaks: Bool

    /// one pass of the LEDs, after which the line takes their place
    static let waveDuration = FinnLEDs.duration

    var body: some View {
        HStack(spacing: 12) {
            FinnAvatar()
            ZStack(alignment: .leading) {
                if speaks {
                    Text(line)
                        .font(.body)
                        .foregroundStyle(HomeStyle.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                } else {
                    FinnLEDs()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(speaks ? Text("Finn: \(line)") : Text("Finn is replying"))
        .accessibilityIdentifier("onboarding.finnReaction")
    }
}

/// Finn's monogram on a small round card
struct FinnAvatar: View {
    @ScaledMetric(relativeTo: .body) private var size = 36.0

    var body: some View {
        Image("FinnMark")
            .resizable()
            .scaledToFit()
            .padding(size * 0.22)
            .frame(width: size, height: size)
            .background(HomeStyle.card, in: Circle())
            .accessibilityHidden(true)
    }
}

/// five pink LEDs: each one brightens and dims a moment after the one before, so one wave runs
/// from left to right
struct FinnLEDs: View {
    private static let count = 5
    private static let stagger = 0.1
    private static let rise = 0.12
    private static let fall = 0.3
    private static let dim = 0.25
    static let duration = stagger * Double(count - 1) + rise + fall

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< Self.count, id: \.self) { index in
                Circle()
                    .fill(DashboardStyle.accent)
                    .frame(width: 6, height: 6)
                    // every LED's track lasts one whole wave, so they stay in step
                    .keyframeAnimator(initialValue: Self.dim, repeating: true) { led, glow in
                        led.opacity(glow)
                            .shadow(color: DashboardStyle.accent.opacity(glow), radius: 3 * glow)
                    } keyframes: { _ in
                        LinearKeyframe(Self.dim, duration: Self.stagger * Double(index))
                        CubicKeyframe(1, duration: Self.rise)
                        CubicKeyframe(Self.dim, duration: Self.fall)
                        LinearKeyframe(Self.dim, duration: Self.stagger * Double(Self.count - 1 - index))
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

/// the first-name field: the system keyboard, given-name autofill, words capitalised, a pink caret
struct OnboardingNameField: View {
    @Binding var name: String
    var focus: FocusState<Bool>.Binding
    let submit: () -> Void
    @ScaledMetric(relativeTo: .title) private var textSize = 26.0

    var body: some View {
        TextField("Your name", text: $name)
            .font(.system(size: textSize))
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.continue)
            .focused(focus)
            .onSubmit(submit)
            .tint(DashboardStyle.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 68)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .accessibilityIdentifier("onboarding.name")
    }
}

/// a picture still to be supplied. Until its image set has a file, a dashed outline with the
/// asset's name holds its place, so the layout is already the final one
struct OnboardingImageSlot: View {
    let name: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(HomeStyle.supportingText, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .overlay {
                    // a label for the team, not for the person: fixed size, hidden from VoiceOver
                    Text(verbatim: name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(HomeStyle.supportingText)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .padding(8)
                        .accessibilityHidden(true)
                }
        }
    }
}
