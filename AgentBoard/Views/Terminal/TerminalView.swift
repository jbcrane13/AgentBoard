import SwiftUI

struct TerminalView: View {
    @Environment(AppState.self) private var appState

    let session: CodingSession

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            InteractiveTerminalView(sessionID: session.id)
        }
        .background(AppTheme.appBackground)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                appState.backToBoardFromTerminal()
            } label: {
                Label("Back to Board", systemImage: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])

            Divider()
                .frame(height: 14)

            Text(session.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            statusChip

            if let model = session.model, !model.isEmpty {
                Text(model)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let beadID = session.beadId {
                Text(beadID)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
            }

            Text(elapsedLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Nudge") {
                Task {
                    await appState.nudgeSession(sessionID: session.id)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(session.status.rawValue.capitalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusColor: Color {
        AppTheme.sessionColor(for: session.status)
    }

    private var elapsedLabel: String {
        let elapsed = max(0, Int(session.elapsed))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
