import SwiftUI

/// the pink exercise chips of the Progress tab, one per exercise
struct ExercisePicker: View {
    @Binding var selection: ExerciseKind

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an exercise")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ExerciseKind.allCases, id: \.rawValue) { kind in
                        chip(kind)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(_ kind: ExerciseKind) -> some View {
        let selected = selection == kind
        return Button {
            selection = kind
        } label: {
            Text(kind.chipName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? DashboardStyle.accent : Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.definition.copy.name)
        .accessibilityIdentifier("progress.exercise.\(kind.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
