import SwiftUI

/// after the last question, one screen in two states. First the chosen coach customises the plan
/// while a bar fills; at 100 % the coach stays and, in place, says what they understood, above a
/// recap of every answer. Continue opens the plan offer
struct PlanSummaryView: View {
    let profile: OnboardingProfile
    /// true once the bar has filled; the parent keeps it, so coming back from the offer skips the wait
    @Binding var isReady: Bool
    let back: () -> Void
    let next: () -> Void

    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// how long the bar takes to fill
    private static let fillDuration = 2.4
    /// the bar's updates: small, animated steps, or a few plain jumps with Reduce Motion
    private static let smoothSteps = 48
    private static let reducedSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton(action: back)
                Spacer()
            }
            .padding(.horizontal, OnboardingMetrics.gutter)
            .padding(.top, OnboardingMetrics.headerTop)
            ScrollView {
                VStack(spacing: OnboardingMetrics.sectionSpacing) {
                    // the coach stays put; only what is under them changes
                    CoachAvatar(coach: profile.coach, size: OnboardingMetrics.coachPortrait)
                    if isReady {
                        summary
                            .transition(stateTransition)
                    } else {
                        loading
                            .transition(stateTransition)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.top, OnboardingMetrics.pageTop)
                .padding(.bottom, OnboardingMetrics.sectionSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            if isReady {
                Button(action: next) {
                    PrimaryActionLabel(title: "Continue")
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("summary.continue")
                .padding(.horizontal, OnboardingMetrics.gutter)
                .padding(.bottom, OnboardingMetrics.bottomInset)
                .transition(.opacity)
            }
        }
        .task { await customise() }
    }

    private var stateTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    // MARK: Loading

    private var loading: some View {
        VStack(spacing: OnboardingMetrics.sectionSpacing) {
            Text("Customising your training plan")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .trailing, spacing: OnboardingMetrics.titleSpacing) {
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityHidden(true)
                ProgressView(value: progress)
                    .tint(DashboardStyle.accent)
                    .accessibilityLabel("Customising your training plan")
            }
        }
        .accessibilityIdentifier("summary.loading")
    }

    /// fills the bar, then turns the screen into the summary. Does nothing once ready
    private func customise() async {
        guard !isReady else { return }
        let steps = reduceMotion ? Self.reducedSteps : Self.smoothSteps
        let pause = Self.fillDuration / Double(steps)
        progress = 0
        for step in 1...steps {
            do { try await Task.sleep(for: .seconds(pause)) } catch { return }
            withAnimation(reduceMotion ? nil : .linear(duration: pause)) {
                progress = Double(step) / Double(steps)
            }
        }
        // a beat at 100 %, then the summary
        do { try await Task.sleep(for: .seconds(pause)) } catch { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : HomeStyle.spring) { isReady = true }
        AccessibilityNotification.Announcement(spokenSummary).post()
    }

    // MARK: Summary

    private var sentence: String { profile.coachSummary() }

    private var spokenSummary: String { String(localized: "\(profile.coach.name): \(sentence)") }

    private var summary: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.sectionSpacing) {
            Text(sentence)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spokenSummary)
                .accessibilityIdentifier("summary.sentence")
            VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
                Text("Your answers")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
                    ForEach(Array(recap.enumerated()), id: \.element.question) { index, row in
                        VStack(alignment: .leading, spacing: OnboardingMetrics.rowSpacing) {
                            if index > 0 { Divider() }
                            RecapRow(question: row.question, answer: row.answer)
                        }
                    }
                }
                .optionCard()
            }
        }
    }

    /// every question, as it was asked, with its answer
    private var recap: [(question: String, answer: String)] {
        let skipped = String(localized: "Skipped")
        var rows: [(question: String, answer: String)] = [
            (String(localized: "Training goal"), profile.goal?.title ?? skipped),
            (String(localized: "Training experience"), profile.level?.title ?? skipped),
            (String(localized: "Have you ever followed a training program?"),
             profile.followedProgram.map { $0 ? String(localized: "Yes") : String(localized: "No") } ?? skipped),
        ]
        if profile.followedProgram == true {
            rows.append((String(localized: "Why did you stop?"),
                         profile.stopReasons.isEmpty ? skipped
                            : profile.stopReasons.map(\.title).formatted(.list(type: .and))))
        }
        rows += [
            (String(localized: "How hard do you want me to push you?"), profile.intensity?.title ?? skipped),
            (String(localized: "How many days a week are you ready to train?"), profile.days?.title ?? skipped),
            (String(localized: "Choose your coach"), profile.coach.name),
        ]
        return rows
    }
}

/// one question and its answer in the recap
private struct RecapRow: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingMetrics.titleSpacing / 2) {
            Text(question)
                .font(.subheadline)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
            Text(answer)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private extension OnboardingProfile {
    static let preview = OnboardingProfile(goal: .muscle, level: .regular, firstName: "Alex",
                                           followedProgram: true, stopReasons: [.motivation, .injury],
                                           intensity: .challenge, days: .threeToFour)
}

#Preview("Loading, then summary") {
    @Previewable @State var ready = false
    PlanSummaryView(profile: .preview, isReady: $ready, back: {}, next: {})
        .background(HomeStyle.background)
        .preferredColorScheme(.dark)
}

#Preview("Summary, light, skipped answers") {
    @Previewable @State var ready = true
    PlanSummaryView(profile: OnboardingProfile(), isReady: $ready, back: {}, next: {})
        .background(HomeStyle.background)
        .preferredColorScheme(.light)
}

#Preview("Summary, accessibility text") {
    @Previewable @State var ready = true
    PlanSummaryView(profile: .preview, isReady: $ready, back: {}, next: {})
        .background(HomeStyle.background)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
