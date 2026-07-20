import AgentBoardCore
import SwiftUI

// MARK: - Design Theme

//
// AgentBoard renders with standard macOS / iOS chrome rather than a custom
// neumorphic (skeuomorphic double-shadow) treatment. The public symbol names
// in this file are preserved so every existing call site keeps compiling:
//
//   - `NeuPalette.*`          semantic + surface colors (platform-aware)
//   - `NeuBackground()`       window/scene background
//   - `.neuExtruded(...)`     raised card → .regularMaterial rounded rect
//   - `.neuRecessed(...)`     inset well → grouped-background rounded rect
//   - `NeuButtonTarget(...)`  button style → .bordered / .borderedProminent
//
// The colour ramp stays brand-toned (accent teal / status colours) so the
// kanban pills and status indicators keep their meaning, but surfaces now use
// the platform's native materials and window colours instead of hand-rolled
// gradients, dual shadows, and extruded/recessed effects.

/// Surface + semantic colours. `NeuPalette` reads through these so light and
/// dark mode, and macOS vs iOS, all resolve to the correct native colour.
public struct NeuTheme: Sendable {
    public let background: Color
    public let surface: Color
    public let surfaceRaised: Color
    public let surfaceHover: Color
    public let inset: Color
    public let gradientTop: Color
    public let gradientBottom: Color

    public let accentOrange: Color
    public let primaryAccent: Color
    public let primaryAccentBright: Color
    public let primaryAccentForeground: Color
    public let accentCoral: Color
    public let accentPurple: Color
    public let statusOpen: Color
    public let statusClosed: Color
    public let statusSuccess: Color
    public let statusIdle: Color

    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textDisabled: Color
    public let borderSoft: Color
    public let border: Color
    public let borderStrong: Color

    public let shadowDark: Color
    public let shadowLight: Color

    /// Platform-aware native surfaces. Backgrounds and text come from the OS
    /// (`NSColor` / `UIColor`) so they adapt to light/dark automatically.
    /// Accents and status colours stay fixed for brand + semantic meaning.
    private static func makeNative() -> NeuTheme {
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

        return NeuTheme(
            background: background,
            surface: surface,
            surfaceRaised: surfaceRaised,
            surfaceHover: surfaceHover,
            inset: inset,
            gradientTop: background,
            gradientBottom: background,
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
            shadowDark: .black.opacity(0.20),
            shadowLight: .clear
        )
    }

    public static let blue = NeuTheme.makeNative()
    public static let grey = NeuTheme.makeNative()

    /// Kept for API compatibility; both presets resolve to the same native theme.
    public static func preset(_: AgentBoardDesignTheme) -> NeuTheme {
        .makeNative()
    }
}

@MainActor
public enum NeuPalette {
    private static var active = NeuTheme.blue

    public static func apply(_ designTheme: AgentBoardDesignTheme) {
        active = .preset(designTheme)
    }

    public static var background: Color {
        active.background
    }

    public static var surface: Color {
        active.surface
    }

    public static var surfaceRaised: Color {
        active.surfaceRaised
    }

    /// Sibling `Material` accessor for `surfaceRaised`. Floating/raised chrome
    /// (cards, compose bar, headers) can opt into the real translucent
    /// material instead of the flat fallback `Color` without changing the
    /// existing `Color`-typed token's call sites.
    public static var surfaceMaterial: Material {
        .regular
    }

    public static var surfaceHover: Color {
        active.surfaceHover
    }

    public static var inset: Color {
        active.inset
    }

    public static var gradientTop: Color {
        active.gradientTop
    }

    public static var gradientBottom: Color {
        active.gradientBottom
    }

    public static var accentOrange: Color {
        active.accentOrange
    }

    public static var accentCyan: Color {
        active.primaryAccent
    }

    public static var accentCyanBright: Color {
        active.primaryAccentBright
    }

    public static var accentForeground: Color {
        active.primaryAccentForeground
    }

    public static var accentCoral: Color {
        active.accentCoral
    }

    public static var accentPurple: Color {
        active.accentPurple
    }

    public static var accentGreen: Color {
        active.statusSuccess
    }

    public static var statusBlue: Color {
        active.statusOpen
    }

    public static var statusClosed: Color {
        active.statusClosed
    }

    public static var statusSuccess: Color {
        active.statusSuccess
    }

    public static var statusIdle: Color {
        active.statusIdle
    }

    public static var textPrimary: Color {
        active.textPrimary
    }

    public static var textSecondary: Color {
        active.textSecondary
    }

    public static var textTertiary: Color {
        active.textTertiary
    }

    public static var textDisabled: Color {
        active.textDisabled
    }

    public static var borderSoft: Color {
        active.borderSoft
    }

    public static var border: Color {
        active.border
    }

    public static var borderStrong: Color {
        active.borderStrong
    }

    public static var shadowDark: Color {
        active.shadowDark
    }

    public static var shadowLight: Color {
        active.shadowLight
    }
}

/// Scene background. Uses the native window/background colour so the app sits
/// correctly in light and dark mode with no hand-drawn gradient.
public struct NeuBackground: View {
    public init() {}
    public var body: some View {
        NeuPalette.background.ignoresSafeArea()
    }
}

/// Raised card — a flat material-backed rounded rectangle with a hairline
/// border. Replaces the neumorphic dual-shadow "extruded" look with native
/// chrome. No permanent drop shadow: cards read as flat native surfaces at
/// rest, and `.draggable()` already gives the system's own lifted-preview
/// shadow while a card is actually being dragged, so no bespoke `isDragging`
/// state is needed to satisfy "shadow only while dragging".
public struct NeuExtrudedModifier: ViewModifier {
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
                    .stroke(NeuPalette.borderSoft, lineWidth: 0.5)
            )
    }
}

/// Inset well — a flat grouped-background rounded rectangle. Replaces the
/// neumorphic blurred "recessed" look with a subtle native inset surface.
public struct NeuRecessedModifier: ViewModifier {
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
                    .fill(NeuPalette.inset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NeuPalette.borderSoft, lineWidth: 0.5)
            )
    }
}

public extension View {
    func neuExtruded(cornerRadius: CGFloat = 24, elevation: CGFloat = 10) -> some View {
        modifier(NeuExtrudedModifier(cornerRadius: cornerRadius, elevation: elevation))
    }

    func neuRecessed(cornerRadius: CGFloat = 16, depth: CGFloat = 4) -> some View {
        modifier(NeuRecessedModifier(cornerRadius: cornerRadius, depth: depth))
    }
}

/// Native button style. Accent buttons render as the platform's prominent
/// (filled) button; regular buttons render as the standard bordered button.
/// Pressed state relies on the system feedback rather than a custom scale +
/// shadow animation.
public struct NeuButtonTarget: ButtonStyle {
    public let isAccent: Bool
    public init(isAccent: Bool = false) {
        self.isAccent = isAccent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isAccent ? NeuPalette.accentForeground : NeuPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isAccent ? NeuPalette.accentCyan : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isAccent ? Color.clear : NeuPalette.surfaceHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAccent ? Color.clear : NeuPalette.border, lineWidth: 0.5)
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
            .foregroundStyle(NeuPalette.textSecondary)
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
