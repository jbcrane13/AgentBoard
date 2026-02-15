import SwiftUI

struct BoardView: View {
    private struct Column: Identifiable {
        let id: String
        let title: String
        let status: BeadStatus
        let color: Color
    }

    private let columns: [Column] = [
        .init(id: "open", title: "Open", status: .open, color: .blue),
        .init(id: "in-progress", title: "In Progress", status: .inProgress, color: .orange),
        .init(id: "blocked", title: "Blocked", status: .blocked, color: .red),
        .init(id: "done", title: "Done", status: .done, color: .green),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(columns) { column in
                boardColumn(title: column.title, status: column.status, color: column.color)
            }
        }
        .padding(16)
        .padding(.horizontal, 8)
    }

    private func boardColumn(title: String, status: BeadStatus, color: Color) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(color)

                Text("0")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.04), in: Capsule())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 8) {
                    Text(status == .done ? "All clear 🎉" : "No issues")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .padding(8)
            }
            .background(columnBackground(for: status), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private func columnBackground(for status: BeadStatus) -> Color {
        switch status {
        case .open: Color.blue.opacity(0.03)
        case .inProgress: Color.orange.opacity(0.04)
        case .blocked: Color.red.opacity(0.04)
        case .done: Color.green.opacity(0.03)
        }
    }
}
