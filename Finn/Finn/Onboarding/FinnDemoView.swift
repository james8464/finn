import SwiftUI

/// an isolated illustrated tour, available in release builds. It never opens the camera,
/// runs analysis, talks to accessories, or writes sample workouts to the person's history
struct FinnDemoView: View {
    let startWorkout: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAdvice = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IntroBrand()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close demo")
                .accessibilityIdentifier("demo.close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            ScrollView {
                DemoStoryPage(showsAdvice: showsAdvice)
                    .padding(24)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                    .id(showsAdvice)
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 10) {
                IntroAction(title: showsAdvice ? "Start a set" : "View set review") {
                    if showsAdvice {
                        startWorkout()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { showsAdvice = true }
                    }
                }
                .accessibilityIdentifier("demo.continue")
                if showsAdvice {
                    Button { showsAdvice = false } label: {
                        Text("Replay demo").font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .accessibilityIdentifier("demo.replay")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 540)
        }
        .foregroundStyle(.white)
        .background { IntroBackground() }
        .preferredColorScheme(.dark)
    }
}

struct DemoStoryPage: View {
    let showsAdvice: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            IntroHeading(eyebrow: showsAdvice ? "02 / REVIEW" : "01 / REPS",
                         title: showsAdvice ? "Set review" : "Rep counting")
            if !showsAdvice {
                DemoCameraCard(showsAdvice: false)
            }
            if showsAdvice {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    : AnyLayout(HStackLayout(spacing: 16))
                layout {
                    Image("DemoAthlete")
                        .resizable().scaledToFill()
                        .frame(width: 88, height: 112).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("6 squat reps").font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("00:18 · Example session").font(.caption)
                            .foregroundStyle(DashboardStyle.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Observation", systemImage: "text.bubble.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Your last two reps were shorter.").font(.title3.weight(.semibold))
                    Text("Try slowing down and matching the depth of your first reps on the next set.")
                        .font(.subheadline).foregroundStyle(DashboardStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(DashboardStyle.accent.opacity(0.4), lineWidth: 1))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("demo.advice")
            }
            Text("Illustrated demo · sample reps and advice")
                .font(.caption).foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(showsAdvice ? "demo.result" : "demo.capture")
    }
}

/// the same framing, count and set status as the camera UI, with an explicitly synthetic athlete
struct DemoCameraCard: View {
    let showsAdvice: Bool
    var welcome = false
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 48.0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("DemoAthlete")
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .accessibilityHidden(true)
            LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0),
                                   .init(color: .clear, location: 0.30),
                                   .init(color: .clear, location: 0.63),
                                   .init(color: .black.opacity(0.88), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Squat").font(.headline)
                        Text(showsAdvice ? "Set reviewed" : "Side view")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Text("DEMO").font(.caption2.bold()).tracking(1)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .foregroundStyle(.black)
                        .background(DashboardStyle.accent, in: Capsule())
                }
                Spacer()
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .bottom))
                layout {
                    if welcome {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("A coach in your corner.").font(.title3.bold())
                            Text("Right on your iPhone.").font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("6").font(.system(size: countSize, weight: .bold, design: .rounded))
                            Text("reps").font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        Label(showsAdvice ? "Reviewed" : "00:18", systemImage: showsAdvice ? "checkmark.circle" : "timer")
                            .font(.caption.weight(.medium)).monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10).background(.black.opacity(0.5), in: Capsule())
                    }
                }
            }
            .padding(20)
            if !welcome {
                // frame corners echo the production capture screen. They are decorative, not pose data.
                DemoFrameCorners()
                    .stroke(DashboardStyle.accent.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(.horizontal, 25).padding(.top, 70).padding(.bottom, 90)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? 480 : welcome ? 300 : showsAdvice ? 260 : 350)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.17), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(welcome
            ? "Illustrated demo: a man doing a squat in a gym."
            : "Illustrated demo of Finn’s camera screen. A man doing a squat. Six sample reps. \(showsAdvice ? "Set reviewed." : "Eighteen seconds.")")
        .accessibilityAddTraits(.isImage)
    }
}

private struct DemoFrameCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 16
        for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0),
                               (rect.maxX, rect.minY, -1.0, 1.0),
                               (rect.minX, rect.maxY, 1.0, -1.0),
                               (rect.maxX, rect.maxY, -1.0, -1.0)] {
            path.move(to: CGPoint(x: x + dx * length, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * length))
        }
        return path
    }
}
