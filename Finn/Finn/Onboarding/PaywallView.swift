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
/// Subscribe opens the App Store in-app purchase sheet for the chosen plan (`TestConfig.storekit`
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var typeSize

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
                VStack(alignment: .leading, spacing: OnboardingMetrics.sectionSpacing) {
                    heading
                    // the touch of pink: Home's outline around Finn Coach+ and its two plans
                    FinnOutline(topRadius: Self.rowRadius, bottomRadius: Self.rowRadius) {
                        VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
                            features
                                .padding(.horizontal, OnboardingMetrics.cardPadding)
                                .padding(.vertical, OnboardingMetrics.titleSpacing)
                            planRow(.weekly)
                            planRow(.annual)
                        }
                    }
                    // outside the outline, as wide as the plans inside it
                    planRow(.trial)
                        .padding(.horizontal, DashboardStyle.cardSpacing)
                    terms
                }
                .finnFeedback(.selection, trigger: plan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.vertical, OnboardingMetrics.sectionSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, OnboardingMetrics.gutter)
            // at the very bottom of the screen, under the main action
            links
                .padding(.horizontal, OnboardingMetrics.gutter)
        }
        .disabled(isBusy)
        .finnFeedback(.success, trigger: purchases)
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
        VStack(alignment: .leading, spacing: OnboardingMetrics.titleSpacing) {
            Text("Your plan is ready.")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Finn can't wait to coach you.")
                .font(.body)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// what Finn Coach+ adds, one line each, in the plain style of Apple's own offers
    private var features: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
            Text(verbatim: "Finn Coach+")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Label("Full experience", systemImage: "applewatch")
                .accessibilityValue(Text("Apple Watch and AirPods"))
            Label("Unlimited workouts", systemImage: "infinity")
            Label("Talk to your coach", systemImage: "bubble.left.and.text.bubble.right")
        }
        .font(.body)
        .foregroundStyle(Color.primary)
    }

    /// one plan: a neutral row, every price in the same type; only the chosen one turns pink
    private func planRow(_ rowPlan: CoachPlan) -> some View {
        let selected = plan == rowPlan
        let shape = RoundedRectangle(cornerRadius: Self.rowRadius, style: .continuous)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: OnboardingMetrics.titleSpacing))
            : AnyLayout(HStackLayout(spacing: OnboardingMetrics.rowSpacing))
        return Button { choose(rowPlan) } label: {
            HStack(spacing: OnboardingMetrics.rowSpacing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? DashboardStyle.accent : HomeStyle.supportingText)
                    .accessibilityHidden(true)
                layout {
                    VStack(alignment: .leading, spacing: OnboardingMetrics.titleSpacing / 2) {
                        Text(title(rowPlan))
                            .font(.headline)
                        if let detail = detail(rowPlan) {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(HomeStyle.supportingText)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text(billedPrice(rowPlan))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            .padding(OnboardingMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(HomeStyle.card, in: shape)
            .overlay {
                if selected { shape.strokeBorder(DashboardStyle.accent, lineWidth: Self.selectionWidth) }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("plan.\(rowPlan.rawValue)")
    }

    private static let rowRadius: CGFloat = 20
    private static let selectionWidth: CGFloat = 2

    private func title(_ plan: CoachPlan) -> String {
        switch plan {
        case .weekly: String(localized: "Weekly")
        case .annual: String(localized: "Annual")
        case .trial: String(localized: "Free trial")
        }
    }

    /// the trial says what follows it; the price beside it is the one billed
    private func detail(_ plan: CoachPlan) -> String? {
        plan == .trial ? String(localized: "2 weeks free, then billed yearly") : nil
    }

    /// what the plan bills, the same size for every plan, the trial included
    private func billedPrice(_ plan: CoachPlan) -> String {
        switch plan {
        case .weekly: String(localized: "\(price(.weekly)) / week")
        case .annual: String(localized: "\(price(.annual)) / year")
        case .trial: String(localized: "\(price(.trial)) / year")
        }
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

    /// Subscribe appears once a plan is chosen, above the links
    private var actions: some View {
        VStack {
            if plan != nil {
                Button { Task { await buy() } } label: {
                    PrimaryActionLabel(title: "Subscribe")
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("plan.continue")
                .transition(.opacity)
            }
        }
    }

    /// in the top row like Not now on the questions: the full text size and colour, so it is easy to
    /// find, with no fill, so Subscribe stays the main action
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

#Preview {
    PaywallView(back: {}, next: {}, skip: {})
        .preferredColorScheme(.dark)
}
