import SwiftUI

struct TaskCardView: View {
    let bead: Bead

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bead.id)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(bead.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                .lineLimit(3)
                .padding(.bottom, 4)

            HStack(spacing: 6) {
                kindTag

                Spacer()

                if let assignee = bead.assignee, !assignee.isEmpty {
                    Text(assignee)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(bead.updatedAt.formatted(.dateTime.month(.twoDigits).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.04), radius: 0, y: 0)
        .opacity(bead.status == .done ? 0.7 : 1.0)
    }

    private var kindTag: some View {
        Text(bead.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(kindColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(kindColor)
    }

    private var kindColor: Color {
        switch bead.kind {
        case .task: .blue
        case .bug: .red
        case .feature: .green
        case .epic: .purple
        }
    }
}
