import SwiftUI

/// Finn's next workout on the pink card: when it starts and ends, then its intensity and how to
/// train at it. As tall as its content, so it never shows more pink than Home's card
struct NextWorkoutCard: View {
    let workout: NextWorkout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Next workout")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            when.padding(.top, 8)
            intensity.padding(.top, 8)
        }
        // Home's card padding, so the two cards hold about the same pink
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FinnCardSurface())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workout.next")
    }

    /// day · start – end on one line; one per line at accessibility sizes
    @ViewBuilder private var when: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.dayText)
                    Text(workout.timeRangeText)
                }
            } else {
                Text(verbatim: "\(workout.dayText) · \(workout.timeRangeText)")
            }
        }
        .font(.body.weight(.medium))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(String(localized: "\(workout.spokenDayText), \(workout.timeText) to \(workout.endTimeText)",
                                   comment: "VoiceOver: day, start time and end time of the next workout."))
    }

    /// the intensity row, then one line on how to train at it, in the same whisper as Home's quote
    private var intensity: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "flame").accessibilityHidden(true)
                Text("Intensity").font(.subheadline)
                Spacer(minLength: 8)
                Text(workout.intensity.title).font(.subheadline.weight(.semibold))
            }
            Text(workout.intensity.encouragement)
                .font(.subheadline.weight(.light))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
