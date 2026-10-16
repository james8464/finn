import SwiftUI

/// one moment to fix and one done right, each with Finn's comment. Finn keeps no camera images
/// today, so this shows its empty state: the two places, a dash for each comment, and why
struct PostureMomentsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wrong and right")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                moment("To fix", symbol: "xmark")
                moment("Done right", symbol: "checkmark")
            }
            .accessibilityHidden(true)
            Text("No photos yet")
                .font(.subheadline.weight(.semibold))
            Text(
                "When Finn has photos of this exercise, you’ll see one moment to fix and one done right, each with Finn’s comment."
            )
            .font(.subheadline)
            .foregroundStyle(DashboardStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(DashboardGlass())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("posture.moments")
    }

    private func moment(_ title: LocalizedStringKey, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.25))
                }
                .overlay(alignment: .topLeading) {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(symbol == "checkmark" ? DashboardStyle.accent : DashboardStyle
                            .secondary)
                        .padding(8)
                }
            Text(title).font(.subheadline.weight(.semibold))
            Text(verbatim: "—").font(.subheadline).foregroundStyle(DashboardStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
