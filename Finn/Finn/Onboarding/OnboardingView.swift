import SwiftUI

/// the five first-launch screens. Each one can be skipped; the answers go to `FinnPreferences`
/// when the person taps Start, and the camera is asked for later, when a set starts
struct OnboardingView: View {
    let preferences: FinnPreferences
    /// called once the answers are saved (or the whole thing was skipped)
    let finished: (OnboardingProfile) -> Void

    @State private var step = 0
    @State private var profile: OnboardingProfile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let stepCount = 5

    init(preferences: FinnPreferences, finished: @escaping (OnboardingProfile) -> Void) {
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
        .tint(HomeStyle.accent)
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var progress: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    HStack {
                        backButton
                        Spacer()
                        skipAllButton
                    }
                    Text("\(step + 1) of \(Self.stepCount)")
                        .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    backButton
                    Spacer()
                    Text("\(step + 1) of \(Self.stepCount)")
                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    skipAllButton
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var backButton: some View {
        Button { withAnimation(reduceMotion ? nil : HomeStyle.spring) { step -= 1 } } label: {
            if typeSize.isAccessibilitySize {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            } else {
                Label("Back", systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
        }
        .accessibilityLabel("Back")
        .disabled(step == 0)
        .opacity(step == 0 ? 0 : 1)
    }

    private var skipAllButton: some View {
        Button(action: finish) { Text("Not now").frame(minHeight: 44) }
            .accessibilityIdentifier("onboarding.finish")
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
            Button {
                if isLast { finish() } else { withAnimation(reduceMotion ? nil : HomeStyle.spring) { step += 1 } }
            } label: {
                Text(isLast ? "Skip this" : "Skip")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(HomeStyle.supportingText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("onboarding.skip")
        }
    }

    private func advance() {
        if isLast { finish() } else { withAnimation(reduceMotion ? nil : HomeStyle.spring) { step += 1 } }
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
        page(String(localized: "Training goal"),
             String(localized: "Choose a focus for set feedback.")) {
            VStack(spacing: 10) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    ChoiceCard(title: goal.title, detail: nil, symbol: goal.symbol,
                               selected: profile.goal == goal) {
                        profile.goal = profile.goal == goal ? nil : goal
                    }
                    .accessibilityIdentifier("onboarding.goal.\(goal.rawValue)")
                }
            }
        }
    }

    private var exercisesPage: some View {
        page(String(localized: "Exercises"),
             String(localized: "Favorites appear first in Workout.")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
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
        page(String(localized: "Training experience"),
             String(localized: "Adjusts the detail in set feedback.")) {
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
        page(String(localized: "Spoken feedback"),
             String(localized: "Hear the countdown, rep count and live observations.")) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $profile.speaksLive) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Say reps aloud").font(.headline)
                    }
                }
                .tint(Color(uiColor: .systemGreen))
                .accessibilityIdentifier("onboarding.speaksLive")
                .optionCard()
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
                layout {
                    Image(systemName: "airpods.pro")
                        .font(.system(size: 22))
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Headphones").font(.headline)
                        Text("Audio plays through connected headphones or the iPhone speaker.")
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
        page(String(localized: "Camera setup"),
             String(localized: "Keep the phone upright on a stable support.")) {
            VStack(alignment: .leading, spacing: 14) {
                // always a standing figure: the point is the whole body in the frame
                PlacementScene(kind: .bodyweightSquat)
                    .frame(height: 210)
                    .accessibilityIdentifier("onboarding.placementScene")
                VStack(alignment: .leading, spacing: 12) {
                    placementRow("rectangle.portrait.and.arrow.right", String(localized: "From the side"),
                                 String(localized: "Your profile faces the camera. From the front, Finn still counts your reps, but posture advice needs your side."))
                    placementRow("arrow.up.and.down", String(localized: "At hip height"),
                                 String(localized: "Place the camera near hip height."))
                    placementRow("figure.walk", String(localized: "A few steps away"),
                                 Locale.current.measurementSystem == .us
                                     ? String(localized: "About seven to ten feet. Walk back to your iPhone to end the set.")
                                     : String(localized: "Two to three meters. Walk back to your iPhone to end the set."))
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
                .font(.system(size: 20))
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

/// one answer: a card that fills when chosen
private struct ChoiceCard: View {
    let title: String
    let detail: String?
    let symbol: String?
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .frame(width: 28)
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let detail { Text(detail)
                        .font(.subheadline)
                        .opacity(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? HomeStyle.accent : Color(uiColor: .secondaryLabel))
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(selected ? HomeStyle.accent.opacity(0.12) : HomeStyle.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// one exercise as a small dark camera card, numbered once picked
private struct ExerciseTile: View {
    let kind: ExerciseKind
    let rank: Int?
    let tap: () -> Void
    @ScaledMetric(relativeTo: .footnote) private var rankSize = 26.0

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ExerciseFigureView(kind: kind)
                        .frame(height: 110)
                    if let rank {
                        Text("\(rank)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: rankSize, height: rankSize)
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

/// the placement drawing: an iPhone standing at hip height on the left, the person a few steps away
/// on the right, a dotted line between them at hip height, and the camera's field of view
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
                    // the figure's own floor (about 16 pt above its frame) sits on the scene's floor
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
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
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

        // the floor
        var floor = Path()
        floor.move(to: CGPoint(x: 10, y: floorY))
        floor.addLine(to: CGPoint(x: size.width - 10, y: floorY))
        context.stroke(floor, with: .color(white.opacity(0.18)), lineWidth: 1)

        // the iPhone, standing upright, its height about a hip
        let phoneHeight: CGFloat = 54
        let phone = CGRect(x: 26, y: floorY - phoneHeight, width: 26, height: phoneHeight)
        let body = RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: phone)
        context.fill(body, with: .color(white.opacity(0.12)))
        context.stroke(body, with: .color(white), lineWidth: 2)
        // the camera, blinking softly
        let lens = CGPoint(x: phone.maxX - 1, y: phone.minY + 10)
        let ring = Path(ellipseIn: CGRect(x: lens.x - 5, y: lens.y - 5, width: 10, height: 10))
        context.fill(ring, with: .color(white.opacity(0.25 + 0.6 * pulse)))

        // the field of view, towards the person
        var cone = Path()
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: 22))
        cone.move(to: lens)
        cone.addLine(to: CGPoint(x: size.width - 18, y: floorY - 4))
        context.stroke(cone, with: .color(white.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

        // the hip line, from the lens across the floor: "at hip height"
        var hipLine = Path()
        hipLine.move(to: CGPoint(x: phone.maxX + 8, y: lens.y))
        hipLine.addLine(to: CGPoint(x: size.width - 150, y: lens.y))
        context.stroke(hipLine, with: .color(white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))

        // the distance, written under the floor
        // illustration labels share fixed geometry; the accessible description and
        // placement instructions below provide the scalable text
        let text = Text("2 to 3 m").font(.system(size: 12, weight: .semibold)).foregroundStyle(white.opacity(0.8))
        context.draw(context.resolve(text), at: CGPoint(x: (phone.maxX + size.width - 150) / 2, y: floorY + 16))
        var arrow = Path()
        arrow.move(to: CGPoint(x: phone.maxX + 6, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 - 34, y: floorY + 16))
        arrow.move(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 + 34, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: size.width - 150, y: floorY + 16))
        context.stroke(arrow, with: .color(white.opacity(0.4)), lineWidth: 1)

        // "Side view" label at the top left
        let label = Text("Side view · hip height").font(.system(size: 13, weight: .semibold)).foregroundStyle(white)
        context.draw(context.resolve(label), at: CGPoint(x: 14, y: 12), anchor: .topLeading)
    }
}
