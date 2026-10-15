import SwiftUI

/// What the screens without a camera (welcome, Coach, Awards, Options, Privacy) add to `HomeStyle`:
/// the whole-screen surface, a glass panel for a group of content, and a large in-content title so
/// a tab reads the same whether or not a navigation bar is above it.
extension View {
    /// A group of content on its own glass panel, edged by the hairline.
    func darkGlassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plumbGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// The whole screen: silk behind, white text, dark bars.
    func darkScreen() -> some View {
        self.foregroundStyle(.white)
            .tint(.white)
            .plumbBackdrop()
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// The large title of a tab screen, in the content rather than the bar, so it sits on the silk.
struct DarkScreenTitle: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
