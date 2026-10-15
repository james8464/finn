import SwiftUI

/// a conversation grounded in the saved sets, with source details one tap away
struct CoachView: View {
    @State private var conversation: CoachConversation
    @State private var draft = ""
    @State private var showsSource = false
    @State private var replyTask: Task<Void, Never>?
    @State private var followsLatestReply = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    @FocusState private var fieldFocused: Bool
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { fieldFocused = false }
                    .accessibilityIdentifier("coach.dismissKeyboard")
            }
        }
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
                    if conversation.messages.count == 1, !conversation.suggestedQuestions.isEmpty {
                        suggestions
                    }
                    Color.clear.frame(height: 1).id("conversation.bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .clipped()
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height - geometry.visibleRect.maxY < 100
            } action: { _, isNearBottom in
                followsLatestReply = isNearBottom
            }
            .onChange(of: conversation.messages.last?.id) { _, _ in
                // The conversation is capped at 40 messages, so its count eventually stops changing.
                guard followsLatestReply || conversation.messages.last?.role == .person else { return }
                scrollToLatest(using: proxy)
            }
            .onChange(of: conversation.isAnswering) { _, _ in
                if followsLatestReply { scrollToLatest(using: proxy) }
            }
            .onChange(of: fieldFocused) { _, focused in
                if focused {
                    conversation.prepare()
                }
            }
        }
    }

    private var composer: some View {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    TextField("Ask about your sets", text: $draft,
                              prompt: Text("Ask about your sets").foregroundStyle(HomeStyle.supportingText),
                              axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityLabel("Ask about your sets")
                        .textFieldStyle(.plain)
                        .focused($fieldFocused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityIdentifier("coach.field")
                        .onChange(of: draft) { previous, value in
                            // Multiline SwiftUI fields can insert a newline instead of invoking
                            // onSubmit for the software keyboard's Send key.
                            if let question = CoachDraft.submission(previous: previous, updated: value) {
                                draft = question
                                send()
                            } else if value.count > FoundationModelsCoachPrompt.maximumQuestionCharacters {
                                draft = String(value.prefix(FoundationModelsCoachPrompt.maximumQuestionCharacters))
                            }
                        }
                    Button {
                        if conversation.isAnswering {
                            replyTask?.cancel()
                        } else {
                            send()
                        }
                    } label: {
                        Image(systemName: conversation.isAnswering ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.title)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .tint(AppPageStyle.tint)
                    .disabled(!conversation.isAnswering && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(conversation.isAnswering ? String(localized: "Stop response") : String(localized: "Send"))
                    .accessibilityIdentifier(conversation.isAnswering ? "coach.stop" : "coach.send")
                }
            }
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

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(conversation.suggestedQuestions, id: \.self) { question in
                Button {
                    draft = question
                    send()
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

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo("conversation.bottom", anchor: .bottom)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !conversation.isAnswering else { return }
        followsLatestReply = true
        draft = ""
        replyTask = Task { await conversation.send(text) }
    }
}
