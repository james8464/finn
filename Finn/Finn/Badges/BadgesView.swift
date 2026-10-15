import SwiftUI

struct BadgesView: View {
    let ledger: BadgeLedger
    @State private var selected: BadgeEntry?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "rosette")
                        .font(.largeTitle).foregroundStyle(HomeStyle.accent)
                        .accessibilityHidden(true)
                    Text(ledger.count == 0
                         ? "No awards yet"
                         : "\(ledger.count) awards earned")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("badges.count")
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(ledger.count == 0 ? "badges.empty" : "badges.summary")
            }
            if !ledger.earned.isEmpty {
                Section("Earned") {
                    ForEach(ledger.all.filter { $0.earned != nil }, id: \.kind) { entry in
                        badgeButton(kind: entry.kind, earned: entry.earned)
                    }
                }
            }
            Section {
                ForEach(ledger.all.filter { $0.earned == nil }, id: \.kind) { entry in
                    badgeButton(kind: entry.kind, earned: nil)
                }
            } header: {
                Text("Milestones")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Awards")
        .onAppear { ledger.acknowledge() }
        .sheet(item: $selected) { entry in
            BadgeDetailView(kind: entry.kind, earned: entry.earned)
        }
    }

    private func badgeButton(kind: BadgeKind, earned: EarnedBadge?) -> some View {
        Button { selected = BadgeEntry(kind: kind, earned: earned) } label: {
            BadgeRow(kind: kind, earned: earned)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("badge.row")
    }
}

struct BadgeRow: View {
    let kind: BadgeKind
    let earned: EarnedBadge?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BadgeMark(kind: kind, earned: earned != nil)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(earned?.detail ?? kind.rule)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let earned {
                    Label(earned.earnedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned == nil ? "Not earned yet" : "Earned")
    }
}

struct BadgeMark: View {
    let kind: BadgeKind
    let earned: Bool
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(DashboardStyle.accent)
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

/// inside the dashboard's Awards card: the latest marks and a count, or an invitation
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
            Text(badges.isEmpty ? "No awards yet"
                 : (badges.count == 1 ? "1 badge · \(badges.last!.kind.title)"
                    : "\(badges.count) badges · latest: \(badges.last!.kind.title)"))
                .font(.footnote)
                .foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// inline completion feedback. Awards never interrupt a workout with a modal or push alert.
struct BadgeUnlockCard: View {
    let badges: [EarnedBadge]
    let open: () -> Void
    @State private var shown = false

    var body: some View {
        Button(action: open) {
            HomeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(badges.count == 1 ? "Award earned" : "\(badges.count) awards earned", systemImage: "rosette")
                        .font(.headline).foregroundStyle(HomeStyle.accent)
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(badge.kind.title).font(.headline)
                            Text(badge.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Label("View awards", systemImage: "chevron.right").font(.subheadline)
                        .foregroundStyle(HomeStyle.accent)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: shown)
        .onAppear { shown = true }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result.badges")
    }
}

struct BadgeEntry: Identifiable, Equatable {
    let kind: BadgeKind
    let earned: EarnedBadge?
    var id: BadgeKind { kind }
}

/// one badge on its own sheet: the mark large, the measured fact and the date when earned, the
/// condition when not
struct BadgeDetailView: View {
    let kind: BadgeKind
    let earned: EarnedBadge?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                BadgeMark(kind: kind, earned: earned != nil, size: 120)
                    .padding(.top, 36)
                WrappingText(text: kind.title, style: .title1, weight: .bold, alignment: .center)
                    .accessibilityAddTraits(.isHeader)
                if let earned {
                    WrappingText(text: earned.detail, alignment: .center)
                    WrappingText(text: earned.earnedAt.formatted(.dateTime.day().month(.wide).year().hour().minute()),
                                 style: .footnote, colour: .secondaryLabel, alignment: .center)
                } else {
                    WrappingText(text: kind.rule, colour: .secondaryLabel, alignment: .center)
                }
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
        }
        .background(HomeStyle.background)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(HomeStyle.background)
        .accessibilityIdentifier("badges.detail")
    }
}
