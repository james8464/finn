import SwiftUI

/// the light pink outline that groups cards: 1 pt, 40% pink. Its corners are concentric with the
/// cards inside: each outline radius is the card radius plus the padding
struct FinnOutline<Content: View>: View {
    /// the radii of the cards the outline holds, at its top and bottom
    var topRadius = DashboardStyle.cardRadius
    var bottomRadius = DashboardStyle.cardRadius
    @ViewBuilder var content: Content

    var body: some View {
        let padding = DashboardStyle.cardSpacing
        let top = topRadius + padding, bottom = bottomRadius + padding
        content
            .padding(padding)
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: top,
                    bottomLeadingRadius: bottom,
                    bottomTrailingRadius: bottom,
                    topTrailingRadius: top,
                    style: .continuous
                )
                .strokeBorder(DashboardStyle.accent.opacity(DashboardStyle.outlineOpacity), lineWidth: 1)
                .accessibilityHidden(true)
            }
    }
}

/// a Home glass card: full width, 14 pt in, no border
struct DashboardCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(DashboardGlass(showsBorder: false))
            .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.cardRadius))
    }
}

/// the title of a Home card
struct DashboardHeading: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
    }
}
