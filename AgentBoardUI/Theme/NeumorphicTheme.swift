import SwiftUI

public enum NeuPalette {
    public static let background = Color(red: 0.102, green: 0.110, blue: 0.122)
    public static let surface = Color(red: 0.137, green: 0.149, blue: 0.161)
    public static let surfaceRaised = Color(red: 0.169, green: 0.180, blue: 0.196)
    public static let surfaceHover = Color(red: 0.208, green: 0.227, blue: 0.247)
    public static let inset = Color(red: 0.086, green: 0.094, blue: 0.102)

    public static let accentOrange = Color(red: 0.961, green: 0.647, blue: 0.141)
    public static let accentCyan = Color(red: 0.788, green: 0.478, blue: 0.243)
    public static let accentCyanBright = Color(red: 0.910, green: 0.647, blue: 0.455)
    public static let accentCoral = Color(red: 1.000, green: 0.420, blue: 0.329)
    public static let accentPurple = Color(red: 0.541, green: 0.502, blue: 0.537)
    public static let statusBlue = Color(red: 0.722, green: 0.722, blue: 0.722)
    public static let statusClosed = Color(red: 0.541, green: 0.502, blue: 0.537)
    public static let accentForeground = Color(red: 0.165, green: 0.086, blue: 0.024)

    public static let textPrimary = Color(red: 0.945, green: 0.949, blue: 0.957)
    public static let textSecondary = Color(red: 0.765, green: 0.773, blue: 0.788)
    public static let textTertiary = Color(red: 0.502, green: 0.518, blue: 0.541)
    public static let textDisabled = Color(red: 0.329, green: 0.345, blue: 0.365)
    public static let borderSoft = Color.white.opacity(0.04)
    public static let border = Color.white.opacity(0.07)
    public static let borderStrong = Color.white.opacity(0.12)

    public static let shadowDark = Color.black.opacity(0.62)
    public static let shadowLight = Color.white.opacity(0.045)
}

public struct NeuBackground: View {
    public init() {}
    public var body: some View {
        ZStack {
            NeuPalette.background
            LinearGradient(
                colors: [
                    Color(red: 0.180, green: 0.196, blue: 0.212).opacity(0.90),
                    NeuPalette.background.opacity(0.98),
                    Color(red: 0.075, green: 0.082, blue: 0.090).opacity(0.90)
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
