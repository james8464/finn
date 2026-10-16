    private func historyDetail(_ session: WorkoutSessionSummary) -> some View {
        Form {
            Section {
                Text(session.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(session.sets.indices, id: \.self) { index in
                let set = session.sets[index]
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(set.exercise.definition.copy.name).font(.headline)
                        Spacer()
                        Text("\(set.analysis.reps.count) measured reps")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(AppPageStyle.tint)
                    }
                    if let cue = set.cue {
                        if set.cueResponse == .notRelevant {
                            Text("Observation marked not relevant.").foregroundStyle(.secondary)
                        } else {
                            Text(cue.observation).font(.body.weight(.semibold))
                            nextAction(cue.nextAction)
                        }
                    } else {
                        Text("No observation").foregroundStyle(.secondary)
                    }
                    DisclosureGroup("Rep details") {
                        repList(set.analysis.reps, exercise: set.exercise)
                    }
                } header: {
                    Text("Set \(index + 1)")
                }
            }
            Section {
                fitnessHistoryLine(session)
                DisclosureGroup("About measurements") {
                    Text("These are camera measurements from one view, not a full technique assessment.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .tint(AppPageStyle.tint)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

