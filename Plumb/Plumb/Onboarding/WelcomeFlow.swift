import SwiftUI

/// A local offer preference for this design preview, never a subscription entitlement.
nonisolated enum CoachPlanChoice: String, CaseIterable {
    case free, monthly, annual

    var title: String {
        switch self {
        case .free: "Free"
        case .monthly: "Plumb+ Monthly"
        case .annual: "Plumb+ Annual"
        }
    }
}

extension PlumbPreferences {
    var coachPlanChoice: CoachPlanChoice {
        get { defaults.string(forKey: "plumb.coachPlanPreview").flatMap(CoachPlanChoice.init(rawValue:)) ?? .free }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "plumb.coachPlanPreview") }
    }
}

/// Welcome → two illustrated demo moments → offer choice → Home. No permissions or sample sets.
struct OnboardingView: View {
    let preferences: PlumbPreferences
    let finished: (OnboardingProfile) -> Void
    @State private var step = 0
    @State private var plan: CoachPlanChoice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(preferences: PlumbPreferences, finished: @escaping (OnboardingProfile) -> Void) {
        self.preferences = preferences
        self.finished = finished
        _plan = State(initialValue: preferences.coachPlanChoice)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IntroBrand()
                Spacer()
                if step > 0 {
                    Button { move(to: step - 1) } label: {
                        Image(systemName: "arrow.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("onboarding.back")
                }
                if step < 3 {
                    Button { move(to: 3) } label: {
                        Text("Skip").font(.subheadline.weight(.medium))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .accessibilityLabel("Skip to coach plans")
                        .accessibilityIdentifier("onboarding.skip")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case 0: welcome
                    case 1: DemoStoryPage(showsAdvice: false)
                    case 2: DemoStoryPage(showsAdvice: true)
                    default: CoachPlanPicker(selection: $plan)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .id(step)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 16) {
                HStack(spacing: 7) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == progressStep ? DashboardStyle.lime : .white.opacity(0.22))
                            .frame(width: index == progressStep ? 26 : 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(progressStep + 1) of 3")

                IntroAction(title: actionTitle, symbol: step == 3 ? "checkmark" : "arrow.right") {
                    if step == 3 {
                        preferences.coachPlanChoice = plan
                        // Preserve Guilhem's existing personalization answers on a replay.
                        let profile = preferences.onboardingProfile
                        preferences.apply(profile)
                        finished(profile)
                    } else {
                        move(to: step + 1)
                    }
                }
                .accessibilityIdentifier("onboarding.continue")
                Text(step == 3 ? "Plan preview · no payment today" : "Your next good habit starts here.")
                    .font(.caption)
                    .foregroundStyle(DashboardStyle.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: 540)
        }
        .foregroundStyle(.white)
        .background { IntroBackground() }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private var progressStep: Int { step == 0 ? 0 : step == 3 ? 2 : 1 }
    private var actionTitle: String {
        switch step {
        case 0: "See Plumb in action"
        case 1: "See Plumb’s advice"
        case 2: "Choose my coach"
        default: "Continue with \(plan == .free ? "Free" : "Plumb+")"
        }
    }

    private func move(to next: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { step = next }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            IntroHeading(eyebrow: "A LITTLE GUIDANCE. A LOT OF PROGRESS.",
                         title: "Find your line.",
                         subtitle: "Meet the coach that pays attention to your movement. One rep, one insight, one step forward.")
                .accessibilityIdentifier("onboarding.welcome")
            DemoCameraCard(showsAdvice: false, welcome: true)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.title2).foregroundStyle(DashboardStyle.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your iPhone. Your own pace.").font(.headline)
                    Text("Set it down, step into view, and make your next set count.")
                        .font(.subheadline).foregroundStyle(DashboardStyle.secondary)
                }
            }
        }
    }
}

struct IntroBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("PlumbMark").resizable().scaledToFit().frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Plumb").font(.title3.weight(.bold))
                Text("Find your line.").font(.caption2).foregroundStyle(DashboardStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct IntroBackground: View {
    var body: some View {
        HomeBackdrop()
            .overlay(LinearGradient(colors: [.black.opacity(0.68), .black.opacity(0.78)],
                                    startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
    }
}

struct IntroHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 39.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.caption2.weight(.semibold)).tracking(1.5)
                .foregroundStyle(DashboardStyle.lime)
            Text(title).font(.system(size: titleSize, weight: .bold)).tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct IntroAction: View {
    let title: String
    var symbol = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title).font(.headline)
                Spacer(minLength: 0)
                Image(systemName: symbol).font(.headline).accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.black)
            .background(DashboardStyle.lime, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct CoachPlanPicker: View {
    @Binding var selection: CoachPlanChoice
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IntroHeading(eyebrow: "YOUR MOVEMENT. YOUR CHOICE.", title: "Choose your coach",
                         subtitle: "Your essentials, or a little more personal.")

            Button { selection = .free } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Free").font(.title2.bold())
                        Spacer()
                        Text("€0").font(.title2.bold())
                        selectionMark(selection == .free)
                    }
                    feature("Advice after every set", symbol: "text.bubble")
                    feature("Track your workouts", symbol: "chart.xyaxis.line")
                }
                .padding(16)
                .planSurface(selected: selection == .free)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("paywall.free")
            .accessibilityAddTraits(selection == .free ? .isSelected : [])

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plumb+").font(.title2.bold())
                        Text("Everything in Free, plus")
                            .font(.caption).foregroundStyle(DashboardStyle.secondary)
                    }
                    Spacer()
                    Text("A LITTLE MORE PERSONAL")
                        .font(.system(size: 9, weight: .bold)).tracking(0.7)
                        .foregroundStyle(DashboardStyle.lime)
                }
                feature("A coach you can talk to", symbol: "waveform")
                feature("Apple Watch on your wrist", symbol: "applewatch")
                feature("Advice in your AirPods", symbol: "airpods.pro")

                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                layout {
                    priceOption(.monthly, title: "Monthly", price: "€9.99", period: "/ month", detail: "Billed monthly")
                    priceOption(.annual, title: "Annual", price: "€99", period: "/ year", detail: "€8.25 / month · save 17%")
                }
            }
            .padding(16)
            .planSurface(selected: selection != .free)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.plus")
        }
        .foregroundStyle(.white)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func feature(_ title: String, symbol: String) -> some View {
        Label {
            Text(title).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(DashboardStyle.lime)
        }
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3).foregroundStyle(selected ? DashboardStyle.lime : .white.opacity(0.4))
            .accessibilityHidden(true)
    }

    private func priceOption(_ plan: CoachPlanChoice, title: String, price: String,
                             period: String, detail: String) -> some View {
        Button { selection = plan } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 2)
                    selectionMark(selection == plan)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price).font(.title2.bold()).monospacedDigit()
                    Text(period).font(.caption).foregroundStyle(DashboardStyle.secondary)
                }
                Text(detail).font(.caption2.weight(.medium))
                    .foregroundStyle(plan == .annual ? DashboardStyle.lime : DashboardStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 28, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selection == plan ? DashboardStyle.lime.opacity(0.10) : .black.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(selection == plan ? DashboardStyle.lime : .white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("paywall.\(plan.rawValue)")
        .accessibilityAddTraits(selection == plan ? .isSelected : [])
    }
}

private extension View {
    func planSurface(selected: Bool) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26)
                .strokeBorder(selected ? DashboardStyle.lime : .white.opacity(0.18), lineWidth: 1))
    }
}
