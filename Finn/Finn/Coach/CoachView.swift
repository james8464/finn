import SwiftUI

/// a conversation with Finn, who remembers the onboarding answers and reads the saved sets. Finn's
/// chosen face heads the screen, signs each reply and moves while a reply is on its way
struct CoachView: View {
    @State private var conversation: CoachConversation
    @State private var showsSource = false
    @State private var replyTask: Task<Void, Never>?
    @State private var followsLatestReply = true
    @State private var isUserScrolling = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.coach) private var coach
    /// Finn's face beside the heading, on each reply, and while Finn thinks
    @ScaledMetric(relativeTo: .title2) private var headingFace: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var replyFace: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var thinkingFace: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool {
        AppMotion.reduces(systemReduceMotion)
    }

    private let history: [WorkoutSessionSummary]
    /// the onboarding answers Finn remembers, as the document the model rereads every turn
    private let profile: String?
    /// the conversation kept between launches
    private let savedConversation: CoachTranscriptStore?

    init(history: [WorkoutSessionSummary], planningContext: WorkoutPlanningContext? = nil,
         transcript: CoachTranscriptStore? = nil) {
        self.history = history
        self.profile = planningContext?.profile.coachMemory
        self.savedConversation = transcript
        _conversation = State(initialValue: CoachConversation(
            history: history,
            profile: profile,
            transcript: transcript
        ))
    }

    init(history: [WorkoutSessionSummary], conversation: CoachConversation) {
        self.history = history
        self.profile = conversation.context.profile
        self.savedConversation = nil
        _conversation = State(initialValue: conversation)
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            composer

        }
        .background(AppPageStyle.background.ignoresSafeArea())
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsSource = true } label: {
                    Image(systemName: "info.circle")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("About Coach")
                .accessibilityIdentifier("coach.engine")
                .accessibilityHint("Explains how the Coach writes its answers")
            }

        }
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                List {
                    Section("Source") {
                        Text(engineLine)
                        if
                            let note = conversation
                                .engineNote {
                            Text(note).foregroundStyle(AppPageStyle.secondaryText)
                        }
                    }
                    Section {
                        Text(
                            "Coach answers with a language model and can make mistakes. It cannot diagnose an injury or assess your whole technique."
                        )
                    }
                }
                .navigationTitle("About Coach")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showsSource = false } } }
            }
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        }
        .onAppear { conversation.refresh(history: history, profile: profile) }
        .onChange(of: history) { _, updated in conversation.refresh(history: updated, profile: profile) }
        .onChange(of: profile) { _, updated in conversation.refresh(history: history, profile: updated) }
        // Delete all data emptied the saved conversation: the screen starts over too
        .onChange(of: savedConversation?.turns.isEmpty) { _, isEmpty in
            if isEmpty == true, conversation.messages.count > 1 {
                replyTask?.cancel()
                conversation.forget()
            }
        }
        .onDisappear {
            replyTask?.cancel()
            replyTask = nil
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    FinnBadge(showsOutline: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Finn, your coach")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("coach.finn")
                    // Finn's greeting heads the conversation, then the analysis card, then the turns
                    if let opening = conversation.messages.first {
                        openingCard(opening).id(opening.id)
                    }
                    analysisCard.padding(.bottom, 4)
                    // like a messaging app: the day above its first message, a thin line after
                    // a pause, the time on each message
                    let turns = Array(conversation.messages.dropFirst())
                    ForEach(Array(turns.enumerated()), id: \.element.id) { index, message in
                        if let marker = CoachTimeline.marker(for: message, after: index > 0 ? turns[index - 1] : nil) {
                            timelineMarker(marker)
                        }
                        bubble(message).id(message.id)
                    }
                    if conversation.isAnswering, let draft = conversation.draftReply, !draft.isEmpty {
                        bubble(CoachMessage(role: .coach, text: draft), identifier: "coach.draft", showsTime: false)
                    } else if conversation.isAnswering {
                        thinking
                    }
                    if showsPrompts {
                        prompts
                    }
                    Color.clear.frame(height: 1).id("conversation.bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            // the thread opens at its latest messages, as in Messages
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            // no Done button: dragging the conversation down into the keyboard, or touching the
            // conversation, puts the keyboard away, as in Messages and WhatsApp
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .accessibilityIdentifier("coach.transcript")
            .clipped()
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height - geometry.visibleRect.maxY < 24
            } action: { _, isNearBottom in
                if isUserScrolling {
                    followsLatestReply = isNearBottom
                } else if followsLatestReply && !isNearBottom {
                    // Resizing for the keyboard is layout work. Animating this correction can
                    // feed intermediate scroll positions back into another animation.
                    scrollToLatest(using: proxy, animated: false)
                }
            }
            .onScrollPhaseChange { _, phase in
                isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
            }
            .onChange(of: conversation.messages.last?.id) { _, _ in
                // The conversation is capped at 40 messages, so its count eventually stops changing.
                guard followsLatestReply || conversation.messages.last?.role == .person else {
                    return
                }
                scrollToLatest(using: proxy)
            }
            .onChange(of: conversation.isAnswering) { _, _ in
                if followsLatestReply {
                    scrollToLatest(using: proxy)
                }
            }
            .onChange(of: conversation.draftReply) { _, _ in
                // follows the reply while the model writes it, without animating every word
                if followsLatestReply {
                    scrollToLatest(using: proxy, animated: false)
                }
            }
        }
    }

    private var composer: some View {
        CoachComposerField(
            isAnswering: conversation.isAnswering,
            onSubmit: send,
            onStop: { replyTask?.cancel() },
            onFocus: conversation.prepare
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppPageStyle.background)
    }

    private var engineLine: String {
        switch conversation.engineKind {
        case .fallback:
            String(localized: "No language model available. The coach repeats what Finn saved.")
        case .onDevice:
            String(
                localized: "Apple Intelligence writes the answers on this iPhone, using your saved sets."
            )
        case .privateCloudCompute:
            String(
                localized: "Apple Private Cloud Compute writes the answers, using your saved sets."
            )
        case .claudeDemo:
            String(
                localized: "Debug demo: Claude writes the answers, using your saved sets."
            )
        }
    }

    /// Finn's greeting: who is talking, with the chosen face beside the name
    private func openingCard(_ message: CoachMessage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(AppPageStyle.tint)
                .accessibilityHidden(true)
            HStack(spacing: 10) {
                Text("Talk to Finn")
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                CoachAvatar(coach: coach, size: headingFace)
            }
            Text(message.text)
                .font(.body)
                .foregroundStyle(AppPageStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("coach.opening")
        }
        .modifier(AppSurface())
    }

    /// the day, in a small capsule centred above its first message, or the thin line of a pause
    @ViewBuilder private func timelineMarker(_ marker: CoachTimeline.Marker) -> some View {
        switch marker {
        case .day(let date):
            Text(CoachTimeline.dayLabel(for: date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(HomeStyle.supportingText)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(AppPageStyle.surface, in: Capsule())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("coach.day")
        case .pause:
            Rectangle()
                .fill(HomeStyle.supportingText.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    /// Finn's face, swaying while the model works, where the reply will appear
    private var thinking: some View {
        HStack(spacing: 10) {
            ThinkingFace(coach: coach, size: thinkingFace, moves: !reduceMotion)
            Text("Thinking")
                .font(.subheadline)
                .foregroundStyle(HomeStyle.supportingText)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coach.thinking")
    }

    /// the whole picture in one tap, sent like a typed question. Framed like Home's Last workout
    private var analysisCard: some View {
        FinnOutline {
            Button { send(conversation.analysisRequest) } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        DashboardHeading("Analyze my progress")
                        Text("Where I stand, what to do next, what to avoid.")
                            .font(.footnote)
                            .foregroundStyle(DashboardStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(DashboardStyle.accent)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.primary)
                .modifier(DashboardCard())
            }
            .buttonStyle(PressableStyle())
            .disabled(conversation.isAnswering)
            .accessibilityHint("Asks Finn to analyze your saved sets")
            .accessibilityIdentifier("coach.analysis")
        }
    }

    /// the prompts stay until the person asks their first question
    private var showsPrompts: Bool {
        !conversation.suggestedQuestions.isEmpty && !conversation.messages.contains { $0.role == .person }
    }

    /// questions to tap, on glass, sent like typed ones. The row scrolls when they don't fit
    private var prompts: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(conversation.suggestedQuestions, id: \.self) { question in
                        Button { send(question) } label: {
                            Text(question)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .accessibilityHint("Sends this question to Finn")
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .disabled(conversation.isAnswering)
        .accessibilityIdentifier("coach.suggestions")
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(conversation.suggestedQuestions, id: \.self) { question in
                Button {
                    _ = send(question)
                } label: {
                    Text(question)
                        .font(.subheadline)
                        .frame(minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .accessibilityIdentifier("coach.suggestions")
    }

    @ViewBuilder private func bubble(_ message: CoachMessage, identifier: String? = nil, showsTime: Bool = true) -> some View {
        let isCoach = message.role == .coach
        HStack {
            if !isCoach {
                Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 40)
            }
            // the time sits at the bottom right of the bubble, as in a messaging app
            VStack(alignment: .trailing, spacing: 2) {
                VStack(alignment: .leading, spacing: 6) {
                    // like a group chat: the face and name of who is talking, above the text
                    if isCoach {
                        HStack(spacing: 6) {
                            CoachAvatar(coach: coach, size: replyFace)
                            Text(verbatim: "Finn")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DashboardStyle.accent)
                        }
                    }
                    Text(isCoach ? Self.formatted(message.text) : AttributedString(message.text))
                        .font(.body)
                        .foregroundStyle(isCoach ? Color.primary : Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if showsTime {
                    Text(CoachTimeline.time(of: message.sentAt))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(isCoach ? HomeStyle.supportingText : Color.black.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isCoach ? AppPageStyle.surface : AppPageStyle.action,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            if isCoach {
                Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 40)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? (isCoach ? "coach.answer.\(message.engine?.rawValue ?? "opening")" :
                "coach.question"))
    }

    /// model replies can carry inline Markdown such as **bold**; show it styled, never as symbols
    private static func formatted(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(!animated || reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo("conversation.bottom", anchor: .bottom)
        }
    }

    @discardableResult
    private func send(_ question: String) -> Bool {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !conversation.isAnswering else {
            return false
        }
        followsLatestReply = true
        FinnHaptics.play(.selection)
        replyTask = Task { await conversation.send(text) }
        return true
    }
}

/// Finn's face while a reply is on its way: it sways and breathes in place of a spinner. With
/// Reduce Motion it only fades in and out
private struct ThinkingFace: View {
    let coach: Coach
    let size: CGFloat
    let moves: Bool

    private struct Pose {
        var scale = 1.0
        var tilt = 0.0
        var lift = 0.0
    }

    var body: some View {
        if moves {
            CoachAvatar(coach: coach, size: size)
                .keyframeAnimator(initialValue: Pose(), repeating: true) { face, pose in
                    face
                        .scaleEffect(pose.scale)
                        .rotationEffect(.degrees(pose.tilt))
                        .offset(y: pose.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.12, duration: 0.5)
                        SpringKeyframe(0.92, duration: 0.5)
                        SpringKeyframe(1, duration: 0.4)
                    }
                    KeyframeTrack(\.tilt) {
                        CubicKeyframe(-12, duration: 0.35)
                        CubicKeyframe(12, duration: 0.7)
                        CubicKeyframe(0, duration: 0.35)
                    }
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(-size * 0.1, duration: 0.7)
                        CubicKeyframe(0, duration: 0.7)
                    }
                }
        } else {
            CoachAvatar(coach: coach, size: size)
                .phaseAnimator([1.0, 0.4]) { face, opacity in
                    face.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
        }
    }
}
