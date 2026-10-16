import SwiftUI

/// a conversation grounded in the saved sets, with source details one tap away
struct CoachView: View {
    @State private var conversation: CoachConversation
    @State private var draft = ""
    @State private var showsSource = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // who the person talks to, and the one-tap analysis. They scroll away with the turns
                    CoachBadge(showsOutline: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Finn, your coach")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("coach.finn")
                    analysisCard.padding(.bottom, 4)
                    ForEach(conversation.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                    if conversation.isAnswering {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking")
                                .font(.subheadline)
                                .foregroundStyle(HomeStyle.supportingText)
                        }
                        .padding(.horizontal, 4)
                        .id("thinking")
                    }
                    // at accessibility sizes the row scrolls with the turns, so the conversation keeps its room
                    if showsPrompts && typeSize.isAccessibilitySize {
                        prompts
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation.messages.count) { _, _ in
                guard let last = conversation.messages.last else { return }
                withAnimation(reduceMotion ? nil : HomeStyle.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if showsPrompts && !typeSize.isAccessibilitySize {
                    prompts.transition(.opacity)
                }
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
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.isAnswering)
                    .accessibilityLabel("Send")
                    .accessibilityIdentifier("coach.send")
                }
                Button { showsSource = true } label: {
                    Label("About Coach", systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.engine")
                .accessibilityHint("Explains how the Coach chooses its answer")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(HomeStyle.background)
            .animation(reduceMotion ? nil : HomeStyle.spring, value: showsPrompts)
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
                        if let note = conversation.engineNote { Text(note).foregroundStyle(.secondary) }
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

    @ViewBuilder private func bubble(_ message: CoachMessage) -> some View {
        let isCoach = message.role == .coach
        HStack {
            if !isCoach { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isCoach ? Color.primary : HomeStyle.onAccent)
                    .fixedSize(horizontal: false, vertical: true)
                if isCoach, !history.isEmpty, let engine = message.engine {
                    Text(engine.label)
                        .font(.caption)
                        .foregroundStyle(HomeStyle.supportingText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCoach ? HomeStyle.card : HomeStyle.filledAccent,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if isCoach { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    /// the typed question: sent, then the field clears
    private func send() {
        if send(draft) { draft = "" }
    }

    /// the one way a question reaches the coach: typed, a prompt or the analysis card
    @discardableResult private func send(_ text: String) -> Bool {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !conversation.isAnswering else { return false }
        Task { await conversation.send(question) }
        return true
    }
}
