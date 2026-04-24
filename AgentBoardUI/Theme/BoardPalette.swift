import SwiftUI

enum BoardPalette {
    static let night = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let deepSea = Color(red: 0.11, green: 0.19, blue: 0.24)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let warmInk = Color(red: 0.16, green: 0.18, blue: 0.21)
    static let coral = Color(red: 0.94, green: 0.43, blue: 0.34)
    static let gold = Color(red: 0.86, green: 0.63, blue: 0.22)
    static let mint = Color(red: 0.36, green: 0.74, blue: 0.62)
    static let cobalt = Color(red: 0.29, green: 0.47, blue: 0.90)
    static let rose = Color(red: 0.82, green: 0.32, blue: 0.46)
    static let fog = Color.white.opacity(0.82)
}

struct BoardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoardPalette.night, BoardPalette.deepSea, BoardPalette.warmInk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(BoardPalette.coral.opacity(0.14))
                .frame(width: 520, height: 520)
                .blur(radius: 12)
                .offset(x: -260, y: -240)

            Circle()
                .fill(BoardPalette.gold.opacity(0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 16)
                .offset(x: 300, y: -280)

            RoundedRectangle(cornerRadius: 56, style: .continuous)
                .fill(BoardPalette.fog.opacity(0.04))
                .frame(width: 700, height: 460)
                .rotationEffect(.degrees(12))
                .offset(x: 180, y: 240)
                .blur(radius: 2)
        }
    }
}
