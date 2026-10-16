import SwiftUI

/// the two parts of the Progress tab. Home's Posture card always opens `.posture`
enum ProgressSection: String, CaseIterable, Hashable {
    case posture, strength

    var title: LocalizedStringKey {
        switch self {
        case .posture: "Posture"
        case .strength: "Strength"
        }
    }
}

/// one chosen exercise, seen two ways: how to move well, and how the person's sets have grown
struct ProgressTabView: View {
    let history: [WorkoutSessionSummary]
    @Binding var section: ProgressSection
    @Binding var exercise: ExerciseKind
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Section", selection: $section) {
                    ForEach(ProgressSection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("progress.section")
                ExercisePicker(selection: $exercise)
                Group {
                    switch section {
                    case .posture: PostureSection(history: history, exercise: exercise)
                    case .strength: StrengthSection(history: history, exercise: exercise)
                    }
                }
                .id(section)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: section)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("progress.scroll")
        .foregroundStyle(.white)
        .background { HomeBackdrop() }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
    }
}
