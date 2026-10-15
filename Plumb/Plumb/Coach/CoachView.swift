import SwiftUI

/// The Coach tab: a conversation about the saved sets, on dark silk. The coach speaks in glass
/// bubbles, the person in white ones.
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
                        DarkScreenTitle(title: "Coach")
                            .padding(.top, 4)
                            .padding(.bottom, 12)
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
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: conversation.messages.count) { _, _ in
                    guard let last = conversation.messages.last else { return }
                    withAnimation(HomeStyle.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    TextField("Ask Plumb", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .focused($fieldFocused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.leading, 18)
                        .padding(.vertical, 14)
                        .accessibilityIdentifier("coach.field")
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(.white, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || conversation.isAnswering)
                    .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                    .padding(.trailing, 8)
                    .accessibilityLabel("Send")
                    .accessibilityIdentifier("coach.send")
                }
                .plumbGlass(in: Capsule())
                Text(engineLine)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("coach.engine")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .darkScreen()
        .navigationTitle("")
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .onAppear { conversation.refresh(history: history) }
    }

    private var engineLine: String {
        switch conversation.engineKind {
        case .fallback: String(localized: "No language model available. The coach repeats what Plumb saved.")
        case .onDevice: String(localized: "Apple Intelligence chose the sets; the details come from Plumb's records.")
        case .privateCloudCompute: String(localized: "Apple Private Cloud Compute chose the sets; the details come from Plumb's records.")
        case .claudeDemo: String(localized: "Debug demo: Claude chose the sets; the details come from Plumb's records.")
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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .plumbGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(PressableStyle())
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
                    .foregroundStyle(isCoach ? Color.white : Color.black)
                    .fixedSize(horizontal: false, vertical: true)
                if isCoach, let engine = message.engine {
                    Text(engine.label)
                        .font(.caption2)
                        .foregroundStyle(HomeStyle.supportingText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isCoach {
                    Color.clear.plumbGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white)
                }
            }
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
