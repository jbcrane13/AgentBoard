import SwiftUI

struct ProjectHeaderView: View {
    @Environment(AppState.self) private var appState
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Text(project.name)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.primary)

            connectionBadge

            Spacer()

            statsRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppTheme.appBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var connectionBadge: some View {
        let state = appState.chatConnectionState
        return HStack(spacing: 5) {
            Circle()
                .fill(state.color)
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(state.color.opacity(0.12), in: Capsule())
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(value: project.openCount, label: "Open")
            statItem(value: project.inProgressCount, label: "In Progress")
            statItem(value: project.totalCount, label: "Total")
        }
        .padding(.leading, 12)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
    }
}
