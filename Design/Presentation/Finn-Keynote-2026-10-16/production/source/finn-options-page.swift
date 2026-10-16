    private var optionsPage: some View {
        Form {
            Section {
                Toggle("Start and stop sets for me", isOn: Binding(
                    get: { model.handsFree }, set: { model.handsFree = $0 }
                ))
                .accessibilityIdentifier("options.handsFree")
                Toggle("Say reps aloud", isOn: Binding(
                    get: { model.speaksLive }, set: { model.speaksLive = $0 }
                ))
                .accessibilityIdentifier("options.speaksLive")
            } header: {
                Text("Hands-free")
            } footer: {
                Text("Hold position to start. Walk back or stop moving to finish.")
            }

            Section {
                Picker("Haptics", selection: Binding(
                    get: { model.hapticFeedback },
                    set: { style in
                        model.hapticFeedback = style
                        if style != .off { workoutFeedback.play(.rep, haptics: style, sound: .off) }
                    }
                )) {
                    ForEach(HapticFeedbackStyle.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("options.hapticFeedback")
                Picker("Sound effects", selection: Binding(
                    get: { model.soundFeedback },
                    set: { style in
                        model.soundFeedback = style
                        if style != .off { workoutFeedback.play(.setStarted, haptics: .off, sound: style) }
                    }
                )) {
                    ForEach(SoundFeedbackStyle.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("options.soundFeedback")
            } header: {
                Text("Workout feedback")
            } footer: {
                Text("Your iPhone taps at the start and end of a set; Apple Watch taps each rep. Optional tones mark the set. Sounds respect Silent Mode and play alongside your music.")
            }

            Section {
                if model.recognitionMethod != .unavailable {
                    Toggle("Recognize the exercise automatically", isOn: Binding(
                        get: { model.recognizesExercise }, set: { model.recognizesExercise = $0 }
                    ))
                    .accessibilityIdentifier("options.recognizeExercise")
                }
                if model.hasExerciseClassifier {
                    Toggle("Use the trained model instead (experimental)", isOn: Binding(
                        get: { model.usesTrainedModel }, set: { model.usesTrainedModel = $0 }
                    ))
                    .accessibilityIdentifier("options.useTrainedModel")
                }
            } header: {
                Text("Exercise recognition")
            } footer: {
                switch model.recognitionMethod {
                case .keypointModel, .angleModel:
                    Text("Experimental on-device estimate. Uses your selection when uncertain.")
                case .angleRules:
                    Text("Estimates from joint angles; uses your selection when uncertain.")
                case .unavailable:
                    Text("Exercise recognition unavailable. Uses your selection.")
                }
            }

            Section {
                Toggle("Check the camera angle in 3D", isOn: Binding(
                    get: { model.checksCameraAngle }, set: { model.checksCameraAngle = $0 }
                ))
                .accessibilityIdentifier("options.checkCameraAngle")
            } header: {
                Text("Camera angle")
            } footer: {
                Text("Posture feedback requires a side view. Turn this off if the angle estimate is wrong.")
            }

            Section {
                Toggle("Save workouts to Apple Fitness", isOn: Binding(
                    get: { model.savesToFitness },
                    set: { isOn in
                        model.savesToFitness = isOn
                        if isOn { Task { await model.requestFitnessAccess() } }
                    }
                ))
                .disabled(!model.offersFitness)
                .accessibilityIdentifier("options.savesToFitness")
                if let note = fitnessOptionNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("options.fitnessNote")
                }
            } header: {
                Text("Apple Fitness")
            } footer: {
                Text("Saves finished sessions with duration and reps, without calorie or heart-rate estimates.")
            }

            Section {
                Toggle("Use my Health data", isOn: Binding(
                    get: { model.personalizesWithHealth },
                    set: { isOn in Task { await model.setPersonalizesWithHealth(isOn) } }
                ))
                .disabled(!model.offersHealthPersonalization)
                .accessibilityIdentifier("options.personalizesWithHealth")
                if !model.offersHealthPersonalization {
                    Text("Demo and recorded input never read Health.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DisclosureGroup("Health data") {
                    ForEach(HealthReadType.allCases, id: \.self) { type in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title).font(.subheadline.weight(.semibold))
                            Text(type.use).font(.footnote).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Personalize with Health")
            } footer: {
                Text("Tailors rest and recovery advice. Data stays on this iPhone.")
            }

            Section {
                LabeledContent("Language") {
                    Text(Locale(identifier: SpokenLanguage.appLanguage)
                        .localizedString(forIdentifier: SpokenLanguage.appLanguage) ?? SpokenLanguage.appLanguage)
                }
                Button("Choose app language") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .accessibilityIdentifier("options.language")
            } footer: {
                Text("Choose English (UK), English (US), French or Spanish in iPhone Settings. Finn uses your region for dates and numbers.")
            }

            Section {
                Button("Replay the welcome") { showsOnboarding = true }
                    .accessibilityIdentifier("options.replayOnboarding")
            } header: {
                Text("Welcome")
            } footer: {
                Text("The first-launch screens: your goal, your exercises, your level, the voice, and where to put your iPhone. Your choices set exercise order and help Coach select relevant saved sets.")
            }
            #if DEBUG
            Section { CoachDeveloperSection() }
            #endif
        }
        .formStyle(.grouped)
        .tint(AppPageStyle.tint)
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.large)
    }

