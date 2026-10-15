import SwiftUI

struct IntroBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("PlumbMark").resizable().scaledToFit().frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Plumb").font(.title3.weight(.bold))
                Text("Find your line.").font(.caption2).foregroundStyle(DashboardStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct IntroBackground: View {
    var body: some View {
        HomeBackdrop()
            .overlay(LinearGradient(colors: [.black.opacity(0.68), .black.opacity(0.78)],
                                    startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
    }
}

struct IntroHeading: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 39.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.caption2.weight(.semibold)).tracking(1.5)
                .foregroundStyle(DashboardStyle.accent)
            Text(title).font(.system(size: titleSize, weight: .bold)).tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(DashboardStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct IntroAction: View {
    let title: LocalizedStringKey
    var symbol = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title).font(.headline)
                Spacer(minLength: 0)
                Image(systemName: symbol).font(.headline).accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.black)
            .background(DashboardStyle.accent, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}
