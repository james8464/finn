import SwiftUI

/// a plain conversation with the coach about the saved sets. Kept simple so it can be dressed later.
struct CoachView: View {
    @State private var conversation: CoachConversation
    @State private var draft = ""
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
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
                        if conversation.messages.count == 1, !conversation.suggestedQuestions.isEmpty {
                            suggestions
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: conversation.messages.count) { _, _ in
                    guard let last = conversation.messages.last else { return }
                    withAnimation(HomeStyle.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            Divider()
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    TextField("Ask about your sets", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
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
                            .font(.system(size: 30))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || conversation.isAnswering)
                    .accessibilityLabel("Send")
                    .accessibilityIdentifier("coach.send")
                }
                Text(engineLine)
                    .font(.caption2)
                    .foregroundStyle(HomeStyle.supportingText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("coach.engine")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(HomeStyle.background.ignoresSafeArea())
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { conversation.refresh(history: history) }
    }

    private var engineLine: String {
        switch conversation.engineKind {
        case .fallback: String(localized: "No language model available. The coach repeats what Plumb saved.")
        case .onDevice: String(localized: "Answered by Apple Intelligence on this device.")
        case .privateCloudCompute: String(localized: "Answered by Apple Private Cloud Compute.")
        case .claudeDemo: String(localized: "Debug demo: answered by Claude Sonnet via Anthropic API.")
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(HomeStyle.card, in: Capsule())
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
            if !isCoach { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isCoach ? Color.primary : Color(uiColor: .systemBackground))
                    .fixedSize(horizontal: false, vertical: true)
                if isCoach, let engine = message.engine {
                    Text(engine.label)
                        .font(.caption2)
                        .foregroundStyle(HomeStyle.supportingText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCoach ? HomeStyle.card : Color.primary,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if isCoach { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await conversation.send(text) }
    }
}
