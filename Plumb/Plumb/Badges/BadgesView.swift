import SwiftUI

/// the Awards screen, on the dashboard's backdrop: every badge, earned ones with the measured fact
/// behind them and the date, the rest with how to earn them.
struct BadgesView: View {
    let ledger: BadgeLedger

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if ledger.count == 0 {
                    emptyState
                } else {
                    Text(ledger.count == 1 ? "1 badge earned" : "\(ledger.count) badges earned")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DashboardStyle.secondary)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("badges.count")
                }
                ForEach(ledger.all, id: \.kind) { entry in
                    BadgeRow(kind: entry.kind, earned: entry.earned)
                }
                Text("Every badge rests on sets measured on this iPhone. Nothing leaves it.")
                    .font(.footnote)
                    .foregroundStyle(DashboardStyle.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .background { HomeBackdrop().overlay(.black.opacity(0.45)).ignoresSafeArea() }
        .navigationTitle("Awards")
        .toolbarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear { ledger.acknowledge() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            BadgeMark(kind: .firstSet, earned: false, size: 56)
            Text("Your first badge is one set away.")
                .font(.title2.weight(.semibold))
            Text("Badges come from what Plumb measures: a set, a record, a longer range. Here is what each one takes.")
                .font(.subheadline)
                .foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BadgeGlass())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("badges.empty")
    }
}

/// the dashboard's translucent card, for the Awards screen and the unlock card.
struct BadgeGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 15

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                if reduceTransparency {
                    shape.fill(Color(white: 0.09))
                } else {
                    shape.fill(.ultraThinMaterial).opacity(0.8).environment(\.colorScheme, .dark)
                    shape.fill(.black.opacity(0.16))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.13)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
    }
}

/// one badge: its mark, its name, and either how it was earned or how to earn it.
struct BadgeRow: View {
    let kind: BadgeKind
    let earned: EarnedBadge?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BadgeMark(kind: kind, earned: earned != nil, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.headline)
                if let earned {
                    Text(earned.detail)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(earned.earnedAt.formatted(.dateTime.day().month(.wide).year().hour().minute()))
                        .font(.footnote)
                        .foregroundStyle(DashboardStyle.secondary)
                } else {
                    Text(kind.rule)
                        .font(.subheadline)
                        .foregroundStyle(DashboardStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BadgeGlass())
        .opacity(earned == nil ? 0.72 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned == nil ? "Not earned yet" : "Earned")
    }
}

/// the badge itself: a lime disc when earned, a dashed outline when not.
struct BadgeMark: View {
    let kind: BadgeKind
    let earned: Bool
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(DashboardStyle.lime)
            } else {
                Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
            }
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(earned ? Color.black : Color.white.opacity(0.55))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// inside the dashboard's Awards card: the latest marks and a count, or an invitation.
struct AwardsCardContent<Heading: View>: View {
    let badges: [EarnedBadge]
    let heading: Heading

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
            Spacer(minLength: 0)
            HStack(spacing: -8) {
                if badges.isEmpty {
                    BadgeMark(kind: .firstSet, earned: false, size: 34)
                } else {
                    ForEach(Array(badges.suffix(3).reversed()), id: \.kind) { badge in
                        BadgeMark(kind: badge.kind, earned: true, size: 34)
                            .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 1.5))
                    }
                }
            }
            Text(badges.isEmpty ? "Your first badge is one set away."
                 : (badges.count == 1 ? "1 badge · \(badges.last!.kind.title)"
                    : "\(badges.count) badges · latest: \(badges.last!.kind.title)"))
                .font(.footnote)
                .foregroundStyle(DashboardStyle.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// shown on the result once per set, when the set earned badges: the marks drop in, then the
/// person reads why. Sober by design.
struct BadgeUnlockCard: View {
    let badges: [EarnedBadge]
    let open: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(Array(badges.enumerated()), id: \.element.kind) { index, badge in
                        BadgeMark(kind: badge.kind, earned: true, size: 44)
                            .scaleEffect(shown || reduceMotion ? 1 : 0.4)
                            .opacity(shown || reduceMotion ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(index) * 0.12), value: shown)
                    }
                    Spacer(minLength: 0)
                    Text(badges.count == 1 ? "New badge" : "\(badges.count) new badges")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.72))
                }
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.kind.title).font(.headline)
                        Text(badge.detail)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: shown)
        .onAppear { shown = true }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result.badges")
    }
}
