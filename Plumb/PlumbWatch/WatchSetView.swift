import SwiftUI

/// the set the iPhone is measuring: exercise, stage, a large rep count, the latest live observation,
/// and Start set or Stop set when the hands are free to press them
struct WatchSetView: View {
    let link: WatchLink

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let state = link.state {
                    content(for: state)
                } else {
                    Image(systemName: "iphone")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text("Open Plumb on your iPhone to start a set.")
                        .multilineTextAlignment(.center)
                }
                if let beats = link.heart.beatsPerMinute {
                    Label("\(beats) bpm", systemImage: "heart.fill")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.red)
                        .accessibilityLabel("Heart rate \(beats) beats per minute")
                } else if let problem = link.heart.problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let notice = link.notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func content(for state: WatchState) -> some View {
        if state.demoInput {
            Text("DEMO INPUT")
                .font(.caption2.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.yellow, in: Capsule())
        }
        Text(state.exercise.isEmpty ? "Plumb" : state.exercise)
            .font(.headline)
        switch state.stage {
        case .ready:
            Text("Set up the camera on your iPhone.")
                .multilineTextAlignment(.center)
        case .framing:
            Text("Get in position")
            Text(framingHint(for: state))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if state.wristControls {
                command("Start set", .startSet)
            }
        case .countdown:
            Text("\(state.countdown)")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("Starting in \(state.countdown)")
        case .capturing:
            Text("Set running")
                .font(.footnote)
                .foregroundStyle(.secondary)
            repCount(state.reps)
            if let caption = state.caption {
                Text(caption)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            if state.wristControls {
                command("Stop set", .stopSet)
            }
        case .analyzing:
            ProgressView()
            Text("Reviewing")
        case .result:
            if state.reps > 0 {
                repCount(state.reps)
            }
            if let summary = state.summary {
                Text(summary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func framingHint(for state: WatchState) -> String {
        if state.handsFree { return String(localized: "The set starts once you hold still.") }
        return state.wristControls ? String(localized: "Then start the set.") : String(localized: "Start the set on your iPhone.")
    }

    private func repCount(_ reps: Int) -> some View {
        VStack(spacing: 0) {
            Text("\(reps)")
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(reps == 1 ? "rep" : "reps")
                .font(.footnote)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps counted")
        .accessibilityValue("\(reps)")
    }

    private func command(_ title: LocalizedStringKey, _ command: WatchCommand) -> some View {
        Button(title) { link.send(command) }
            .buttonStyle(.borderedProminent)
            .disabled(!link.isPhoneReachable)
    }
}
