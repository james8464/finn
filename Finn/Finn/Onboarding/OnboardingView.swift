import SwiftUI

/// the welcome, two demos, six questions, the plan offer, then a few details about the person.
/// Questions can be skipped; Continue waits for a first name, Access Finn for the training setup.
/// The answers go to `FinnPreferences` when the person leaves, and the camera is asked for later,
/// when a set starts
struct OnboardingView: View {
    let preferences: FinnPreferences
    /// called once the answers are saved (or the whole thing was skipped)
    let finished: (OnboardingProfile) -> Void

    @State private var stage = Stage.welcome
    @State private var step = Step.liveDemo
    @State private var profile: OnboardingProfile
    /// Finn's answer to the current choice; nil while Finn is quiet
    @State private var reaction: Reaction?
    @State private var reactionTask: Task<Void, Never>?
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        AppMotion.reduces(systemReduceMotion)
    }

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var typeSize

    private enum Stage { case welcome, questions, plan, aboutYou }

    /// the screens that carry the progress bar, in order
    private enum Step: Int, CaseIterable {
        case liveDemo
        case wearablesDemo
        case name
        case goal
        case level
        case pastProgram
        case intensity
        case days
    }

    private struct Reaction: Equatable {
        let line: String
        /// false while the LEDs light up
        var speaks: Bool
    }

    /// 00-Notes: Finn's line fades in over 180 ms
    private static let lineFade = 0.18
    /// how long the line stays before the next screen
    private static let lineHold = 1.5

    init(preferences: FinnPreferences, finished: @escaping (OnboardingProfile) -> Void) {
        self.preferences = preferences
        self.finished = finished
        _profile = State(initialValue: preferences.onboardingProfile)
    }

    var body: some View {
        Group {
            switch stage {
            case .welcome:
                OnboardingWelcomeView { show(.questions) }
                    .transition(.opacity)
            case .questions:
                questions
                    .transition(.opacity)
            case .plan:
                PaywallView(back: { show(.questions) }, next: { show(.aboutYou) })
                    .transition(.opacity)
            case .aboutYou:
                AboutYouView(profile: $profile, back: { show(.plan) }, finish: finish)
                    .transition(.opacity)
            }
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .tint(HomeStyle.accent)
        .interactiveDismissDisabled()
    }

    private func show(_ next: Stage) {
        withAnimation(reduceMotion ? nil : HomeStyle.spring) { stage = next }
    }

    // MARK: Chrome

    private var questions: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
            TabView(selection: $step) {
                page(
                    String(localized: "Finn watches every rep"),
                    String(localized: "Set your iPhone down. Move with Finn.")
                ) {
                    LiveCoachingDemo()
                }
                .tag(Step.liveDemo)
                page(
                    String(localized: "In your ears, on your wrist"),
                    String(
                        localized: "Feel the tempo on your wrist. Hear my cues through your AirPods or iPhone."
                    )
                ) {
                    WearablesDemo()
                }
                .tag(Step.wearablesDemo)
                namePage.tag(Step.name)
                goalPage.tag(Step.goal)
                levelPage.tag(Step.level)
                pastProgramPage.tag(Step.pastProgram)
                intensityPage.tag(Step.intensity)
                daysPage.tag(Step.days)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : HomeStyle.spring, value: step)
            // the options stay as they are while Finn answers
            .disabled(reaction != nil)
            if let reaction {
                FinnReaction(line: reaction.line, speaks: reaction.speaks)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .transition(.opacity)
            }
            actions
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .onChange(of: step) { _, newStep in
            endReaction()
            nameFocused = newStep == .name
        }
    }

    /// the row (Back, the counter, Not now), then the pink bar
    private var header: some View {
        VStack(spacing: 15) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 4) {
                        HStack {
                            backButton
                            Spacer()
                            skipAllButton
                        }
                        counter.font(.footnote.weight(.semibold))
                    }
                } else {
                    HStack {
                        backButton
                        Spacer()
                        counter.font(.subheadline.weight(.semibold))
                        Spacer()
                        skipAllButton
                    }
                }
            }
            .accessibilityElement(children: .contain)
            // the counter above already says how far along this is
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(DashboardStyle.accent)
                .accessibilityHidden(true)
                .animation(reduceMotion ? nil : HomeStyle.spring, value: step)
        }
    }

    private var counter: some View {
        Text("\(step.rawValue + 1) of \(Step.allCases.count)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var backButton: some View {
        OnboardingBackButton {
            guard let previous = Step(rawValue: step.rawValue - 1) else {
                return
            }
            withAnimation(reduceMotion ? nil : HomeStyle.spring) { step = previous }
        }
        .disabled(step == .liveDemo)
        .opacity(step == .liveDemo ? 0 : 1)
    }

    private var skipAllButton: some View {
        Button(action: finish) { Text("Not now").frame(minHeight: 44) }
            .accessibilityIdentifier("onboarding.finish")
    }

    /// the first name is the one answer Continue waits for: two titles use it
    private var continueDisabled: Bool {
        step == .name && profile.preferredName == nil
    }

    private var actions: some View {
        VStack(spacing: 2) {
            Button(action: advance) {
                PrimaryActionLabel(title: "Continue")
            }
            .buttonStyle(PressableStyle())
            .disabled(continueDisabled)
            .opacity(continueDisabled ? 0.4 : 1)
            .accessibilityIdentifier("onboarding.continue")
            Button(action: goToNextStep) {
                Text("Skip")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(HomeStyle.supportingText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("onboarding.skip")
        }
    }

    // MARK: Finn's reaction

    /// what Finn says about the current answer; nil on the demos, the name, or with no answer
    private var finnLine: String? {
        switch step {
        case .liveDemo,
             .wearablesDemo,
             .name:
            nil
        case .goal:
            profile.goal?.finnLine
        case .level:
            profile.level?.finnLine
        case .pastProgram:
            profile.followedProgram.map {
                $0 ? String(localized: "Good. We'll build on what worked.")
                    : String(localized: "No problem. We'll build one together.")
            }
        case .intensity:
            profile.intensity?.finnLine
        case .days:
            profile.days?.finnLine
        }
    }

    /// Continue: Finn answers the choice first, then the next screen comes by itself. Tapping
    /// again while Finn speaks moves on at once
    private func advance() {
        guard reaction == nil, let line = finnLine else {
            goToNextStep()
            return
        }
        reactionTask = Task { await react(with: line) }
    }

    private func react(with line: String) async {
        let fade = Animation.easeInOut(duration: Self.lineFade)
        if reduceMotion {
            withAnimation(fade) { reaction = Reaction(line: line, speaks: true) }
        } else {
            withAnimation(fade) { reaction = Reaction(line: line, speaks: false) }
            do { try await Task.sleep(for: .seconds(FinnReaction.waveDuration)) } catch { return }
            withAnimation(fade) { reaction?.speaks = true }
        }
        // VoiceOver reads the line, then waits for Continue rather than moving on by itself
        if voiceOverEnabled {
            AccessibilityNotification.Announcement(line).post()
            return
        }
        do { try await Task.sleep(for: .seconds(Self.lineFade + Self.lineHold)) } catch { return }
        goToNextStep()
    }

    private func endReaction() {
        reactionTask?.cancel()
        reactionTask = nil
        guard reaction != nil else {
            return
        }
        withAnimation(.easeInOut(duration: Self.lineFade)) { reaction = nil }
    }

    private func goToNextStep() {
        endReaction()
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(reduceMotion ? nil : HomeStyle.spring) { step = next }
        } else {
            show(.plan)
        }
    }

    private func finish() {
        endReaction()
        preferences.apply(profile)
        finished(profile)
    }

    // MARK: Pages

    private func page<Content: View>(
        _ title: String,
        _ subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(HomeStyle.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    private var namePage: some View {
        page(String(localized: "What should I call you?")) {
            OnboardingNameField(name: $profile.firstName, focus: $nameFocused) {
                if !continueDisabled {
                    advance()
                }
            }
        }
    }

    private var goalPage: some View {
        page(
            profile.preferredName.map { String(localized: "Your training goal, \($0)") }
                ?? String(localized: "Training goal"),
            String(localized: "Choose a focus for better coaching")
        ) {
            VStack(spacing: 10) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    ChoiceCard(
                        title: goal.title,
                        detail: nil,
                        symbol: goal.symbol,
                        selected: profile.goal == goal
                    ) {
                        profile.goal = profile.goal == goal ? nil : goal
                    }
                    .accessibilityIdentifier("onboarding.goal.\(goal.rawValue)")
                }
            }
        }
    }

    private var levelPage: some View {
        page(
            String(localized: "Training experience"),
            String(localized: "Adjusts training plan")
        ) {
            VStack(spacing: 10) {
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    ChoiceCard(
                        title: level.title,
                        detail: nil,
                        symbol: nil,
                        selected: profile.level == level
                    ) {
                        profile.level = profile.level == level ? nil : level
                    }
                    .accessibilityIdentifier("onboarding.level.\(level.rawValue)")
                }
            }
        }
    }

    /// Yes opens a second question below, to scroll to; No (or no answer) clears it
    private var pastProgramPage: some View {
        page(String(localized: "Have you ever followed a training program?")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach([true, false], id: \.self) { answer in
                    ChoiceCard(
                        title: answer ? String(localized: "Yes") : String(localized: "No"),
                        detail: nil,
                        symbol: nil,
                        selected: profile.followedProgram == answer
                    ) {
                        withAnimation(reduceMotion ? nil : HomeStyle.spring) {
                            profile.followedProgram = profile.followedProgram == answer ? nil : answer
                            if profile.followedProgram != true {
                                profile.stopReasons = []
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding.program.\(answer ? "yes" : "no")")
                }
                if profile.followedProgram == true {
                    stopReasons
                        .transition(.opacity)
                }
            }
        }
    }

    private var stopReasons: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Why did you stop?")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
            }
            .padding(.top, 22)
            .padding(.bottom, 4)
            ForEach(ProgramStopReason.allCases, id: \.self) { reason in
                ChoiceCard(
                    title: reason.title,
                    detail: nil,
                    symbol: nil,
                    selected: profile.stopReasons.contains(reason),
                    multiple: true
                ) {
                    if let index = profile.stopReasons.firstIndex(of: reason) {
                        profile.stopReasons.remove(at: index)
                    } else {
                        profile.stopReasons.append(reason)
                    }
                }
                .accessibilityIdentifier("onboarding.stopReason.\(reason.rawValue)")
            }
        }
    }

    private var intensityPage: some View {
        page(profile.preferredName.map { String(localized: "How hard do you want me to push you, \($0)?") }
            ?? String(localized: "How hard do you want me to push you?")) {
                VStack(spacing: 10) {
                    ForEach(TrainingIntensity.allCases, id: \.self) { intensity in
                        ChoiceCard(
                            title: intensity.title,
                            detail: nil,
                            symbol: nil,
                            selected: profile.intensity == intensity
                        ) {
                            profile.intensity = profile.intensity == intensity ? nil : intensity
                        }
                        .accessibilityIdentifier("onboarding.intensity.\(intensity.rawValue)")
                    }
                }
            }
    }

    private var daysPage: some View {
        page(String(localized: "How many days a week are you ready to train?")) {
            VStack(spacing: 10) {
                ForEach(TrainingDays.allCases, id: \.self) { days in
                    ChoiceCard(
                        title: days.title,
                        detail: nil,
                        symbol: nil,
                        selected: profile.days == days
                    ) {
                        profile.days = profile.days == days ? nil : days
                    }
                    .accessibilityIdentifier("onboarding.days.\(days.rawValue)")
                }
            }
        }
    }

    // MARK: Out of the flow
    // Exercises, Spoken feedback and Camera setup left the onboarding; they stay here, with the
    // answers they save, until favourite exercises move to Options

    private var exercisesPage: some View {
        page(
            String(localized: "Exercises"),
            String(localized: "Favorites appear first in Workout.")
        ) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: typeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: 10
            ) {
                ForEach(ExerciseKind.allCases, id: \.self) { kind in
                    ExerciseTile(
                        kind: kind,
                        rank: profile.favouriteExercises.firstIndex(of: kind).map { $0 + 1 }
                    ) {
                        if let index = profile.favouriteExercises.firstIndex(of: kind) {
                            profile.favouriteExercises.remove(at: index)
                        } else {
                            profile.favouriteExercises.append(kind)
                        }
                    }
                    .accessibilityIdentifier("onboarding.exercise.\(kind.rawValue)")
                }
            }
            .finnFeedback(.selection, trigger: profile.favouriteExercises)
        }
    }

    private var voicePage: some View {
        page(
            String(localized: "Spoken feedback"),
            String(localized: "Hear the countdown, rep count and live observations.")
        ) {
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
        page(
            String(localized: "Camera setup"),
            String(localized: "Keep the phone upright on a stable support.")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // always a standing figure: the point is the whole body in the frame
                PlacementScene(kind: .bodyweightSquat)
                    .frame(height: 210)
                    .accessibilityIdentifier("onboarding.placementScene")
                VStack(alignment: .leading, spacing: 12) {
                    placementRow(
                        "rectangle.portrait.and.arrow.right",
                        String(localized: "From the side"),
                        String(
                            localized: "Your profile faces the camera. From the front, Finn still counts your reps, but posture advice needs your side."
                        )
                    )
                    placementRow(
                        "arrow.up.and.down",
                        String(localized: "At hip height"),
                        String(localized: "Place the camera near hip height.")
                    )
                    placementRow(
                        "figure.walk",
                        String(localized: "A few steps away"),
                        Locale.current.measurementSystem == .us
                            ?
                            String(
                                localized: "About seven to ten feet. Walk back to your iPhone to end the set."
                            )
                            :
                            String(
                                localized: "Two to three meters. Walk back to your iPhone to end the set."
                            )
                    )
                    placementRow(
                        "person.crop.rectangle",
                        String(localized: "Whole body in the frame"),
                        String(localized: "Head and feet both visible, with a bit of room above and below.")
                    )
                }
                .optionCard()
                Label(
                    "The camera is asked for when you start your first set, not now.",
                    systemImage: "camera"
                )
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

/// one answer: a card that fills when chosen. Square check boxes when several answers can apply
private struct ChoiceCard: View {
    let title: String
    let detail: String?
    let symbol: String?
    let selected: Bool
    var multiple = false
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
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .opacity(0.78)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: multiple ? (selected ? "checkmark.square.fill" : "square")
                    : (selected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(selected ? HomeStyle.accent : Color(uiColor: .secondaryLabel))
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(
                selected ? HomeStyle.accent.opacity(0.12) : HomeStyle.card,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .finnFeedback(.selection, trigger: selected)
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
                LinearGradient(
                    colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        AppMotion.reduces(systemReduceMotion)
    }

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
                LinearGradient(
                    colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .environment(\.colorScheme, .dark)
        }
        .accessibilityElement()
        .accessibilityLabel(
            "Drawing: the iPhone stands at hip height a few steps from the person, filming from the side."
        )
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
        context.stroke(
            cone,
            with: .color(white.opacity(0.22)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 5])
        )

        // the hip line, from the lens across the floor: "at hip height"
        var hipLine = Path()
        hipLine.move(to: CGPoint(x: phone.maxX + 8, y: lens.y))
        hipLine.addLine(to: CGPoint(x: size.width - 150, y: lens.y))
        context.stroke(
            hipLine,
            with: .color(white.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6])
        )

        // the distance, written under the floor
        // illustration labels share fixed geometry; the accessible description and
        // placement instructions below provide the scalable text
        let text = Text("2 to 3 m").font(.system(size: 12, weight: .semibold))
            .foregroundStyle(white.opacity(0.8))
        context.draw(
            context.resolve(text),
            at: CGPoint(x: (phone.maxX + size.width - 150) / 2, y: floorY + 16)
        )
        var arrow = Path()
        arrow.move(to: CGPoint(x: phone.maxX + 6, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 - 34, y: floorY + 16))
        arrow.move(to: CGPoint(x: (phone.maxX + size.width - 150) / 2 + 34, y: floorY + 16))
        arrow.addLine(to: CGPoint(x: size.width - 150, y: floorY + 16))
        context.stroke(arrow, with: .color(white.opacity(0.4)), lineWidth: 1)

        // "Side view" label at the top left
        let label = Text("Side view · hip height").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(white)
        context.draw(context.resolve(label), at: CGPoint(x: 14, y: 12), anchor: .topLeading)
    }
}
