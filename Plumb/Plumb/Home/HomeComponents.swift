import AVFoundation
import SwiftUI

/// Colors of the app. Plumb is black on white (white on black at night): the camera carries the
/// screen, not an accent color.
enum HomeStyle {
    static let background = Color(uiColor: .systemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let supportingText = Color.primary.opacity(0.72)
    /// The placement drawing of the welcome is dark in both appearances, like the camera it stands for.
    static let cameraTop = Color(white: 0.11)
    static let cameraBottom = Color(white: 0.05)
    static let cameraSecondaryText = Color(white: 0.8)
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)
}

/// The pages behind the first screen's one icon.
enum HomeRoute: Hashable, CaseIterable {
    case history, coach, awards, options, privacy

    var title: String {
        switch self {
        case .history: String(localized: "History")
        case .coach: String(localized: "Coach")
        case .awards: String(localized: "Awards")
        case .options: String(localized: "Options")
        case .privacy: String(localized: "Privacy")
        }
    }

    var symbol: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .coach: "bubble.left.and.text.bubble.right"
        case .awards: "rosette"
        case .options: "slider.horizontal.3"
        case .privacy: "lock"
        }
    }
}

extension ExerciseKind {
    /// The short name, for a menu row.
    var chipName: String {
        switch self {
        case .bodyweightSquat: String(localized: "Squat")
        case .pushUp: String(localized: "Push-up")
        case .staticLunge: String(localized: "Lunge")
        case .stiffLegDeadlift: String(localized: "Deadlift")
        case .pullUp: String(localized: "Pull-up")
        case .muscleUp: String(localized: "Muscle-up")
        }
    }

    /// The first screen's title, one whole sentence so every language reads naturally.
    var readyTitle: LocalizedStringKey {
        switch self {
        case .bodyweightSquat: "Ready for squats?"
        case .pushUp: "Ready for push-ups?"
        case .staticLunge: "Ready for lunges?"
        case .stiffLegDeadlift: "Ready for deadlifts?"
        case .pullUp: "Ready for pull-ups?"
        case .muscleUp: "Ready for muscle-ups?"
        }
    }

    /// The name in a sentence: "27 push-ups".
    var pluralName: String {
        switch self {
        case .bodyweightSquat: String(localized: "squats")
        case .pushUp: String(localized: "push-ups")
        case .staticLunge: String(localized: "lunges")
        case .stiffLegDeadlift: String(localized: "deadlifts")
        case .pullUp: String(localized: "pull-ups")
        case .muscleUp: String(localized: "muscle-ups")
        }
    }
}

/// Liquid Glass behind a label, or a plain surface when the person has turned transparency off.
struct PlumbGlass<S: Shape>: ViewModifier {
    let shape: S
    var prominent = false
    var interactive = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(prominent ? Color.primary : HomeStyle.background, in: shape)
        } else if prominent {
            content.glassEffect(.regular.tint(Color.primary).interactive(interactive), in: shape)
        } else {
            content.glassEffect(.regular.tint(HomeStyle.background.opacity(0.55)).interactive(interactive),
                                in: shape)
        }
    }
}

extension View {
    /// A light glass surface, solid when transparency is reduced.
    func plumbGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(PlumbGlass(shape: shape, interactive: interactive))
    }

    /// The one filled surface of a screen: black glass (white at night).
    func plumbProminentGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(PlumbGlass(shape: shape, prominent: true, interactive: interactive))
    }

    /// A group of settings on its own rounded card.
    func optionCard() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The one filled action of a screen: a full-width black pill.
struct PrimaryActionLabel: View {
    let title: LocalizedStringKey
    var symbol: String? = nil

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(Color(uiColor: .systemBackground))
            .background(Color.primary, in: Capsule())
            .contentShape(Capsule())
    }
}

/// Presses in slightly, like a physical key.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Whether iOS has yet to ask for the camera, so Plumb can say what the camera is for first.
enum CameraPermission {
    static var notAskedYet: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined }
}

/// Shown once, before iOS asks for the camera: what Plumb does with it, in three lines.
struct CameraPrimer: View {
    let onContinue: () -> Void
    let onPrivacy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("What the camera does")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    primerRow("figure.strengthtraining.functional", "Counts your reps",
                              "Plumb follows one person from the side and ignores anyone else in view.")
                    primerRow("video.slash", "Keeps no video",
                              "Frames are analyzed on this iPhone, then dropped. Nothing is recorded.")
                    primerRow("iphone", "Sends nothing",
                              "No account, no upload. Your set summaries are saved on this iPhone.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 36)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 2) {
                Button(action: onContinue) {
                    PrimaryActionLabel(title: "Continue")
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("iOS then asks for camera access")
                .accessibilityIdentifier("primer.continue")
                HStack(spacing: 24) {
                    Button("Not now") { dismiss() }
                    Button("Privacy details", action: onPrivacy)
                        .accessibilityIdentifier("primer.privacy")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HomeStyle.supportingText)
                .frame(minHeight: 44)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .tint(.primary)
    }

    private func primerRow(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Everything that is not the next set, behind the first screen's one icon: a native list.
struct MoreSheet: View {
    let open: (HomeRoute) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(HomeRoute.allCases, id: \.self) { route in
                    Button { open(route) } label: {
                        Label(route.title, systemImage: route.symbol)
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier("more.\(route)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Plumb")
            .toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// The six exercises, large, each with its moving figure: touch one and the first screen follows.
struct ExercisePickerSheet: View {
    let order: [ExerciseKind]
    @Binding var selection: ExerciseKind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(order, id: \.self) { kind in
                        let selected = kind == selection
                        Button {
                            selection = kind
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                ExerciseFigureView(kind: kind, lineColor: selected ? Color(uiColor: .systemBackground) : .primary)
                                    .frame(height: 140)
                                Text(kind.definition.copy.name)
                                    .font(.headline)
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                            .background(selected ? Color.primary : HomeStyle.card,
                                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(kind.definition.copy.name)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("exercise.\(kind.rawValue)")
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(HomeStyle.background.ignoresSafeArea())
            .navigationTitle("Exercises")
            .toolbarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
