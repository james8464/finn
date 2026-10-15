import AVFoundation
import SwiftUI

/// colours of the first screen. Plumb stays black and white: the dark camera card carries the screen,
/// not an accent colour.
enum HomeStyle {
    static let background = Color(uiColor: .systemBackground)
    static let card = Color(uiColor: .secondarySystemBackground)
    static let supportingText = Color.primary.opacity(0.72)
    /// the camera card is dark in both appearances, like the camera view it stands for.
    static let cameraTop = Color(white: 0.11)
    static let cameraBottom = Color(white: 0.05)
    /// supporting text on the camera card, solid so its contrast does not depend on what is behind.
    static let cameraSecondaryText = Color(white: 0.8)
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)
}

/// the secondary pages reachable from the first screen.
enum HomeRoute: Hashable {
    case history, options, privacy, coach
    case account, lastWorkout, posture, weights, awards, plus
}

extension ExerciseKind {
    /// the name on the exercise chips, as short as it can be.
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
}

/// one chip per exercise. The selected one is filled; VoiceOver reads the full exercise name. At
/// accessibility text sizes the chips become one menu, which never runs off the screen.
struct ExerciseChips: View {
    @Binding var selection: ExerciseKind
    /// the order of the chips: the exercises picked at the first launch come first.
    var order: [ExerciseKind] = ExerciseKind.allCases
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                Picker("Exercise", selection: $selection.animation(HomeStyle.spring)) {
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
                                // the chosen exercise is kept across launches: bring its chip into view.
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: selection) { _, kind in
                    withAnimation(HomeStyle.spring) { proxy.scrollTo(kind, anchor: .center) }
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }

    private func chip(_ kind: ExerciseKind) -> some View {
        let selected = kind == selection
        return Button {
            withAnimation(HomeStyle.spring) { selection = kind }
        } label: {
            Text(kind.chipName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .background(selected ? Color.primary : HomeStyle.card, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(kind.definition.copy.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("exercise.\(kind.rawValue)")
    }
}

/// the dark card at the top of the first screen: the chosen exercise drawn as Plumb's camera sees
/// it, its name, and where to put the phone.
struct ExerciseHeroCard: View {
    let kind: ExerciseKind
    /// shorter once there is a last session to show below it.
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var figureHeight: CGFloat = 340

    var body: some View {
        let copy = kind.definition.copy
        VStack(alignment: .leading, spacing: 0) {
            Label(kind.definition.expectedView == .side ? "Side view" : "Side, front or back",
                  systemImage: "camera.viewfinder")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.12), in: Capsule())
                .accessibilityLabel(kind.definition.expectedView == .side ? "Filmed from the side"
                                    : "Filmed from the side, the front or the back")
            ExerciseFigureView(kind: kind)
                .frame(maxWidth: .infinity)
                .frame(height: min(compact ? figureHeight * 0.62 : figureHeight, 400))
                .padding(.vertical, 12)
                .id(kind)
                .transition(.blurReplace)
            Text(copy.name)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("\(copy.placementDetail) \(copy.stanceTitle).")
                .font(.subheadline)
                .foregroundStyle(HomeStyle.cameraSecondaryText)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [HomeStyle.cameraTop, HomeStyle.cameraBottom], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.exercise")
    }
}

/// a light card on the grouped background, for the focus, the last session and status lines.
struct HomeCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// the one filled action of a screen: a full-width pill with its arrow in a circle of its own.
struct PrimaryActionLabel: View {
    let title: LocalizedStringKey
    var symbol = "arrow.right"

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .systemBackground), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .foregroundStyle(Color(uiColor: .systemBackground))
        .background(Color.primary, in: Capsule())
        .contentShape(Capsule())
    }
}

/// presses in slightly, like a physical key.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// whether iOS has yet to ask for the camera, so Plumb can say what the camera is for first.
enum CameraPermission {
    static var notAskedYet: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined }
}

/// shown once, before iOS asks for the camera: what Plumb does with it, in three lines.
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

extension View {
    /// a group of settings on its own rounded card, as on the first screen.
    func optionCard() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
