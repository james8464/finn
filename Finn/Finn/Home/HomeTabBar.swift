import SwiftUI

struct HomeBackdrop: View {
    var body: some View {
        GeometryReader { _ in
            Color(white: 0.035)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum HomeAccessibilityDiagnostics {
    static var opaqueSurface: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-finn-ui-opaque-surface")
        #else
        false
        #endif
    }
}

struct DashboardGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 15
    var stableBackdrop = false
    var showsBorder = true

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                if stableBackdrop || reduceTransparency || HomeAccessibilityDiagnostics.opaqueSurface {
                    shape.fill(Color(white: 0.09)).accessibilityHidden(true)
                } else {
                    shape.fill(.ultraThinMaterial).opacity(0.8).environment(\.colorScheme, .dark).accessibilityHidden(true)
                    shape.fill(.black.opacity(0.16)).accessibilityHidden(true)
                }
            }
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.13)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .accessibilityHidden(true)
                }
            }
    }
}

struct HomeTabBar: View {
    @Binding var selection: HomeTab
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AppMotion.reduces(systemReduceMotion) }
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    // caption2 plateaus at smaller sizes. Body scaling preserves 11pt at default
    // while responding at every content size; the original normal-size layout is unchanged
    @ScaledMetric(relativeTo: .body) private var labelSize = 11.0
    @ScaledMetric(relativeTo: .body) private var tabHeight = 64.0
    @Namespace private var glassSelection

    var body: some View {
        tabs
            .background {
                GlassEffectContainer(spacing: 0) {
                    LazyVGrid(columns: tabColumns, spacing: 0) {
                        ForEach(HomeTab.allCases, id: \.self) { tab in
                            Color.clear
                                .overlay {
                                    if selection == tab { selectionCapsule }
                                }
                                .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? min(tabHeight, 88) : 64)
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        .padding(4)
        // stable charcoal surfaces retain the glass outline without variable contrast
        // beneath small labels. The selection still moves between tabs.
        .modifier(DashboardGlass(radius: 48, stableBackdrop: true))
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .accessibilityIdentifier("home.tabBar")
    }

    private var tabColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: typeSize.isAccessibilitySize ? 2 : 4)
    }

    private var tabs: some View {
        LazyVGrid(columns: tabColumns, spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    // animate only the bar. Changing pages should respond immediately.
                    selection = tab
                } label: {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(HStackLayout(spacing: 8))
                        : AnyLayout(VStackLayout(spacing: 4))
                    layout {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 24, weight: tab == .home ? .semibold : .regular))
                            .overlay(alignment: .topTrailing) {
                                if tab == .coach {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11, weight: .medium))
                                        .offset(x: 9, y: -5)
                                }
                            }
                            .frame(height: 28)
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey(tab.rawValue))
                            .font(.system(size: labelSize, weight: selection == tab ? .medium : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(selection == tab
                                     ? DashboardStyle.accent
                                     : DashboardStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? min(tabHeight, 88) - 2 : 62)
                    .padding(.vertical, 1)
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier(tab.identifier)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var selectionCapsule: some View {
        if reduceTransparency || HomeAccessibilityDiagnostics.opaqueSurface {
            Capsule().fill(Color(white: 0.04))
                .matchedGeometryEffect(id: "selection", in: glassSelection)
        } else {
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1)
                }
                .matchedGeometryEffect(id: "selection", in: glassSelection)
        }
    }
}
