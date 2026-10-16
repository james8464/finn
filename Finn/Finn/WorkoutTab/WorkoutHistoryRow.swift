import SwiftUI

/// one saved session: its exercises and reps, when, how many sets, and the latest observation the
/// person kept. Opens the session's sets
struct WorkoutHistoryRow: View {
    let session: WorkoutSessionSummary
    var savedToFitness = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(exerciseNames) · \(reps) reps")
                        .font(.headline)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Group {
                        if savedToFitness { Text("\(when) · \(sets) · Saved to Fitness") } else { Text("\(when) · \(sets)") }
                    }
                    .font(.subheadline)
                    .foregroundStyle(DashboardStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    if let note {
                        Label(note, systemImage: "text.quote")
                            .font(.subheadline)
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DashboardStyle.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(DashboardGlass(showsBorder: false))
            .contentShape(RoundedRectangle(cornerRadius: DashboardStyle.cardRadius))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Review measured sets")
        .accessibilityIdentifier("workout.session")
    }

    private var reps: Int { session.sets.reduce(0) { $0 + $1.analysis.reps.count } }

    private var sets: String { String(localized: "\(session.sets.count) sets") }

    private var exerciseNames: String {
        var names: [String] = []
        for set in session.sets where !names.contains(set.exercise.definition.copy.name) {
            names.append(set.exercise.definition.copy.name)
        }
        return names.joined(separator: ", ")
    }

    private var when: String {
        let time = session.startedAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(session.startedAt) { return String(localized: "Today, \(time)") }
        if Calendar.current.isDateInYesterday(session.startedAt) { return String(localized: "Yesterday, \(time)") }
        return session.startedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    /// the latest observation the person kept, word for word
    private var note: String? {
        session.sets.last(where: { $0.cue != nil && $0.cueResponse != .notRelevant })?.cue?.observation
    }
}
