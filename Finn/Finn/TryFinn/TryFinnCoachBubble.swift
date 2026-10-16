import SwiftUI

/// who speaks on Try Finn. For now Finn's "F" monogram; the real coach avatars replace this view
/// alone
struct TryFinnCoachAvatar: View {
    var body: some View {
        FinnBadge(showsOutline: true)
            .accessibilityHidden(true)
    }
}

/// the coach's line: the avatar beside a speech bubble, a short lead-in, then the words that
/// matter in large type
struct TryFinnCoachBubble: View {
    let lead: String
    let emphasis: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            TryFinnCoachAvatar()
            VStack(alignment: .leading, spacing: 6) {
                Text(lead)
                    .font(.body)
                    .foregroundStyle(HomeStyle.supportingText)
                Text(emphasis)
                    .font(.largeTitle.bold())
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Finn: \(lead) \(emphasis)"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("tryFinn.coach")
    }
}

#Preview("Squat") {
    TryFinnCoachBubble(lead: "Try your first exercise:", emphasis: "Squat")
        .padding(20)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    TryFinnCoachBubble(lead: "Try your first exercise:", emphasis: "Push-up")
        .padding(20)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
