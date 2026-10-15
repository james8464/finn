import SwiftUI

/// Finn's next workout as a full-width square: when it is, Finn's line (the same one as on Home),
/// then what the workout holds. It grows past square at accessibility text sizes
struct NextWorkoutCard: View {
    let workout: NextWorkout
    let quote: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                content
            } else {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .topLeading) { content }
            }
        }
        .modifier(FinnCardSurface())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workout.next")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Next workout")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            when.padding(.top, 8)
            Text(String(localized: "“\(quote)”", comment: "Finn's encouragement, in quotation marks."))
                .font(.subheadline.weight(.light))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            Spacer(minLength: 24)
            details
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// day · time on one line; one per line at accessibility sizes
    @ViewBuilder private var when: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.dayText)
                    Text(workout.timeText)
                }
            } else {
                Text(verbatim: "\(workout.dayText) · \(workout.timeText)")
            }
        }
        .font(.body.weight(.medium))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(workout.spokenDayText), \(workout.timeText)")
    }

    /// what the workout holds, one row per field `NextWorkout` has beyond its time
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(.white.opacity(0.2)).frame(height: 1).accessibilityHidden(true)
            detailRow("Intensity", value: workout.intensity.title, symbol: "flame")
        }
    }

    private func detailRow(_ title: LocalizedStringKey, value: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).accessibilityHidden(true)
            Text(title).font(.subheadline)
            Spacer(minLength: 8)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}
