import AgentBoardCore
import SwiftUI

public enum BoardPalette {
    public static let paper = Color(.secondaryLabel)
    public static let gold = Color.orange
    public static let cobalt = Color.blue
    public static let mint = Color.green
    public static let rose = Color.red
    public static let coral = Color.red
}

public struct BoardBackground: View {
    public init() {}
    public var body: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }
}
