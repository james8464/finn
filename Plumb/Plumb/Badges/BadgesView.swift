import SwiftUI

/// The Awards page: every badge, earned ones with the measured fact behind them and the date, the
/// rest with how to earn them. Black on white, like the rest of Plumb.
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
                        .foregroundStyle(HomeStyle.supportingText)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("badges.count")
                }
                ForEach(ledger.all, id: \.kind) { entry in
                    BadgeRow(kind: entry.kind, earned: entry.earned)
                }
                Text("Every badge rests on sets measured on this iPhone. Nothing leaves it.")
                    .font(.footnote)
                    .foregroundStyle(HomeStyle.supportingText)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(HomeStyle.background.ignoresSafeArea())
        .navigationTitle("Awards")
        .toolbarTitleDisplayMode(.inline)
        .onAppear { ledger.acknowledge() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            BadgeMark(kind: .firstSet, earned: false, size: 56)
            Text("Your first badge is one set away.")
                .font(.title2.weight(.semibold))
            Text("Badges come from what Plumb measures: a set, a record, a longer range. Here is what each one takes.")
                .font(.subheadline)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .optionCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("badges.empty")
    }
}

/// One badge: its mark, its name, and either how it was earned or how to earn it.
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
                        .foregroundStyle(HomeStyle.supportingText)
                } else {
                    Text(kind.rule)
                        .font(.subheadline)
                        .foregroundStyle(HomeStyle.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .opacity(earned == nil ? 0.72 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned == nil ? "Not earned yet" : "Earned")
    }
}

/// The badge itself: a black disc when earned, a dashed outline when not.
struct BadgeMark: View {
    let kind: BadgeKind
    let earned: Bool
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(Color.primary)
            } else {
                Circle().strokeBorder(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
            }
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(earned ? Color(uiColor: .systemBackground) : Color.primary.opacity(0.55))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Shown on the result once per set, when the set earned badges: the marks drop in, then the
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
