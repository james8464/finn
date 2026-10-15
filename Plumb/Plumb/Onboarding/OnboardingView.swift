import SwiftUI

/// The five first-launch screens. Each one can be skipped; the answers go to `PlumbPreferences`
/// when the person taps Start, and the camera is asked for later, when a set starts.
struct OnboardingView: View {
    let preferences: PlumbPreferences
    /// Called once the answers are saved (or the whole thing was skipped).
    let finished: (OnboardingProfile) -> Void

    @State private var step = 0
    @State private var profile: OnboardingProfile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stepCount = 5

    init(preferences: PlumbPreferences, finished: @escaping (OnboardingProfile) -> Void) {
        self.preferences = preferences
        self.finished = finished
        _profile = State(initialValue: preferences.onboardingProfile)
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, 20)
                .padding(.top, 18)
            TabView(selection: $step) {
                goalPage.tag(0)
                exercisesPage.tag(1)
                levelPage.tag(2)
                voicePage.tag(3)
                placementPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : HomeStyle.spring, value: step)
            actions
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .tint(.primary)
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.primary : HomeStyle.card)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(Self.stepCount)")
    }

    private var isLast: Bool { step == Self.stepCount - 1 }

    private var actions: some View {
        VStack(spacing: 2) {
            Button(action: advance) {
                PrimaryActionLabel(title: isLast ? "Start" : "Continue",
                                   symbol: isLast ? "checkmark" : "arrow.right")
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("onboarding.continue")
            Button(isLast ? "Skip this" : "Skip") {
                if isLast { finish() } else { withAnimation(HomeStyle.spring) { step += 1 } }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(HomeStyle.supportingText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("onboarding.skip")
        }
    }

    private func advance() {
        if isLast { finish() } else { withAnimation(HomeStyle.spring) { step += 1 } }
    }

    private func finish() {
        preferences.apply(profile)
        finished(profile)
    }

    // MARK: Pages

    private func page<Content: View>(_ title: String, _ subtitle: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(HomeStyle.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var goalPage: some View {
        page(String(localized: "What brings you here?"),
             String(localized: "Plumb adapts what it says after each set. Pick one.")) {
            VStack(spacing: 10) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    ChoiceCard(title: goal.title, detail: goal.detail, symbol: goal.symbol,
                               selected: profile.goal == goal) {
                        profile.goal = profile.goal == goal ? nil : goal
                    }
                    .accessibilityIdentifier("onboarding.goal.\(goal.rawValue)")
                }
            }
        }
    }

    private var exercisesPage: some View {
        page(String(localized: "Which exercises?"),
             String(localized: "They come first on your screen. The first one is ready when you open Plumb.")) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ExerciseKind.allCases, id: \.self) { kind in
                    ExerciseTile(kind: kind,
                                 rank: profile.favoriteExercises.firstIndex(of: kind).map { $0 + 1 }) {
                        if let index = profile.favoriteExercises.firstIndex(of: kind) {
                            profile.favoriteExercises.remove(at: index)
                        } else {
                            profile.favoriteExercises.append(kind)
                        }
                    }
                    .accessibilityIdentifier("onboarding.exercise.\(kind.rawValue)")
                }
            }
            .sensoryFeedback(.selection, trigger: profile.favoriteExercises)
        }
    }

    private var levelPage: some View {
        page(String(localized: "How often do you train?"),
             String(localized: "This changes how Plumb talks to you, not what it measures.")) {
            VStack(spacing: 10) {
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    ChoiceCard(title: level.title, detail: level.detail, symbol: nil,
                               selected: profile.level == level) {
                        profile.level = profile.level == level ? nil : level
                    }
                    .accessibilityIdentifier("onboarding.level.\(level.rawValue)")
                }
            }
        }
    }

    private var voicePage: some View {
        page(String(localized: "A voice during the set?"),
             String(localized: "Your phone stands a few steps away. Plumb can count out loud so you never look at the screen.")) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $profile.speaksLive) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Say reps aloud").font(.headline)
                        Text("The countdown, each rep, and one alert when a rep is clearly faster or shorter.")
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color(uiColor: .systemGreen))
                .accessibilityIdentifier("onboarding.speaksLive")
                .optionCard()
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "airpods.pro")
                        .font(.title2)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AirPods or any headphones").font(.headline)
                        Text("When they are connected, Plumb speaks there. Otherwise it uses the iPhone speaker. You can change this in Options.")
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .optionCard()
            }
        }
    }

    private var placementPage: some View {
        page(String(localized: "Where to put your iPhone"),
             String(localized: "This is what makes the counting work. Four things to check before each set.")) {
            VStack(alignment: .leading, spacing: 14) {
                // Always a standing figure: the point is the whole body in the frame.
                PlacementScene(kind: .bodyweightSquat)
                    .frame(height: 210)
                    .accessibilityIdentifier("onboarding.placementScene")
                VStack(alignment: .leading, spacing: 12) {
                    placementRow("rectangle.portrait.and.arrow.right", String(localized: "From the side"),
                                 String(localized: "Your profile faces the camera. From the front, Plumb still counts your reps, but posture advice needs your side."))
                    placementRow("arrow.up.and.down", String(localized: "At hip height"),
                                 String(localized: "Lean it against a bottle, a shoe or a bag, on the floor or a low bench."))
                    placementRow("figure.walk", String(localized: "A few steps away"),
                                 String(localized: "Two to three meters. Walk back to your iPhone to end the set."))
                    placementRow("person.crop.rectangle", String(localized: "Whole body in the frame"),
                                 String(localized: "Head and feet both visible, with a bit of room above and below."))
                }
                .optionCard()
                Label("The camera is asked for when you start your first set, not now.", systemImage: "camera")
                    .font(.footnote)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func placementRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One answer: a card that fills when chosen.
private struct ChoiceCard: View {
    let title: String
    let detail: String
    let symbol: String?
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button {
            withAnimation(HomeStyle.spring) { tap() }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(width: 28)
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .opacity(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
            .background(selected ? Color.primary : HomeStyle.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// One exercise as a small dark camera card, numbered once picked.
private struct ExerciseTile: View {
    let kind: ExerciseKind
    let rank: Int?
    let tap: () -> Void

    var body: some View {
        Button {
            withAnimation(HomeStyle.spring) { tap() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ExerciseFigureView(kind: kind)
                        .frame(height: 110)
                    if let rank {
                        Text("\(rank)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 26, height: 26)
                            .background(.white, in: Circle())
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(kind.chipName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(rank == nil ? .white.opacity(0.08) : .white, lineWidth: rank == nil ? 1 : 2))
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(kind.definition.copy.name)
        .accessibilityValue(rank.map { "Picked, number \($0)" } ?? "Not picked")
        .accessibilityAddTraits(rank == nil ? [] : .isSelected)
    }
}

/// The placement drawing: an iPhone standing at hip height on the left, the person a few steps away
/// on the right, a dotted line between them at hip height, and the camera's field of view.
struct PlacementScene: View {
    let kind: ExerciseKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 1 : 0.55 + 0.45 * (1 + sin(2 * .pi * seconds / 1.8)) / 2
            ZStack(alignment: .bottom) {
                Canvas { context, size in
                    draw(in: &context, size: size, pulse: pulse)
                }
                HStack(alignment: .bottom) {
                    Spacer()
                    // The figure's own floor (about 16 pt above its frame) sits on the scene's floor.
                    ExerciseFigureView(kind: kind)
                        .frame(width: 150, height: 160)
                        .padding(.trailing, 12)
                        .padding(.bottom, 18)
                }
            }
            .padding(14)
            .background(
                LinearGradient(colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .environment(\.colorScheme, .dark)
        }
        .accessibilityElement()
        .accessibilityLabel("Drawing: the iPhone stands at hip height a few steps from the person, filming from the side.")
        .accessibilityAddTraits(.isImage)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, pulse: Double) {
        let floorY = size.height - 34
        let white = Color.white

        // The floor.
        var floor = Path()
        floor.move(to: CGPoint(x: 10, y: floorY))
        floor.addLine(to: CGPoint(x: size.width - 10, y: floorY))
        context.stroke(floor, with: .color(white.opacity(0.18)), lineWidth: 1)

        // The iPhone, standing upright, its height about a hip.
        let phoneHeight: CGFloat = 54
        let phone = CGRect(x: 26, y: floorY - phoneHeight, width: 26, height: phoneHeight)
        let body = RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: phone)
        context.fill(body, with: .color(white.opacity(0.12)))
        context.stroke(body, with: .color(white), lineWidth: 2)
        // The camera, blinking softly.
        let lens = CGPoint(x: phone.maxX - 1, y: phone.minY + 10)
        let ring = Path(ellipseIn: CGRect(x: lens.x - 5, y: lens.y - 5, width: 10, height: 10))
        context.fill(ring, with: .color(white.opacity(0.25 + 0.6 * pulse)))

        // The field of view, towards the person.
        var cone = Path()
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: 22))
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: floorY - 4))
        context.stroke(cone, with: .color(white.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

        // The hip line, from the lens across the floor: "at hip height".
        var hipLine = Path()
        hipLine.move(to: CGPoint(x: phone.maxX + 8, y: lens.y))
        hipLine.addLine(to: CGPoint(x: size.width - 150, y: lens.y))
        context.stroke(hipLine, with: .color(white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))

        // The distance, written under the floor.
        let text = Text("2 to 3 m").font(.caption.weight(.semibold)).foregroundStyle(white.opacity(0.8))
        context.draw(context.resolve(text), at: CGPoint(x: (phone.maxX + size.width - 150) / 2, y: floorY + 16))
        var arrow = Path()
        arrow.move(to: CGPoint(x: phone.maxX + 6, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 - 34, y: floorY + 16))
        arrow.move(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 + 34, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: size.width - 150, y: floorY + 16))
        context.stroke(arrow, with: .color(white.opacity(0.4)), lineWidth: 1)

        // "Side view" label at the top left.
        let label = Text("Side view · hip height").font(.footnote.weight(.semibold)).foregroundStyle(white)
        context.draw(context.resolve(label), at: CGPoint(x: 14, y: 12), anchor: .topLeading)
    }
}
