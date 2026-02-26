import SwiftUI

struct TaskCardView: View {
    @Environment(AppState.self) private var appState
    let bead: Bead

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(bead.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                priorityBadge
            }

            Text(bead.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .padding(.bottom, 4)

            HStack(spacing: 6) {
                kindTag

                Spacer()

                if let assignee = bead.assignee, !assignee.isEmpty {
                    Text(AgentDefinition.find(assignee).displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(bead.updatedAt.formatted(.dateTime.month(.twoDigits).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if let gitSummary = appState.gitSummary(for: bead.id) {
                gitSummaryRow(gitSummary)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
        .opacity(bead.status == .done ? 0.7 : 1.0)
    }

    private var kindTag: some View {
        Text(bead.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bead.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(bead.kind.color)
    }

    private var priorityBadge: some View {
        let color = priorityColor(for: bead.priority)
        return Text("P\(bead.priority)")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private func gitSummaryRow(_ summary: BeadGitSummary) -> some View {
        HStack(spacing: 6) {
            if bead.status == .inProgress {
                Text("\(summary.commitCount)")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.16), in: Capsule())
                    .foregroundStyle(.orange)
            }

            if let branch = summary.latestCommit.branch ?? appState.currentGitBranch {
                Text(branch)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(summary.latestCommit.shortSHA) {
                Task {
                    await appState.openCommitDiffInCanvas(beadID: bead.id)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.accentColor)
        }
    }
}
