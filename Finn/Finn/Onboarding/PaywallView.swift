import StoreKit
import SwiftUI

/// the three offers of the plan screen and their products in `TestConfig.storekit`. The trial is
/// its own annual product, so choosing Annual never starts a trial by itself
nonisolated enum CoachPlan: String, CaseIterable, Sendable {
    case weekly, annual, trial

    var productID: String {
        switch self {
        case .weekly: "ai.mwm.build.challenge.team.08.weekly.00.ft.05.99"
        case .annual: "ai.mwm.build.challenge.team.08.yearly.00.ft.149.99"
        case .trial: "ai.mwm.build.challenge.team.08.yearly.14.ft.149.99"
        }
    }

    /// the design's prices, shown until the App Store answers (previews, launches without StoreKit)
    var fallbackPrice: String { self == .weekly ? "€5.99" : "€149.99" }
}

/// the plan offer: Finn Coach+, weekly or annual, or annual after a two-week free trial.
/// Pay with Apple Pay opens the App Store in-app purchase sheet for the chosen plan (`TestConfig.storekit`
/// in the simulator); Skip, at the top right, keeps Finn Free and goes straight to Home
struct PaywallView: View {
    let back: () -> Void
    /// called after a purchase or a restored subscription
    let next: () -> Void
    /// called by Skip
    let skip: () -> Void

    @State private var plan: CoachPlan?
    @State private var products: [String: Product] = [:]
    @State private var isBusy = false
    @State private var notice: Notice?
    /// counts the purchases, for the success haptic
    @State private var purchases = 0
    @Environment(\.purchase) private var purchase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var planLabelWidth = 80.0

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://james8464.github.io/finn/privacy.html")!

    private enum Notice {
        case unavailable, nothingToRestore

        var title: String {
            switch self {
            case .unavailable: String(localized: "Purchase unavailable")
            case .nothingToRestore: String(localized: "Nothing to restore")
            }
        }

        var message: String {
            switch self {
            case .unavailable: String(localized: "The App Store can't be reached right now. Try again later.")
            case .nothingToRestore: String(localized: "No Finn Coach+ subscription was found for this Apple Account.")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton(action: back)
                Spacer()
                skipButton
            }
            .padding(.horizontal, OnboardingMetrics.gutter)
            .padding(.top, OnboardingMetrics.headerTop)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heading
                    coachPlusCard
                    trialCard
                    if plan != .trial {
                        terms
                    }
                    links
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .disabled(isBusy)
        .sensoryFeedback(.success, trigger: purchases)
        .task { await loadProducts() }
        .alert(notice?.title ?? "", isPresented: Binding(get: { notice != nil },
                                                         set: { if !$0 { notice = nil } }),
               presenting: notice) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
    }

    // MARK: Content

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan is ready.")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .trailing, spacing: 6) {
                Text(verbatim: 1.0.formatted(.percent))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                ProgressView(value: 1)
                    .tint(DashboardStyle.accent)
                    .accessibilityHidden(true)
            }
            Text("Finn can't wait to coach you.")
                .font(.body)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
    }

    private var coachPlusCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Finn Coach+")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("Full experience")
                        .accessibilityValue(Text("Apple Watch and AirPods"))
                    Group {
                        Image(systemName: "applewatch")
                        Image(systemName: "airpodspro")
                    }
                    .accessibilityHidden(true)
                }
                Text("Unlimited workouts")
                Text("Talk to your coach")
            }
            .font(.subheadline)
            .foregroundStyle(Color.primary.opacity(0.85))
            .padding(.horizontal, 4)
            .padding(.top, 10)
            VStack(spacing: 10) {
                planRow(.weekly, title: String(localized: "Weekly"),
                        price: String(localized: "\(price(.weekly)) / week"))
                planRow(.annual, title: String(localized: "Annual"),
                        price: String(localized: "\(price(.annual)) / year"))
            }
            .padding(.top, 7)
        }
        .padding(EdgeInsets(top: 20, leading: 16, bottom: 12, trailing: 16))
        .offerCard()
    }

    private var trialCard: some View {
        let selected = plan == .trial
        return VStack(alignment: .leading, spacing: 12) {
            Button { choose(.trial) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Free trial · 2 weeks")
                            .font(.headline)
                        Text("Then \(price(.trial)) / year")
                            .font(.footnote)
                            .foregroundStyle(selected ? Color.black : HomeStyle.supportingText)
                    }
                    Spacer(minLength: 0)
                    checkBox(selected)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                .planSurface(selected)
            }
            .buttonStyle(PressableStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("plan.trial")
            if selected {
                terms
                    .transition(.opacity)
            }
        }
        .padding(16)
        .offerCard()
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func planRow(_ rowPlan: CoachPlan, title: String, price: String) -> some View {
        let selected = plan == rowPlan
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return Button { choose(rowPlan) } label: {
            HStack(spacing: 12) {
                layout {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: typeSize.isAccessibilitySize ? nil : planLabelWidth, alignment: .leading)
                    Text(price)
                        .font(.headline)
                }
                Spacer(minLength: 0)
                checkBox(selected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .planSurface(selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("plan.\(rowPlan.rawValue)")
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func checkBox(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.square.fill" : "square")
            .font(.system(size: 20))
            .foregroundStyle(selected ? Color.black : HomeStyle.supportingText)
            .accessibilityHidden(true)
    }

    /// what the chosen plan costs and how it renews
    private var terms: some View {
        Text(termsText)
            .font(.footnote)
            .foregroundStyle(HomeStyle.supportingText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var termsText: String {
        switch plan {
        case nil:
            String(localized: "Renews automatically. Cancel in Settings at least 24 hours before renewal. Trial for eligible subscribers.")
        case .weekly?:
            String(localized: "\(price(.weekly)) charged today, then weekly. Renews automatically. Cancel in Settings at least 24 hours before renewal.")
        case .annual?:
            String(localized: "\(price(.annual)) charged today, then yearly. Renews automatically. Cancel in Settings at least 24 hours before renewal.")
        case .trial?:
            String(localized: "\(freeToday) today. After 2 weeks, \(price(.trial))/year. Renews automatically. Cancel in Settings at least 24 hours before renewal. Eligible subscribers only.")
        }
    }

    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { linkItems(separated: true) }
            VStack(spacing: 0) { linkItems(separated: false) }
        }
        .font(.footnote)
        .foregroundStyle(HomeStyle.supportingText)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func linkItems(separated: Bool) -> some View {
        Button { Task { await restore() } } label: { target("Restore purchases") }
            .accessibilityIdentifier("plan.restore")
        if separated { Text(verbatim: "·").accessibilityHidden(true) }
        Link(destination: Self.termsURL) { target("Terms") }
        if separated { Text(verbatim: "·").accessibilityHidden(true) }
        Link(destination: Self.privacyURL) { target("Privacy") }
    }

    /// a small text link with the full 44 pt target around it
    private func target(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Pay with Apple Pay appears once a plan is chosen
    private var actions: some View {
        VStack {
            if plan != nil {
                Button { Task { await buy() } } label: {
                    PrimaryActionLabel(title: "Pay with Apple Pay")
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("plan.continue")
                .transition(.opacity)
            }
        }
    }

    /// in the top row like Not now on the questions: the full text size and colour, so it is easy to
    /// find, with no fill, so Pay with Apple Pay stays the main action
    private var skipButton: some View {
        Button(action: skip) {
            Text("Skip")
                .font(.body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Color.primary)
        .accessibilityLabel("Skip")
        .accessibilityHint("Continue with Finn Free")
        .accessibilityIdentifier("plan.skip")
    }

    // MARK: StoreKit

    private func choose(_ chosen: CoachPlan) {
        withAnimation(reduceMotion ? nil : HomeStyle.spring) { plan = chosen }
    }

    private func price(_ plan: CoachPlan) -> String {
        products[plan.productID]?.displayPrice ?? plan.fallbackPrice
    }

    /// nothing due today, in the trial's currency
    private var freeToday: String {
        guard let product = products[CoachPlan.trial.productID] else { return "€0" }
        return Decimal.zero.formatted(product.priceFormatStyle.precision(.fractionLength(0)))
    }

    private func loadProducts() async {
        guard let loaded = try? await Product.products(for: CoachPlan.allCases.map(\.productID)) else { return }
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    /// the App Store in-app purchase sheet for the chosen plan. A verified purchase moves on
    private func buy() async {
        guard let plan else { return }
        #if DEBUG
        // UI tests run without the App Store: `-finn-ui-demo-purchase` stands for a verified purchase
        if ProcessInfo.processInfo.arguments.contains("-finn-ui-demo-purchase") {
            purchases += 1
            next()
            return
        }
        #endif
        isBusy = true
        defer { isBusy = false }
        if products[plan.productID] == nil { await loadProducts() }
        guard let product = products[plan.productID] else {
            notice = .unavailable
            return
        }
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                purchases += 1
                next()
            case .success(.unverified):
                notice = .unavailable
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            notice = .unavailable
        }
    }

    /// asks the App Store for this account's purchases; an active Finn Coach+ plan moves on
    private func restore() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch {
            notice = .unavailable
            return
        }
        let productIDs = Set(CoachPlan.allCases.map(\.productID))
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, productIDs.contains(transaction.productID) {
                next()
                return
            }
        }
        notice = .nothingToRestore
    }
}

private extension View {
    /// the black card with a thin pink outline around each offer
    func offerCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeStyle.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DashboardStyle.accent, lineWidth: 0.5))
    }

    /// a plan inside an offer: grey, or pink with black type once chosen
    func planSurface(_ selected: Bool) -> some View {
        foregroundStyle(selected ? Color.black : Color.primary)
            .background(selected ? DashboardStyle.accent : HomeStyle.card,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview("Dark") {
    PaywallView(back: {}, next: {}, skip: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    PaywallView(back: {}, next: {}, skip: {})
        .preferredColorScheme(.light)
}
