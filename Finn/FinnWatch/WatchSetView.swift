import SwiftUI

/// one short iPhone-authored coaching line, with an optional Watch-owned rhythm
struct WatchSetView: View {
    let link: WatchLink
    private let accent = Color(.sRGB, red: 1, green: 45.0 / 255, blue: 146.0 / 255, opacity: 1)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let state = link.state {
                        content(for: state)
                    } else {
                        Image(systemName: "iphone")
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text("Open Finn on your iPhone to start a set.")
                            .multilineTextAlignment(.center)
                    }
                    if !link.isLiveCapture, link.state?.stage == .capturing {
                        Text("Waiting for iPhone connection")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let notice = link.notice {
                        noticeText(notice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 5)
            }
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        settings
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.black)
                            .accessibilityLabel("Watch settings")
                    }
                }
            }
        }
        .tint(accent)
        .environment(\.locale, Locale(identifier: link.state?.languageCode ?? "en-GB"))
    }

    @ViewBuilder private func content(for state: WatchState) -> some View {
        if state.demoInput && !ProcessInfo.processInfo.arguments.contains("-finn-presentation-capture") {
            Text("DEMO INPUT")
                .font(.caption2.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accent, in: Capsule())
        }
        Text(state.exercise.isEmpty ? "Finn" : state.exercise)
            .font(.headline)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        switch state.stage {
        case .ready,
             .framing:
            Image(systemName: "iphone.gen3")
                .font(.title2)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text("Get ready on your iPhone.")
                .multilineTextAlignment(.center)
        case .countdown:
            Text("Starting soon")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
            Text("Your iPhone is counting down.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .capturing:
            // a set with a rep target (Try Finn) counts towards it on the wrist too
            if let target = state.target {
                Text("\(state.reps)/\(target)")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .accessibilityLabel("Reps counted")
                    .accessibilityValue(Text("\(state.reps) of \(target)"))
            }
            if !link.isLiveCapture {
                Text("Coaching will resume when your iPhone reconnects.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let message = state.coachMessage {
                Text(message)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("I’m with you. Take the next rep at your own pace.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            if link.isLiveCapture, link.rhythmEnabled, state.hapticsEnabled {
                Label("Rhythm: \(link.rhythmInterval) seconds per rep", systemImage: "metronome")
                    .font(.footnote)
                    .foregroundStyle(accent)
            }
        case .analyzing,
             .result:
            Text("Set complete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
            Text("See your iPhone for the details.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var settings: some View {
        Form {
            Section {
                Toggle("Rhythm", isOn: Binding(
                    get: { link.rhythmEnabled },
                    set: { enabled in Task { await link.setRhythmEnabled(enabled) } }
                ))
                .disabled(link.state?.hapticsEnabled == false)
                Picker("Seconds per rep", selection: Binding(
                    get: { link.rhythmInterval },
                    set: { link.setRhythmInterval($0) }
                )) {
                    ForEach(2 ... 5, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .disabled(!link.rhythmEnabled)
            } footer: {
                Text(
                    "Rhythm is a pacing guide, not a form judgement. It starts a temporary Watch workout for taps with your wrist down. That workout is discarded; your iPhone controls Fitness saving."
                )
            }
            if link.state?.hapticsEnabled == false {
                Text("Turn on haptics in iPhone settings to use Watch rhythm.")
                    .font(.footnote)
            }
            if let notice = link.notice {
                noticeText(notice)
                    .font(.footnote)
            }
        }
        .navigationTitle("Watch settings")
    }

    @ViewBuilder private func noticeText(_ notice: WatchNotice) -> some View {
        switch notice {
        case .workoutPermission:
            Text("Allow temporary Watch workouts in Health settings to turn on rhythm.")
        case .workoutUnavailable:
            Text("Rhythm could not start. The coach messages still work.")
        }
    }
}
