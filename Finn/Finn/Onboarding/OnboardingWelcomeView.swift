import SwiftUI

/// the first onboarding screen: the wordmark, the promise and the pink bar from the brand cover,
/// then Continue. Type sizes follow the screen width, so the lockup keeps its shape on every
/// iPhone; the gaps and the bar keep the cover's proportions to those sizes
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var screenWidth: CGFloat = 0
    /// how wide each line sets per point of type, measured in the person's language and settings
    @State private var wordmarkWidthPerPoint: CGFloat = 0
    @State private var taglineWidthPerPoint: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    /// the onboarding's side margins
    private static let margin: CGFloat = 20
    /// "Finn" takes a little more than half the screen width
    private static let wordmarkShare: CGFloat = 0.55
    /// the Liquid Glass ring around Continue
    private static let rim: CGFloat = 6
    /// reference sizes near the final ones, so SF Pro's size-specific tracking matches
    private static let wordmarkReference: CGFloat = 112
    private static let taglineReference: CGFloat = 32
    /// the gap under "Finn" is a quarter tighter than the cover's, so the tagline reads with the wordmark
    private static let wordmarkGapShare: CGFloat = 0.75
    /// SF Pro's cap height, in ems
    private static let capHeight: CGFloat = 0.7046

    /// the brand cover in Pencil ("Finn — brand theme cover"), in points. Its lines are set at 92
    /// and 44 pt, so each value below is read as a share of the line it belongs to
    private enum Cover {
        static let wordmarkSize: CGFloat = 92
        static let taglineSize: CGFloat = 44
        /// from the baseline of "Finn" to the cap height of the tagline
        static let wordmarkToTagline: CGFloat = 41.5
        /// from the tagline's baseline to the top of the bar
        static let taglineToBar: CGFloat = 24.4
        static let barLength: CGFloat = 116
        static let barThickness: CGFloat = 5
        /// "Finn" sits 4 pt left of the tagline so the stem of the F lines up with the S
        static let wordmarkInset: CGFloat = 4
    }

    private struct Metrics {
        let wordmark: CGFloat
        let tagline: CGFloat
        /// both measured down from the baseline of "Finn"
        let taglineBaseline: CGFloat
        let barTop: CGFloat
    }

    private var metrics: Metrics? {
        guard screenWidth > 0, wordmarkWidthPerPoint > 0, taglineWidthPerPoint > 0 else {
            return nil
        }
        let wordmark = screenWidth * Self.wordmarkShare / wordmarkWidthPerPoint
        let tagline = (screenWidth - 2 * Self.margin) / taglineWidthPerPoint
        let taglineBaseline = wordmark * Cover.wordmarkToTagline / Cover.wordmarkSize * Self.wordmarkGapShare
            + tagline * Self.capHeight
        return Metrics(
            wordmark: wordmark,
            tagline: tagline,
            taglineBaseline: taglineBaseline,
            barTop: taglineBaseline + tagline * Cover.taglineToBar / Cover.taglineSize
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            lockup
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, Self.margin)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .background { measurements }
        .background(HomeStyle.background.ignoresSafeArea())
    }

    /// each line is pinned to the baseline of "Finn", so the gaps are the cover's whatever the font's line height
    @ViewBuilder private var lockup: some View {
        if let metrics {
            ZStack(alignment: .topLeading) {
                Text(verbatim: "Finn")
                    .font(.system(size: metrics.wordmark, weight: .semibold))
                    .alignmentGuide(.top) { $0[.firstTextBaseline] }
                    .offset(x: -metrics.wordmark * Cover.wordmarkInset / Cover.wordmarkSize)
                Text("Stronger starts together")
                    .font(.system(size: metrics.tagline, weight: .semibold))
                    .alignmentGuide(.top) { $0[.firstTextBaseline] - metrics.taglineBaseline }
                Rectangle()
                    .fill(DashboardStyle.accent)
                    .frame(
                        width: metrics.tagline * Cover.barLength / Cover.taglineSize,
                        height: metrics.tagline * Cover.barThickness / Cover.taglineSize
                    )
                    .alignmentGuide(.top) { _ in -metrics.barTop }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    /// both lines set once at a reference size, out of sight, to learn their width per point
    private var measurements: some View {
        ZStack {
            Text(verbatim: "Finn")
                .font(.system(size: Self.wordmarkReference, weight: .semibold))
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    wordmarkWidthPerPoint = $0 / Self.wordmarkReference
                }
            Text("Stronger starts together")
                .font(.system(size: Self.taglineReference, weight: .semibold))
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    taglineWidthPerPoint = $0 / Self.taglineReference
                }
        }
        .hidden()
        .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: 2) {
            Button(action: onContinue) {
                // the glass is a layer behind the opaque pill, a rim wider on each side, so only a
                // ring of it shows. Wrapping the pill itself would make it glass content and dim it
                PrimaryActionLabel(title: "Continue")
                    .background {
                        Color.clear
                            .glassEffect(.regular.interactive(), in: rimShape)
                            .padding(-Self.rim)
                    }
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("onboarding.welcome.continue")
            // the steps have a Skip row under Continue; holding its place keeps Continue at the same height
            Text("Skip")
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
                .hidden()
                .accessibilityHidden(true)
        }
    }

    /// concentric with the pill, which turns into a rounded rectangle at accessibility sizes
    private var rimShape: AnyShape {
        typeSize.isAccessibilitySize
            ? AnyShape(RoundedRectangle(cornerRadius: 24 + Self.rim, style: .continuous))
            : AnyShape(Capsule())
    }
}

#Preview("Dark") {
    OnboardingWelcomeView {}
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    OnboardingWelcomeView {}
        .preferredColorScheme(.light)
}

#Preview("Accessibility text") {
    OnboardingWelcomeView {}
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

#Preview("Smallest iPhone", traits: .fixedLayout(width: 375, height: 667)) {
    OnboardingWelcomeView {}
        .preferredColorScheme(.dark)
}
