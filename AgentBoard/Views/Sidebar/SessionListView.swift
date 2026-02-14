import SwiftUI

struct SessionListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Coding Sessions")

            ForEach(appState.sessions) { session in
                sessionRow(session)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    private func sessionRow(_ session: CodingSession) -> some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 7, height: 7)
                    .shadow(color: session.status == .running
                            ? statusColor(session.status).opacity(0.5)
                            : .clear, radius: 3)

                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.878, green: 0.878, blue: 0.878))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(statusLabel(session))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .running: Color(red: 0.204, green: 0.78, blue: 0.349)
        case .idle: Color(red: 0.91, green: 0.663, blue: 0)
        case .stopped: Color(red: 0.557, green: 0.557, blue: 0.576)
        case .error: Color(red: 1.0, green: 0.231, blue: 0.188)
        }
    }

    private func statusLabel(_ session: CodingSession) -> String {
        switch session.status {
        case .running:
            let minutes = Int(session.elapsed / 60)
            return "\(minutes)m"
        case .idle: return "idle"
        case .stopped: return "done"
        case .error: return "error"
        }
    }
}
