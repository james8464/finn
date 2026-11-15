import SwiftUI

/// a coach's face in a circle, the same style at every size
struct CoachAvatar: View {
    let coach: Coach
    let size: CGFloat
    /// the pink ring of the chosen coach
    var isSelected = false

    /// the monogram's margin, as a share of the size
    private static let inset = 0.22
    private static let ringWidth = 2.0

    var body: some View {
        Group {
            switch coach.face {
            case .monogram(let mark):
                Image(mark)
                    .resizable()
                    .scaledToFit()
                    .padding(size * Self.inset)
                    .frame(width: size, height: size)
                    .background(HomeStyle.card, in: Circle())
            case .portrait(let portrait):
                Image(portrait)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .overlay {
            if isSelected {
                Circle().strokeBorder(DashboardStyle.accent, lineWidth: Self.ringWidth)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Coaches") {
    VStack {
        ForEach([Array(Coach.all.prefix(6)), Array(Coach.all.dropFirst(6))], id: \.first?.id) { row in
            HStack {
                ForEach(row) { coach in
                    CoachAvatar(coach: coach, size: OnboardingMetrics.coachPortrait / 3, isSelected: coach == .finn)
                }
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
