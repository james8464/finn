import SwiftUI

/// a coach the person can train with, picked at the last question. Finn is the default; to add a
/// coach, add it to `all`, with its mark once the design exists
nonisolated struct Coach: Identifiable, Hashable, Sendable {
    /// what `FinnPreferences` saves; never change it once shipped
    let id: String
    let name: String
    /// the coach's image set; nil until its design exists, and a silhouette stands in
    let mark: String?

    static let finn = Coach(id: "finn", name: "Finn", mark: "FinnMark")

    /// every coach, in the order the picker lists them
    static let all: [Coach] = [
        .finn,
        // placeholders: no design yet
        Coach(id: "ava", name: "Ava", mark: nil),
        Coach(id: "kai", name: "Kai", mark: nil),
    ]

    /// the saved coach, or Finn when nothing is saved or the coach is gone
    static func stored(_ id: String?) -> Coach {
        all.first { $0.id == id } ?? .finn
    }
}

/// a coach's face: the mark on a round card, the same style at every size
struct CoachAvatar: View {
    let coach: Coach
    let size: CGFloat
    /// the pink ring of the chosen coach
    var isSelected = false

    /// the mark's margin, as a share of the size
    private static let inset = 0.22
    private static let ringWidth = 2.0

    var body: some View {
        Group {
            if let mark = coach.mark {
                Image(mark)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(HomeStyle.supportingText)
            }
        }
        .padding(size * Self.inset)
        .frame(width: size, height: size)
        .background(HomeStyle.card, in: Circle())
        .overlay {
            if isSelected {
                Circle().strokeBorder(DashboardStyle.accent, lineWidth: Self.ringWidth)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Coaches") {
    HStack {
        ForEach(Coach.all) { coach in
            CoachAvatar(coach: coach, size: OnboardingMetrics.coachPortrait / 2, isSelected: coach == .finn)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
