import SwiftUI

struct BadgesView: View {
    let ledger: BadgeLedger

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "rosette")
                        .font(.largeTitle).foregroundStyle(HomeStyle.accent)
                        .accessibilityHidden(true)
                    Text(ledger.count == 0 ? "Every set is a beginning." : "Your progress, recognised.")
                        .font(.title2.bold())
                    Text(ledger.count == 0
                         ? "Finish a measured set to earn your first award."
                         : "\(ledger.count) awards earned from your saved sets.")
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
                        BadgeRow(kind: entry.kind, earned: entry.earned)
                    }
                }
            }
            Section {
                ForEach(ledger.all.filter { $0.earned == nil }, id: \.kind) { entry in
                    BadgeRow(kind: entry.kind, earned: nil)
                }
            } header: {
                Text("Milestones")
            } footer: {
                Text("Awards reflect measurements in your saved sets. They don’t assess overall technique or fitness.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Awards")
        .onAppear { ledger.acknowledge() }
    }
}

struct BadgeRow: View {
    let kind: BadgeKind
    let earned: EarnedBadge?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BadgeMark(kind: kind, earned: earned != nil)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(.headline)
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
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(earned ? HomeStyle.accent : Color(uiColor: .secondaryLabel))
            .frame(width: size, height: size)
            .background(earned ? HomeStyle.accent.opacity(0.1) : Color(uiColor: .tertiarySystemFill), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Inline completion feedback. Awards never interrupt a workout with a modal or push alert.
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
