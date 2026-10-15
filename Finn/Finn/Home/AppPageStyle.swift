import SwiftUI

/// Supporting pages use system surfaces; the Home dashboard keeps its own artwork and palette.
enum AppPageStyle {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let tint = Color(red: 1, green: 0.47, blue: 0.71)
    static let secondaryText = Color(uiColor: .label.withAlphaComponent(0.72))
    static let action = Color(red: 1, green: 45 / 255, blue: 146 / 255)
}

struct AppSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPageStyle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// The Debug launch option exercises the same branches as the system accessibility preference.
enum AppMotion {
    static func reduces(_ systemPreference: Bool) -> Bool {
        #if DEBUG
        systemPreference || ProcessInfo.processInfo.arguments.contains("-finn-ui-reduce-motion")
        #else
        systemPreference
        #endif
    }
}
