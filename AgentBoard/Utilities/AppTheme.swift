import AppKit
import SwiftUI

enum AppTheme {
    static let sidebarBackground = Color(nsColor: NSColor(
        red: 0.173,
        green: 0.173,
        blue: 0.18,
        alpha: 1
    ))
    static let sidebarMutedText = Color(
        nsColor: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
    )
    static let sidebarPrimaryText = Color(
        nsColor: NSColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1)
    )

    static let appBackground = dynamicColor(
        light: NSColor(red: 0.961, green: 0.961, blue: 0.941, alpha: 1),
        dark: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    )
    static let panelBackground = dynamicColor(
        light: NSColor(red: 0.98, green: 0.98, blue: 0.965, alpha: 1),
        dark: NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
    )
    static let cardBackground = dynamicColor(
        light: .white,
        dark: NSColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1)
    )
    static let subtleBorder = dynamicColor(
        light: NSColor(red: 0.886, green: 0.878, blue: 0.847, alpha: 1),
        dark: NSColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1)
    )
    static let mutedText = dynamicColor(
        light: NSColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1),
        dark: NSColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1)
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

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        let nsColor = NSColor(
            name: nil,
            dynamicProvider: { appearance in
                let best = appearance.bestMatch(from: [.darkAqua, .aqua])
                return best == .darkAqua ? dark : light
            }
        )
        return Color(nsColor: nsColor)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 10) -> some View {
        modifier(AppTheme.CardStyle(cornerRadius: cornerRadius))
    }
}
