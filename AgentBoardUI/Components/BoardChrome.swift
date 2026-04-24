import SwiftUI

private enum BoardChromePalette {
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let gold = Color(red: 0.86, green: 0.63, blue: 0.22)
    static let cobalt = Color(red: 0.29, green: 0.47, blue: 0.90)
}

struct BoardSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BoardChromePalette.paper.opacity(0.12),
                                BoardChromePalette.paper.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
    }
}

struct BoardHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(BoardChromePalette.gold)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(BoardChromePalette.paper.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BoardChip: View {
    let label: String
    let systemImage: String
    var tint: Color = BoardChromePalette.cobalt

    var body: some View {
        Label {
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.22))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.36), lineWidth: 1)
        )
    }
}

struct BoardSectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BoardChromePalette.paper.opacity(0.75))
            }
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        BoardSurface {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(BoardChromePalette.gold)

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BoardChromePalette.paper.opacity(0.78))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }
}
