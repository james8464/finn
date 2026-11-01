import StoreKit
import SwiftUI

/// The three offers configured in App Store Connect (and `TestConfig.storekit`): weekly, annual, and
/// annual with a two-week free trial, which StoreKit grants only to eligible accounts.
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

/// The plan offer, as in the design (04-Subscription): Finn Coach+ weekly or annual in one pink
/// outline, the two-week free trial and its terms in a second one.
/// Choosing a plan brings Subscribe in, which opens the App Store purchase sheet for it
/// (`TestConfig.storekit` in the simulator). At the end of the onboarding, the cross beside the
/// subtitle keeps Finn Free and goes straight to Home, where Finn offers a free workout. When the
/// free workout of these two weeks is used, the same offer says when the next one opens
struct PaywallView: View {
    /// where the offer appears
    enum Context: Equatable {
        /// the last step of the onboarding, after the plan summary
        case onboarding
        /// a new workout was refused; `next` is when the next free one opens
        case freeWorkoutUsed(next: Date?)
    }

    let back: () -> Void
    /// after a purchase or a restore; in the onboarding, also after choosing Finn Free
    let next: () -> Void
    /// called by the cross
    let skip: () -> Void
    var context: Context = .onboarding

    @State private var plan: CoachPlan?
    @State private var products: [String: Product] = [:]
    @State private var hasLoadedProducts = false
    @State private var isBusy = false
    @State private var notice: Notice?
    @State private var eligibleForFreeTrial = false
    /// the trial is on sale, but this Apple Account has already had it
    @State private var trialAlreadyUsed = false
    /// counts the purchases, for the success haptic
    @State private var purchases = 0
    @Environment(\.purchase) private var purchase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var typeSize
    /// "Finn Coach+" is set at 24 pt, between Title 2 and Title 1, and grows with the text size
    @ScaledMetric(relativeTo: .title2) private var offerTitleSize = 24.0

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://james8464.github.io/finn/privacy.html")!

    private enum Notice {
        case unavailable, nothingToRestore, trialUsed

        var title: String {
            switch self {
            case .unavailable: String(localized: "Purchase unavailable")
            case .nothingToRestore: String(localized: "Nothing to restore")
            case .trialUsed: String(localized: "Free trial already used")
            }
        }

        var message: String {
            switch self {
            case .unavailable: String(localized: "The App Store can't be reached right now. Try again later.")
            case .nothingToRestore: String(localized: "No Finn Coach+ subscription was found for this Apple Account.")
            case .trialUsed:
                String(localized: "This Apple Account has already used the free trial. Choose Weekly or Annual to subscribe.")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if context == .onboarding {
                HStack {
                    OnboardingBackButton(action: back)
                    Spacer()
                }
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.top, OnboardingMetrics.headerTop)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Self.blockSpacing) {
                    heading
                    PlanOutline {
                        VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
                            features
                                .padding([.horizontal, .top], Self.textInset)
                            planRow(.weekly)
                            planRow(.annual)
                        }
                    }
                    if hasLoadedProducts && !hasPurchasableOffers && !usesDemoPurchase {
                        freePlan
                    } else {
                        PlanOutline { trialAndTerms }
                    }
                    links
                }
                .finnFeedback(.selection, trigger: plan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.top, context == .onboarding ? 0 : OnboardingMetrics.pageTop)
                .padding(.bottom, OnboardingMetrics.bottomInset)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.bottom, OnboardingMetrics.bottomInset)
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

    /// the title, then, in the onboarding, the summary's bar, full now that the plan is built
    private var heading: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.titleSpacing) {
            Text(title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if context == .onboarding {
                VStack(alignment: .trailing, spacing: OnboardingMetrics.titleSpacing) {
                    Text(1.0.formatted(.percent.precision(.fractionLength(0))))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    ProgressView(value: 1)
                        .tint(DashboardStyle.accent)
                }
                // the title already says it: the bar only echoes the summary
                .accessibilityHidden(true)
            }
            Text(subtitle)
                .font(.body)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // room for the cross, which sits over the end of the line without making it taller
                .padding(.trailing, Self.closeTarget)
                .overlay(alignment: .trailing) { closeButton }
                .padding(.top, OnboardingMetrics.titleSpacing)
        }
    }

    private var title: String {
        switch context {
        case .onboarding: String(localized: "Your plan is ready.")
        case .freeWorkoutUsed: String(localized: "You've used your free workout.")
        }
    }

    /// beside the cross. Once the free workout is used, it says when the next one opens
    private var subtitle: String {
        switch context {
        case .onboarding:
            return String(localized: "Finn can't wait to coach you.")
        case .freeWorkoutUsed(let next?):
            let day = next.formatted(.dateTime.weekday(.wide).day().month(.wide))
            return String(localized: "Your next free workout: \(day).")
        case .freeWorkoutUsed(nil):
            return String(localized: "Your next free workout is in two weeks.")
        }
    }

    /// what Finn Coach+ adds: the watch before the first line, the next two in line with it
    private var features: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
            Text(verbatim: "Finn Coach+")
                .font(.system(size: offerTitleSize, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                Label("Full experience", systemImage: "applewatch")
                    .accessibilityValue(Text("Apple Watch and AirPods"))
                Text("Unlimited workouts")
                Text("Talk to your coach")
            }
            .font(.subheadline)
            .foregroundStyle(Color.primary.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// the trial on its own, with its terms under it
    private var trialAndTerms: some View {
        VStack(alignment: .leading, spacing: Self.termsSpacing) {
            planRow(.trial)
            if !hasLoadedProducts && !usesDemoPurchase {
                ProgressView("Checking available plans")
                    .frame(maxWidth: .infinity)
            } else {
                Text(termsText)
                    .font(.footnote)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var freePlan: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.titleSpacing) {
            Text("Finn Free")
                .font(.title2.bold())
            Text("Subscriptions are not available yet. Continue with Finn Free to start your workout plan and use the coach.")
                .font(.body)
                .foregroundStyle(HomeStyle.supportingText)
            Button("Try again") { Task { await loadProducts() } }
                .font(.body.weight(.medium))
                .accessibilityIdentifier("plan.retry")
        }
        .padding(OnboardingMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: Self.rowRadius, style: .continuous))
    }

    /// one plan: a neutral row; the chosen one gets the pink circle and outline. Weekly and Annual
    /// show their price at the right, the trial under its name
    private func planRow(_ rowPlan: CoachPlan) -> some View {
        let selected = plan == rowPlan
        let unavailable = hasLoadedProducts && !offerIsAvailable(rowPlan)
        let shape = RoundedRectangle(cornerRadius: Self.rowRadius, style: .continuous)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: OnboardingMetrics.titleSpacing))
            : AnyLayout(HStackLayout(spacing: OnboardingMetrics.rowSpacing))
        return Button { choose(rowPlan) } label: {
            HStack(spacing: OnboardingMetrics.cardPadding) {
                indicator(selected: selected)
                layout {
                    VStack(alignment: .leading, spacing: Self.detailSpacing) {
                        Text(title(rowPlan))
                            .font(rowPlan == .trial ? .headline : .subheadline.weight(.semibold))
                        if let detail = detail(rowPlan) {
                            Text(detail)
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(selected ? Color.primary : HomeStyle.supportingText)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if let price = priceLabel(for: rowPlan) {
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                        Text(price)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, OnboardingMetrics.cardPadding)
            .padding(.vertical, Self.rowVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(HomeStyle.card, in: shape)
            .overlay {
                if selected { shape.strokeBorder(DashboardStyle.accent, lineWidth: Self.selectionWidth) }
            }
            .contentShape(shape)
            .opacity(unavailable ? 0.5 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(unavailable)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("plan.\(rowPlan.rawValue)")
    }

    /// the circle of the onboarding answers: an empty grey ring, or pink with a black tick
    private func indicator(selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .symbolRenderingMode(.palette)
            .foregroundStyle(selected ? Color.black : Self.ring, DashboardStyle.accent)
            .accessibilityHidden(true)
    }

    private static let rowRadius: CGFloat = 22
    private static let rowHeight: CGFloat = 60
    private static let rowVerticalPadding: CGFloat = 10
    private static let selectionWidth: CGFloat = 2
    /// the empty ring of an unchosen plan
    private static let ring = Color(red: 0xB7 / 255, green: 0xB7 / 255, blue: 0xB7 / 255)
    /// between the heading, the two outlines and the links
    private static let blockSpacing: CGFloat = 16
    /// the title and benefits sit a little further in than the plans
    private static let textInset: CGFloat = 4
    private static let detailSpacing: CGFloat = 4
    private static let termsSpacing: CGFloat = 12

    private func title(_ plan: CoachPlan) -> String {
        switch plan {
        case .weekly: String(localized: "Weekly")
        case .annual: String(localized: "Annual")
        case .trial: "\(String(localized: "Free trial")) · \(String(localized: "2 weeks"))"
        }
    }

    /// the trial's second line: what it costs after the two weeks, or why it can't be chosen
    private func detail(_ plan: CoachPlan) -> String? {
        guard plan == .trial else { return nil }
        if trialAlreadyUsed && !usesDemoPurchase { return String(localized: "Free trial already used") }
        if hasLoadedProducts && !offerIsAvailable(.trial) { return String(localized: "Not available yet") }
        return String(localized: "Then \(shownPrice(.trial)) / year")
    }

    /// what Weekly and Annual bill, in the same type for both
    private func priceLabel(for offer: CoachPlan) -> String? {
        switch offer {
        case .trial: return nil
        case _ where !hasLoadedProducts && !usesDemoPurchase: return "…"
        case _ where !offerIsAvailable(offer): return String(localized: "Not available yet")
        case .weekly: return String(localized: "\(price(.weekly)) / week")
        case .annual: return String(localized: "\(price(.annual)) / year")
        }
    }

    /// the trial's terms, the same whichever plan is chosen: nothing today, then the yearly price
    private var termsText: String {
        String(localized: "\(freeToday) today. After 2 weeks, \(price(.trial))/year. Renews automatically. Cancel in Settings at least 24 hours before renewal. Eligible subscribers only.")
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
        if hasPurchasableOffers || usesDemoPurchase {
            Button { Task { await restore() } } label: { target("Restore purchases") }
                .accessibilityIdentifier("plan.restore")
            if separated { Text(verbatim: "·").accessibilityHidden(true) }
        }
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

    /// Subscribe keeps its place and fades in once a plan is chosen, so nothing moves
    @ViewBuilder private var actions: some View {
        if hasLoadedProducts && !hasPurchasableOffers && !usesDemoPurchase {
            // in the onboarding Finn Free goes on to the last questions; later it only closes the offer
            Button(action: context == .onboarding ? next : skip) {
                PrimaryActionLabel(title: "Continue with Finn Free")
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("plan.continueFree")
        } else {
            subscribeButton
        }
    }

    /// light on dark, as in the design. It opens the App Store's own purchase sheet: a
    /// subscription to digital content is an in-app purchase, so the button carries no Apple Pay mark
    private var subscribeButton: some View {
        let chosen = plan != nil
        let shape = RoundedRectangle(cornerRadius: Self.subscribeRadius, style: .continuous)
        return Button { Task { await buy() } } label: {
            Text("Subscribe")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .padding(.horizontal, OnboardingMetrics.cardPadding)
                .frame(maxWidth: .infinity, minHeight: Self.subscribeHeight)
                .background(Color.primary, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .opacity(chosen ? 1 : 0)
        .disabled(!chosen)
        .accessibilityHidden(!chosen)
        .accessibilityIdentifier("plan.continue")
    }

    private static let subscribeRadius: CGFloat = 14
    private static let subscribeHeight: CGFloat = 56

    /// leaves the offer for Finn Free, in plain sight at the top rather than small at the bottom.
    /// Quieter than the subtitle beside it, small and in the system's secondary grey, yet well above
    /// the 3:1 contrast a control needs, with the full 44 pt target. The target reaches into the
    /// margin, so the cross itself lines up with the outlines
    private var closeButton: some View {
        // the close role: VoiceOver says Close in the person's language
        Button(role: .close, action: skip) {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.medium))
                .frame(width: Self.closeTarget, height: Self.closeTarget)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .padding(.trailing, -Self.closeOverhang)
        .accessibilityHint(context == .onboarding ? Text("Continue with Finn Free") : Text(verbatim: ""))
        .accessibilityIdentifier("plan.skip")
    }

    private static let closeTarget: CGFloat = 44
    /// how far the target runs past the cross into the margin: half the target less half the cross
    private static let closeOverhang: CGFloat = 16

    // MARK: StoreKit

    private func choose(_ chosen: CoachPlan) {
        guard offerIsAvailable(chosen) else { return }
        withAnimation(reduceMotion ? nil : HomeStyle.spring) { plan = chosen }
    }

    private func price(_ plan: CoachPlan) -> String {
        if let product = products[plan.productID] { return product.displayPrice }
        return usesDemoPurchase ? plan.fallbackPrice : String(localized: "Price unavailable")
    }

    /// the price as a row shows it: an ellipsis while the App Store answers
    private func shownPrice(_ plan: CoachPlan) -> String {
        !hasLoadedProducts && !usesDemoPurchase ? "…" : price(plan)
    }

    private var hasPurchasableOffers: Bool {
        CoachPlan.allCases.contains { products[$0.productID] != nil }
    }

    /// on sale, and for the trial, not used yet by this Apple Account
    private func offerIsAvailable(_ offer: CoachPlan) -> Bool {
        if usesDemoPurchase { return true }
        guard products[offer.productID] != nil else { return false }
        return offer != .trial || eligibleForFreeTrial
    }

    private var usesDemoPurchase: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-finn-ui-demo-purchase")
        #else
        false
        #endif
    }

    /// nothing due today, in the trial's currency
    private var freeToday: String {
        guard let product = products[CoachPlan.trial.productID] else { return "€0" }
        return Decimal.zero.formatted(product.priceFormatStyle.precision(.fractionLength(0)))
    }

    /// the free trial the texts describe: one period of two weeks, free
    private static func isTwoWeekFreeTrial(_ offer: Product.SubscriptionOffer) -> Bool {
        let period = offer.period
        let twoWeeks = (period.unit == .week && period.value == 2) || (period.unit == .day && period.value == 14)
        return offer.paymentMode == .freeTrial && offer.periodCount == 1 && twoWeeks
    }

    private func loadProducts() async {
        defer { hasLoadedProducts = true }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-finn-ui-no-storekit-products") { return }
        #endif
        guard let loaded = try? await Product.products(for: CoachPlan.allCases.map(\.productID)) else { return }
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        if let subscription = products[CoachPlan.trial.productID]?.subscription,
           let offer = subscription.introductoryOffer, Self.isTwoWeekFreeTrial(offer) {
            eligibleForFreeTrial = await subscription.isEligibleForIntroOffer
            trialAlreadyUsed = !eligibleForFreeTrial
        } else {
            eligibleForFreeTrial = false
            trialAlreadyUsed = false
        }
    }

    /// the App Store in-app purchase sheet for the chosen plan. A verified purchase moves on
    private func buy() async {
        guard !isBusy, let plan else { return }
        isBusy = true
        defer { isBusy = false }
        #if DEBUG
        // UI tests run without the App Store: `-finn-ui-demo-purchase` stands for a verified purchase
        if ProcessInfo.processInfo.arguments.contains("-finn-ui-demo-purchase") {
            purchases += 1
            next()
            return
        }
        #endif
        if products[plan.productID] == nil { await loadProducts() }
        guard let product = products[plan.productID] else {
            notice = .unavailable
            return
        }
        if plan == .trial, let subscription = product.subscription,
           !(await subscription.isEligibleForIntroOffer) {
            // the trial was offered from an earlier answer: take it away, and say why nothing happened
            eligibleForFreeTrial = false
            trialAlreadyUsed = true
            withAnimation(reduceMotion ? nil : HomeStyle.spring) { self.plan = nil }
            notice = .trialUsed
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
        guard !isBusy else { return }
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

/// a pink hairline around a group of plans, as in the design: 28 pt corners, the plans 16 pt in
private struct PlanOutline<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(OnboardingMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(DashboardStyle.accent, lineWidth: 0.5)
                    .accessibilityHidden(true)
            }
    }
}

#Preview("Dark") {
    PaywallView(back: {}, next: {}, skip: {})
        .background(HomeStyle.background)
        .preferredColorScheme(.dark)
}

#Preview("Free workout used") {
    PaywallView(back: {}, next: {}, skip: {},
                context: .freeWorkoutUsed(next: Calendar.current.date(byAdding: .day, value: 9, to: .now)))
        .background(HomeStyle.background)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    PaywallView(back: {}, next: {}, skip: {})
        .background(HomeStyle.background)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
