import SwiftUI

/// The Awards page on its own, for the places that still push it: the section, full screen.
struct BadgesView: View {
    let ledger: BadgeLedger

    var body: some View {
        ScrollView {
            BadgesSection(ledger: ledger)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .darkScreen()
        .navigationTitle("")
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }
}

/// The Awards section of Stats, made to sit in a scroll: the title, a row of earned badges, then
/// the ones left to earn with their condition. Touching a badge opens its detail.
struct BadgesSection: View {
    let ledger: BadgeLedger
    @State private var selected: BadgeEntry?

    var body: some View {
        let entries = ledger.all.map { BadgeEntry(kind: $0.kind, earned: $0.earned) }
        let earned = entries.filter { $0.earned != nil }
        let remaining = entries.filter { $0.earned == nil }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Awards")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(ledger.count == 1 ? "1 badge earned" : "\(ledger.count) badges earned")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HomeStyle.supportingText)
                    .accessibilityIdentifier("badges.count")
            }
            if earned.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(earned) { entry in
                            Button { selected = entry } label: {
                                VStack(spacing: 8) {
                                    BadgeMark(kind: entry.kind, earned: true, size: 60)
                                    Text(entry.kind.title)
                                        .font(.caption.weight(.medium))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 84)
                                }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(entry.kind.title)
                            .accessibilityValue("Earned")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            if !remaining.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(remaining.enumerated()), id: \.element.id) { index, entry in
                        Button { selected = entry } label: {
                            HStack(alignment: .top, spacing: 12) {
                                BadgeMark(kind: entry.kind, earned: false, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.kind.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.kind.rule)
                                        .font(.footnote)
                                        .foregroundStyle(HomeStyle.supportingText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityValue("Not earned yet")
                        if index < remaining.count - 1 {
                            Divider().overlay(HomeStyle.hairline)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .plumbGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .foregroundStyle(.white)
        .onAppear { ledger.acknowledge() }
        .sheet(item: $selected) { entry in
            BadgeDetailView(kind: entry.kind, earned: entry.earned)
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 14) {
            BadgeMark(kind: .firstSet, earned: false, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your first badge is one set away.")
                    .font(.headline)
                Text("Badges come from what Plumb measures: a set, a record, a longer range. Here is what each one takes.")
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .darkGlassCard(padding: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("badges.empty")
    }
}

/// A badge and whether it was earned, so a sheet can show it.
struct BadgeEntry: Identifiable, Equatable {
    let kind: BadgeKind
    let earned: EarnedBadge?
    var id: BadgeKind { kind }
}

/// One badge on its own sheet: the mark large, the measured fact and the date when earned, the
/// condition when not.
struct BadgeDetailView: View {
    let kind: BadgeKind
    let earned: EarnedBadge?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                BadgeMark(kind: kind, earned: earned != nil, size: 120)
                    .padding(.top, 36)
                Text(kind.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let earned {
                    Text(earned.detail)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(earned.earnedAt.formatted(.dateTime.day().month(.wide).year().hour().minute()))
                        .font(.footnote)
                        .foregroundStyle(HomeStyle.supportingText)
                } else {
                    Text(kind.rule)
                        .font(.body)
                        .foregroundStyle(HomeStyle.supportingText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Every badge rests on sets measured on this iPhone. Nothing leaves it.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 24)
            Button { dismiss() } label: {
                PrimaryActionLabel(title: "Done")
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .darkScreen()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
        .accessibilityIdentifier("badges.detail")
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
        .foregroundStyle(.white)
        .darkGlassCard(padding: 16)
        .opacity(earned == nil ? 0.75 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned == nil ? "Not earned yet" : "Earned")
    }
}

/// The badge itself: a white disc when earned, a dashed white outline when not.
struct BadgeMark: View {
    let kind: BadgeKind
    let earned: Bool
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(.white)
                    .shadow(color: .white.opacity(0.25), radius: size * 0.18)
            } else {
                Circle().strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
            }
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(earned ? Color.black : Color.white.opacity(0.55))
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
                        .foregroundStyle(HomeStyle.supportingText)
                }
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.kind.title).font(.headline)
                        Text(badge.detail)
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .foregroundStyle(.white)
            .darkGlassCard()
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: shown)
        .onAppear { shown = true }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result.badges")
    }
}
