import AgentBoardCore
import SwiftUI

public enum BoardPalette {
    public static let paper = Color.secondary
    public static let surface = Color.agentBoardSurface
    public static let gold = Color.orange
    public static let cobalt = Color.blue
    public static let mint = Color.green
    public static let rose = Color.red
    public static let coral = Color.red
}

public struct BoardBackground: View {
    public init() {}
    public var body: some View {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
        #else
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        #endif
    }
}

extension Color {
    static var agentBoardSurface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

extension View {
    @ViewBuilder
    func agentBoardNavigationBarHidden(_ hidden: Bool) -> some View {
        #if os(macOS)
        self
        #else
        navigationBarHidden(hidden)
        #endif
    }

    @ViewBuilder
    func agentBoardNavigationBarTitleInline() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    func agentBoardTextInputAutocapitalizationNever() -> some View {
        #if os(macOS)
        self
        #else
        textInputAutocapitalization(.never)
        #endif
    }
}
