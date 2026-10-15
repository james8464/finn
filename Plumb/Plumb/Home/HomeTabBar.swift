import SwiftUI

/// Théophile's original artwork, softened behind the monochrome content.
struct HomeBackdrop: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { proxy in
      Image("HomeBackdrop")
        .resizable()
        .scaledToFill()
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
        .saturation(0)
        .overlay(HomeStyle.background.opacity(colorScheme == .dark ? 0.62 : 0.84))
        .overlay(alignment: .bottom) {
          LinearGradient(
            colors: [.clear, HomeStyle.background], startPoint: .top, endPoint: .bottom
          )
          .frame(height: 160)
        }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

/// Restores Théophile's tab composition while TabView keeps each navigation stack alive.
struct HomeTabBar: View {
  @Binding var selection: HomeTab
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .caption2) private var itemHeight = 62.0
  @ScaledMetric(relativeTo: .caption2) private var iconSize = 24.0
  @Namespace private var selectedShape

  var body: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 2 : 4),
      spacing: 4
    ) {
      ForEach(HomeTab.allCases, id: \.self) { tabButton($0) }
    }
    .padding(5)
    .background {
      if reduceTransparency {
        shell.fill(Color(white: 0.08))
      } else {
        shell.fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
        shell.fill(.black.opacity(0.55))
      }
    }
    .overlay(shell.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12), value: selection)
    .sensoryFeedback(.selection, trigger: selection)
    .padding(.horizontal, 16)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("home.tabBar")
  }

  private var shell: RoundedRectangle {
    RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 28 : 50)
  }

  private func tabButton(_ tab: HomeTab) -> some View {
    Button {
      selection = tab
    } label: {
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(HStackLayout(spacing: 8))
        : AnyLayout(VStackLayout(spacing: 4))
      layout {
        Image(systemName: tab.symbol)
          .font(.system(size: min(iconSize, 32), weight: tab == .home ? .semibold : .regular))
          .overlay(alignment: .topTrailing) {
            if tab == .coach {
              Image(systemName: "sparkles")
                .font(.system(size: min(iconSize * 11 / 24, 14), weight: .medium))
                .offset(x: 9, y: -5)
            }
          }
          .frame(minHeight: 28)
          .accessibilityHidden(true)
        Text(LocalizedStringKey(tab.rawValue))
          .font(.caption2.weight(selection == tab ? .semibold : .regular))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(selection == tab ? HomeStyle.lime : Color.white)
      .frame(maxWidth: .infinity, minHeight: min(itemHeight, 88))
      .background {
        if selection == tab {
          Capsule().fill(.white.opacity(0.1))
            .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
            .matchedGeometryEffect(id: "selected", in: selectedShape)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(PressableStyle())
    .accessibilityIdentifier(tab.identifier)
    .accessibilityAddTraits(selection == tab ? .isSelected : [])
  }
}
