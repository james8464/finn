import SwiftUI

/// a conversation grounded in the saved sets, with source details one tap away
struct CoachView: View {
    @State private var conversation: CoachConversation
    @State private var showsSource = false
    @State private var planDraft: PlannedWorkout?
    @State private var replyTask: Task<Void, Never>?
    @State private var followsLatestReply = true
    @State private var isUserScrolling = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    private let history: [WorkoutSessionSummary]

    init(history: [WorkoutSessionSummary]) {
        self.history = history
        _conversation = State(initialValue: CoachConversation(history: history))
    }

    init(history: [WorkoutSessionSummary], conversation: CoachConversation) {
        self.history = history
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
            ToolbarItem(placement: .topBarLeading) {
            Button { planDraft = WorkoutPlanner.make(history: history) } label: {
                Label("Plan a workout", systemImage: "list.bullet.clipboard")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("coach.planWorkout")
            .accessibilityHint("Composes a workout from your saved sets")
            }
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
                .accessibilityHint("Explains how the Coach chooses its answer")
            }

        }
        .sheet(item: $planDraft) { WorkoutPlanView(plan: $0) }
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                List {
                    Section("Source") {
                        Text(engineLine)
                        if let note = conversation.engineNote { Text(note).foregroundStyle(AppPageStyle.secondaryText) }
                    }
                    Section { Text("Coach can describe saved measurements. It cannot diagnose an injury or assess your whole technique.") }
                }
                .navigationTitle("About Coach")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsSource = false } } }
            }
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        }
        .onAppear { conversation.refresh(history: history) }
        .onChange(of: history) { _, updated in conversation.refresh(history: updated) }
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
                    analysisCard.padding(.bottom, 4)
                    ForEach(conversation.messages) { message in
                        if conversation.messages.count == 1 {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppPageStyle.tint)
                                    .accessibilityHidden(true)
                                Text("Ask about your sets")
                                    .font(.title2.weight(.bold))
                                Text(message.text)
                                    .font(.body)
                                    .foregroundStyle(AppPageStyle.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .modifier(AppSurface())
                            .id(message.id)
                        } else {
                            bubble(message).id(message.id)
                        }
                    }
                    if conversation.isAnswering {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking")
                                .font(.subheadline)
                                .foregroundStyle(HomeStyle.supportingText)
                        }
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("coach.thinking")
                    }
                    if showsPrompts {
                        prompts
                    }
                    Color.clear.frame(height: 1).id("conversation.bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
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
                guard followsLatestReply || conversation.messages.last?.role == .person else { return }
                scrollToLatest(using: proxy)
            }
            .onChange(of: conversation.isAnswering) { _, _ in
                if followsLatestReply { scrollToLatest(using: proxy) }
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
        case .fallback: String(localized: "No language model available. The coach repeats what Finn saved.")
        case .onDevice: String(localized: "Apple Intelligence chose the sets; the details come from Finn's records.")
        case .privateCloudCompute: String(localized: "Apple Private Cloud Compute chose the sets; the details come from Finn's records.")
        case .claudeDemo: String(localized: "Debug demo: Claude chose the sets; the details come from Finn's records.")
        }
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

    @ViewBuilder private func bubble(_ message: CoachMessage) -> some View {
        let isCoach = message.role == .coach
        HStack {
            if !isCoach { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isCoach ? Color.primary : Color.black)
                    .fixedSize(horizontal: false, vertical: true)
                if isCoach, !history.isEmpty, let engine = message.engine {
                    Text(engine.label)
                        .font(.caption)
                        .foregroundStyle(HomeStyle.supportingText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCoach ? AppPageStyle.surface : AppPageStyle.action,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if isCoach { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(isCoach ? "coach.answer.\(message.engine?.rawValue ?? "opening")" : "coach.question")
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(!animated || reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo("conversation.bottom", anchor: .bottom)
        }
    }

    private func send(_ question: String) -> Bool {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !conversation.isAnswering else { return false }
        followsLatestReply = true
        replyTask = Task { await conversation.send(text) }
        return true
    }
}
