import AgentBoardCore
import SwiftUI

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

    public static let blue = NeuTheme(
        background: Color(red: 0.043, green: 0.059, blue: 0.090),
        surface: Color(red: 0.067, green: 0.086, blue: 0.122),
        surfaceRaised: Color(red: 0.086, green: 0.110, blue: 0.153),
        surfaceHover: Color(red: 0.110, green: 0.137, blue: 0.188),
        inset: Color(red: 0.039, green: 0.055, blue: 0.082),
        gradientTop: Color(red: 0.075, green: 0.102, blue: 0.149),
        gradientBottom: Color(red: 0.043, green: 0.059, blue: 0.090),
        accentOrange: Color(red: 0.961, green: 0.647, blue: 0.141),
        primaryAccent: Color(red: 0.106, green: 0.749, blue: 0.651),
        primaryAccentBright: Color(red: 0.310, green: 0.851, blue: 0.773),
        primaryAccentForeground: Color(red: 0.043, green: 0.059, blue: 0.090),
        accentCoral: Color(red: 1.000, green: 0.420, blue: 0.329),
        accentPurple: Color(red: 0.690, green: 0.486, blue: 1.000),
        statusOpen: Color(red: 0.306, green: 0.639, blue: 1.000),
        statusClosed: Color(red: 0.494, green: 0.522, blue: 0.584),
        statusSuccess: Color.green,
        statusIdle: Color.blue,
        textPrimary: Color(red: 0.957, green: 0.965, blue: 0.980),
        textSecondary: Color(red: 0.761, green: 0.784, blue: 0.831),
        textTertiary: Color(red: 0.494, green: 0.522, blue: 0.584),
        textDisabled: Color(red: 0.322, green: 0.345, blue: 0.400),
        borderSoft: Color.white.opacity(0.04),
        border: Color.white.opacity(0.07),
        borderStrong: Color.white.opacity(0.12),
        shadowDark: Color.black.opacity(0.50),
        shadowLight: Color.white.opacity(0.025)
    )

    public static let grey = NeuTheme(
        background: Color(red: 0.102, green: 0.110, blue: 0.122),
        surface: Color(red: 0.137, green: 0.149, blue: 0.161),
        surfaceRaised: Color(red: 0.169, green: 0.180, blue: 0.196),
        surfaceHover: Color(red: 0.208, green: 0.227, blue: 0.247),
        inset: Color(red: 0.086, green: 0.094, blue: 0.102),
        gradientTop: Color(red: 0.180, green: 0.196, blue: 0.212),
        gradientBottom: Color(red: 0.075, green: 0.082, blue: 0.090),
        accentOrange: Color(red: 0.961, green: 0.647, blue: 0.141),
        primaryAccent: Color(red: 0.788, green: 0.478, blue: 0.243),
        primaryAccentBright: Color(red: 0.910, green: 0.647, blue: 0.455),
        primaryAccentForeground: Color(red: 0.165, green: 0.086, blue: 0.024),
        accentCoral: Color(red: 1.000, green: 0.420, blue: 0.329),
        accentPurple: Color(red: 0.541, green: 0.502, blue: 0.537),
        statusOpen: Color(red: 0.722, green: 0.722, blue: 0.722),
        statusClosed: Color(red: 0.541, green: 0.502, blue: 0.537),
        statusSuccess: Color(red: 0.910, green: 0.647, blue: 0.455),
        statusIdle: Color(red: 0.765, green: 0.773, blue: 0.788),
        textPrimary: Color(red: 0.945, green: 0.949, blue: 0.957),
        textSecondary: Color(red: 0.765, green: 0.773, blue: 0.788),
        textTertiary: Color(red: 0.502, green: 0.518, blue: 0.541),
        textDisabled: Color(red: 0.329, green: 0.345, blue: 0.365),
        borderSoft: Color.white.opacity(0.04),
        border: Color.white.opacity(0.07),
        borderStrong: Color.white.opacity(0.12),
        shadowDark: Color.black.opacity(0.62),
        shadowLight: Color.white.opacity(0.045)
    )

    public static func preset(_ designTheme: AgentBoardDesignTheme) -> NeuTheme {
        switch designTheme {
        case .blue: .blue
        case .grey: .grey
        }
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

public struct NeuBackground: View {
    public init() {}
    public var body: some View {
        ZStack {
            NeuPalette.background
            LinearGradient(
                colors: [
                    NeuPalette.gradientTop.opacity(0.90),
                    NeuPalette.background.opacity(0.98),
                    NeuPalette.gradientBottom.opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

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
                    .fill(NeuPalette.surfaceRaised)
                    .shadow(
                        color: NeuPalette.shadowDark,
                        radius: elevation * 1.4,
                        x: elevation * 0.45,
                        y: elevation * 0.75
                    )
                    .shadow(
                        color: NeuPalette.shadowLight,
                        radius: elevation * 0.7,
                        x: -elevation * 0.25,
                        y: -elevation * 0.25
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

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
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.3), lineWidth: depth)
                            .blur(radius: depth)
                            .offset(x: depth * 0.5, y: depth * 0.5)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: depth)
                            .blur(radius: depth)
                            .offset(x: -depth * 0.5, y: -depth * 0.5)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
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
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isAccent ? NeuPalette.accentCyan : NeuPalette.surfaceRaised)
                    .shadow(
                        color: configuration.isPressed ? .clear : NeuPalette.shadowDark,
                        radius: configuration.isPressed ? 0 : 8,
                        x: configuration.isPressed ? 0 : 4,
                        y: configuration.isPressed ? 0 : 6
                    )
                    .shadow(
                        color: configuration.isPressed ? .clear : NeuPalette.shadowLight,
                        radius: configuration.isPressed ? 0 : 8,
                        x: configuration.isPressed ? 0 : -2,
                        y: configuration.isPressed ? 0 : -2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AgentBoardEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(NeuPalette.accentCyanBright)
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
        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .overlay(
            Capsule()
                .stroke(color.opacity(0.32), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
