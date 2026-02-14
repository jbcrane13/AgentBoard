import SwiftUI

struct BoardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            boardColumn(title: "Open", status: .open, color: .blue)
            boardColumn(title: "In Progress", status: .inProgress, color: .orange)
            boardColumn(title: "Blocked", status: .blocked, color: .red)
            boardColumn(title: "Done", status: .done, color: .green)
        }
        .padding(16)
        .padding(.horizontal, 8)
    }

    private func boardColumn(title: String, status: BeadStatus, color: Color) -> some View {
        let beads = appState.beads.filter { $0.status == status }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(color)

                Text("\(beads.count)")
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
                    if beads.isEmpty {
                        Text(status == .done ? "All clear" : "No issues")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(beads) { bead in
                            TaskCardView(bead: bead)
                        }
                    }
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
