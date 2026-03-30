#if os(macOS)
    import AppKit
#else
    import UIKit
#endif
import SwiftUI

enum AppTheme {
    static let sidebarBackground = Color(red: 0.173, green: 0.173, blue: 0.18)
    static let sidebarMutedText = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let sidebarPrimaryText = Color(red: 0.878, green: 0.878, blue: 0.878)

    static let appBackground = dynamicColor(
        lightR: 0.961, lightG: 0.961, lightB: 0.941,
        darkR: 0.11, darkG: 0.11, darkB: 0.12
    )
    static let panelBackground = dynamicColor(
        lightR: 0.98, lightG: 0.98, lightB: 0.965,
        darkR: 0.13, darkG: 0.13, darkB: 0.14
    )
    static let cardBackground = dynamicColor(
        lightR: 1.0, lightG: 1.0, lightB: 1.0,
        darkR: 0.173, darkG: 0.173, darkB: 0.18
    )
    static let subtleBorder = dynamicColor(
        lightR: 0.886, lightG: 0.878, lightB: 0.847,
        darkR: 0.3, darkG: 0.3, darkB: 0.32
    )
    static let mutedText = dynamicColor(
        lightR: 0.35, lightG: 0.35, lightB: 0.38,
        darkR: 0.72, darkG: 0.72, darkB: 0.75
    )

    static func sessionColor(for status: SessionStatus) -> Color {
        switch status {
        case .running:
            return Color(red: 0.204, green: 0.78, blue: 0.349)
        case .idle:
            return Color(red: 0.91, green: 0.663, blue: 0)
        case .stopped:
            return Color(red: 0.557, green: 0.557, blue: 0.576)
        case .error:
            return Color(red: 1.0, green: 0.231, blue: 0.188)
        }
    }

    /// ViewModifier for the standard card appearance (background + border).
    struct CardStyle: ViewModifier {
        var cornerRadius: CGFloat = 10

        func body(content: Content) -> some View {
            content
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func dynamicColor(
        lightR: Double, lightG: Double, lightB: Double,
        darkR: Double, darkG: Double, darkB: Double
    ) -> Color {
        #if os(macOS)
            let nsColor = NSColor(name: nil) { appearance in
                let best = appearance.bestMatch(from: [.darkAqua, .aqua])
                return best == .darkAqua
                    ? NSColor(red: darkR, green: darkG, blue: darkB, alpha: 1)
                    : NSColor(red: lightR, green: lightG, blue: lightB, alpha: 1)
            }
            return Color(nsColor: nsColor)
        #else
            let uiColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: darkR, green: darkG, blue: darkB, alpha: 1)
                    : UIColor(red: lightR, green: lightG, blue: lightB, alpha: 1)
            }
            return Color(uiColor: uiColor)
        #endif
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 10) -> some View {
        modifier(AppTheme.CardStyle(cornerRadius: cornerRadius))
    }
}
