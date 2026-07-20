import SwiftUI

// MARK: - Design Theme

//
// AgentBoard renders with standard macOS / iOS chrome rather than a custom
// neumorphic (skeuomorphic double-shadow) treatment. Semantic names below:
//
//   - `AppTheme.*`               semantic + surface colors (platform-aware)
//   - `AppBackground()`          window/scene background
//   - `.cardSurface(...)`        raised card → .regularMaterial rounded rect
//   - `.insetSurface(...)`       inset well → grouped-background rounded rect
//   - `AppButtonStyle(...)`      button style → .bordered / .borderedProminent
//
// The colour ramp stays brand-toned (accent teal / status colours) so the
// kanban pills and status indicators keep their meaning, but surfaces now use
// the platform's native materials and window colours instead of hand-rolled
// gradients, dual shadows, and extruded/recessed effects.

/// Surface + semantic colours. `AppTheme` reads through these so light and
/// dark mode, and macOS vs iOS, all resolve to the correct native colour.
private struct AppThemeTokens: Sendable {
    let background: Color
    let surface: Color
    let surfaceRaised: Color
    let surfaceHover: Color
    let inset: Color

    let accentOrange: Color
    let primaryAccent: Color
    let primaryAccentBright: Color
    let primaryAccentForeground: Color
    let accentCoral: Color
    let accentPurple: Color
    let statusOpen: Color
    let statusClosed: Color
    let statusSuccess: Color
    let statusIdle: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textDisabled: Color
    let borderSoft: Color
    let border: Color
    let borderStrong: Color

    let shadowDark: Color

    /// Platform-aware native surfaces. Backgrounds and text come from the OS
    /// (`NSColor` / `UIColor`) so they adapt to light/dark automatically.
    /// Accents and status colours stay fixed for brand + semantic meaning.
    static func makeNative() -> AppThemeTokens {
        #if os(macOS)
            let background = Color(nsColor: .windowBackgroundColor)
            let surface = Color(nsColor: .controlBackgroundColor)
            let surfaceRaised = Color(nsColor: .controlBackgroundColor)
            let surfaceHover = Color(nsColor: .quaternaryLabelColor).opacity(0.35)
            let inset = Color(nsColor: .underPageBackgroundColor)
            let textPrimary = Color(nsColor: .labelColor)
            let textSecondary = Color(nsColor: .secondaryLabelColor)
            let textTertiary = Color(nsColor: .tertiaryLabelColor)
            let textDisabled = Color(nsColor: .quaternaryLabelColor)
            let border = Color(nsColor: .separatorColor)
        #else
            let background = Color(uiColor: .systemBackground)
            let surface = Color(uiColor: .secondarySystemBackground)
            let surfaceRaised = Color(uiColor: .secondarySystemBackground)
            let surfaceHover = Color(uiColor: .tertiarySystemFill)
            let inset = Color(uiColor: .systemGroupedBackground)
            let textPrimary = Color(uiColor: .label)
            let textSecondary = Color(uiColor: .secondaryLabel)
            let textTertiary = Color(uiColor: .tertiaryLabel)
            let textDisabled = Color(uiColor: .quaternaryLabel)
            let border = Color(uiColor: .separator)
        #endif

        return AppThemeTokens(
            background: background,
            surface: surface,
            surfaceRaised: surfaceRaised,
            surfaceHover: surfaceHover,
            inset: inset,
            accentOrange: .orange,
            primaryAccent: .accentColor, // system accent (Assets AccentColor), not a bespoke brand color
            primaryAccentBright: .accentColor,
            primaryAccentForeground: .white, // justified: white text drawn on top of an accent-filled surface
            accentCoral: .red,
            accentPurple: .purple,
            statusOpen: .blue,
            statusClosed: .secondary,
            statusSuccess: .green,
            statusIdle: .blue,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            textDisabled: textDisabled,
            borderSoft: border.opacity(0.5),
            border: border,
            borderStrong: border.opacity(0.8),
            shadowDark: .black.opacity(0.20)
        )
    }
}

@MainActor
public enum AppTheme {
    private static let tokens = AppThemeTokens.makeNative()

    public static var background: Color {
        tokens.background
    }

    public static var surface: Color {
        tokens.surface
    }

    public static var surfaceRaised: Color {
        tokens.surfaceRaised
    }

    /// Sibling `Material` accessor for `surfaceRaised`. Floating/raised chrome
    /// (cards, compose bar, headers) can opt into the real translucent
    /// material instead of the flat fallback `Color` without changing the
    /// existing `Color`-typed token's call sites.
    public static var surfaceMaterial: Material {
        .regular
    }

    public static var surfaceHover: Color {
        tokens.surfaceHover
    }

    public static var inset: Color {
        tokens.inset
    }

    public static var accentOrange: Color {
        tokens.accentOrange
    }

    public static var accentCyan: Color {
        tokens.primaryAccent
    }

    public static var accentCyanBright: Color {
        tokens.primaryAccentBright
    }

    public static var accentForeground: Color {
        tokens.primaryAccentForeground
    }

    public static var accentCoral: Color {
        tokens.accentCoral
    }

    public static var accentPurple: Color {
        tokens.accentPurple
    }

    public static var accentGreen: Color {
        tokens.statusSuccess
    }

    public static var statusBlue: Color {
        tokens.statusOpen
    }

    public static var statusClosed: Color {
        tokens.statusClosed
    }

    public static var statusSuccess: Color {
        tokens.statusSuccess
    }

    public static var statusIdle: Color {
        tokens.statusIdle
    }

    public static var textPrimary: Color {
        tokens.textPrimary
    }

    public static var textSecondary: Color {
        tokens.textSecondary
    }

    public static var textTertiary: Color {
        tokens.textTertiary
    }

    public static var textDisabled: Color {
        tokens.textDisabled
    }

    public static var borderSoft: Color {
        tokens.borderSoft
    }

    public static var border: Color {
        tokens.border
    }

    public static var borderStrong: Color {
        tokens.borderStrong
    }

    public static var shadowDark: Color {
        tokens.shadowDark
    }
}

/// Scene background. Uses the native window/background colour so the app sits
/// correctly in light and dark mode with no hand-drawn gradient.
public struct AppBackground: View {
    public init() {}
    public var body: some View {
        AppTheme.background.ignoresSafeArea()
    }
}

/// Raised card — a flat material-backed rounded rectangle with a hairline
/// border. Replaces the neumorphic dual-shadow "extruded" look with native
/// chrome. No permanent drop shadow: cards read as flat native surfaces at
/// rest, and `.draggable()` already gives the system's own lifted-preview
/// shadow while a card is actually being dragged, so no bespoke `isDragging`
/// state is needed to satisfy "shadow only while dragging".
public struct CardSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let elevation: CGFloat

    public init(cornerRadius: CGFloat = 24, elevation: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.elevation = elevation
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.borderSoft, lineWidth: 0.5)
            )
    }
}

/// Inset well — a flat grouped-background rounded rectangle. Replaces the
/// neumorphic blurred "recessed" look with a subtle native inset surface.
public struct InsetSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let depth: CGFloat

    public init(cornerRadius: CGFloat = 16, depth: CGFloat = 4) {
        self.cornerRadius = cornerRadius
        self.depth = depth
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.inset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.borderSoft, lineWidth: 0.5)
            )
    }
}

public extension View {
    func cardSurface(cornerRadius: CGFloat = 24, elevation: CGFloat = 10) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius, elevation: elevation))
    }

    func insetSurface(cornerRadius: CGFloat = 16, depth: CGFloat = 4) -> some View {
        modifier(InsetSurfaceModifier(cornerRadius: cornerRadius, depth: depth))
    }
}

/// Native button style. Accent buttons render as the platform's prominent
/// (filled) button; regular buttons render as the standard bordered button.
/// Pressed state relies on the system feedback rather than a custom scale +
/// shadow animation.
public struct AppButtonStyle: ButtonStyle {
    public let isAccent: Bool
    public init(isAccent: Bool = false) {
        self.isAccent = isAccent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isAccent ? AppTheme.accentForeground : AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isAccent ? AppTheme.accentCyan : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isAccent ? Color.clear : AppTheme.surfaceHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAccent ? Color.clear : AppTheme.border, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct AgentBoardEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(AppTheme.textSecondary)
    }
}

struct AgentBoardPill: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            } else {
                Circle()
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}
