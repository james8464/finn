import AVFoundation
import SwiftUI

/// shared semantic colours. Content surfaces stay opaque; system bars provide materials.
enum HomeStyle {
    static let background = Color(uiColor: .systemBackground)
    static let accent = Color.primary
    /// monochrome actions invert with the system appearance
    static let filledAccent = Color.primary
    static let onAccent = Color(uiColor: .systemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let supportingText = AppPageStyle.secondaryText
    /// the camera card is dark in both appearances, like the camera view it stands for
    static let cameraTop = Color(white: 0.11)
    static let cameraBottom = Color(white: 0.05)
    /// supporting text on the camera card, solid so its contrast does not depend on what is behind
    static let cameraSecondaryText = Color(white: 0.8)
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)
}

/// a small category marker shared by dashboard widgets and supporting pages
struct HomeSymbol: View {
    let name: String
    var colour: Color = HomeStyle.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(colour)
            .frame(width: size, height: size)
            .background(colour.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

/// quiet separation from the canvas; content remains opaque and readable
struct HomeSurface: ViewModifier {
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content.background(HomeStyle.card, in: RoundedRectangle(cornerRadius: radius))
    }
}

/// the secondary pages reachable from the first screen
enum HomeRoute: Hashable {
    case history, options, privacy, coach
    case account, lastWorkout, posture, weights, awards, plus
}

extension ExerciseKind {
    /// the name on the exercise chips, as short as it can be
    nonisolated var chipName: String {
        switch self {
        case .bodyweightSquat: String(localized: "Squat")
        case .pushUp: String(localized: "Push-up")
        case .staticLunge: String(localized: "Lunge")
        case .stiffLegDeadlift: String(localized: "Deadlift")
        case .pullUp: String(localized: "Pull-up")
        case .muscleUp: String(localized: "Muscle-up")
        }
    }
}

/// one chip per exercise. The selected one is filled; VoiceOver reads the full exercise name. At
/// accessibility text sizes the chips become one menu, which never runs off the screen
struct ExerciseChips: View {
    @Binding var selection: ExerciseKind
    /// the order of the chips: the exercises picked at the first launch come first
    var order: [ExerciseKind] = ExerciseKind.allCases
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                Picker("Exercise", selection: $selection.animation(reduceMotion ? nil : HomeStyle.spring)) {
                    ForEach(order, id: \.self) { kind in
                        Text(kind.definition.copy.name).tag(kind)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.definition.copy.name)
                        .font(.headline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .foregroundStyle(Color.primary)
                .background(HomeStyle.card, in: Capsule())
            }
            .accessibilityLabel("Exercise: \(selection.definition.copy.name)")
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(order, id: \.self) { kind in
                            chip(kind).id(kind)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // the chosen exercise is kept across launches: bring its chip into view
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: selection) { _, kind in
                    withAnimation(reduceMotion ? nil : HomeStyle.spring) { proxy.scrollTo(kind, anchor: .center) }
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }

    private func chip(_ kind: ExerciseKind) -> some View {
        let selected = kind == selection
        return Button {
            withAnimation(reduceMotion ? nil : HomeStyle.spring) { selection = kind }
        } label: {
            Text(kind.chipName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? HomeStyle.onAccent : Color.primary)
                .background(selected ? HomeStyle.accent : HomeStyle.card, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(kind.definition.copy.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("exercise.\(kind.rawValue)")
    }
}

/// the dark card at the top of the first screen: the chosen exercise drawn as Finn's camera sees
/// it, its name, and where to put the phone
struct ExerciseHeroCard: View {
    let kind: ExerciseKind
    /// shorter once there is a last session to show below it
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let copy = kind.definition.copy
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.name)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Label(kind.definition.expectedView == .side ? "Side view" : "Side, front or back",
                  systemImage: "camera.viewfinder")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPageStyle.tint)
                .accessibilityLabel(kind.definition.expectedView == .side ? "Filmed from the side"
                                    : "Filmed from the side, the front or the back")
            ExerciseFigureView(kind: kind, lineColour: Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: typeSize.isAccessibilitySize ? 160 : (compact ? 170 : 220))
                .padding(.vertical, 4)
                .id(kind)
                .transition(.opacity)
            Text("\(copy.placementDetail) \(copy.stanceTitle).")
                .font(.subheadline)
                .foregroundStyle(AppPageStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(AppSurface())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.exercise")
    }
}

/// a light card on the grouped background, for the focus, the last session and status lines
struct HomeCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// the one filled action of a screen: a full-width pill with its arrow in a circle of its own
struct PrimaryActionLabel: View {
    let title: LocalizedStringResource
    var symbol = "arrow.right"
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = typeSize.isAccessibilitySize
            ? AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous)) : AnyShape(Capsule())
        HStack(spacing: 12) {
            WrappingText(text: String(localized: title), style: .headline, colour: .black)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.black)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(minHeight: 54)
        .foregroundStyle(.black)
        .background(AppPageStyle.action, in: shape)
        .contentShape(shape)
        .accessibilityLabel(Text(title))
    }
}

/// presses in slightly, like a physical key
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// whether iOS has yet to ask for the camera, so Finn can say what the camera is for first
enum CameraPermission {
    static var notAskedYet: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined }
}

/// shown once, before iOS asks for the camera: what Finn does with it, in three lines
struct CameraPrimer: View {
    let onContinue: () -> Void
    let onPrivacy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    WrappingText(text: String(localized: "What the camera does"), style: .title2, weight: .bold)
                        .accessibilityAddTraits(.isHeader)
                    primerRow("figure.strengthtraining.functional", "Counts your reps",
                              "Finn follows one person from the side and ignores anyone else in view.")
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
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 24))
                layout {
                    Button { dismiss() } label: {
                        WrappingText(text: String(localized: "Not now"), style: .subheadline, weight: .medium,
                                     colour: .label.withAlphaComponent(0.72), alignment: .center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityLabel("Not now")
                    Button(action: onPrivacy) {
                        WrappingText(text: String(localized: "Privacy details"), style: .subheadline, weight: .medium,
                                     colour: .label.withAlphaComponent(0.72), alignment: .center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                        .accessibilityLabel("Privacy details")
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
        .tint(HomeStyle.accent)
    }

    private func primerRow(_ symbol: String, _ title: LocalizedStringResource, _ detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                WrappingText(text: String(localized: title), style: .headline)
                WrappingText(text: String(localized: detail), style: .subheadline, colour: .label.withAlphaComponent(0.8))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// a group of settings on its own rounded card, as on the first screen
    func optionCard() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(HomeSurface())
    }
}
