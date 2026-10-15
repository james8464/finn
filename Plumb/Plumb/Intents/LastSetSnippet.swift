import SwiftUI

/// the card Siri and Spotlight show for "How did my last set go in Plumb": exercise, measured reps,
/// when, and the observation word for word. Nothing here is computed; it reads `LastSetReport`.
struct LastSetSnippet: View {
    enum Content: Equatable {
        case report(LastSetReport)
        case nothingYet
        case unavailable
    }

    let content: Content
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last set")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            switch content {
            case .report(let report):
                Text("\(report.exerciseName) · \(report.repsText)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(report.whenText(now: now))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(report.observationText, systemImage: "text.quote")
                    .font(.subheadline)
                    .padding(.top, 4)
            case .nothingYet:
                Text("No set measured yet")
                    .font(.title3.weight(.semibold))
                Text("Say \"Start a squat set in Plumb\" to begin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .unavailable:
                Text("History unavailable")
                    .font(.title3.weight(.semibold))
                Text("Unlock your iPhone and ask again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
