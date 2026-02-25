import SwiftUI

struct AgentsView: View {
    @Environment(AppState.self) private var appState

    private struct AgentRow: Identifiable {
        let id: String
        let name: String
        let agentType: String
        let model: String
        let project: String
        let bead: String
        let status: String
        let elapsed: TimeInterval?
        let tokenUsage: Int?
        let estimatedCostUSD: Double?
        let startedAt: Date?
    }

    @State private var expandedHandoffID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statsRow
                agentStatusSection
                handoffsSection
                sessionTableSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Agent Status Cards

    private var agentStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Status")
                .font(.system(size: 18, weight: .semibold))

            let statuses = appState.coordinationService.agentStatuses
            if statuses.isEmpty {
                HStack {
                    Spacer()
                    Text("No agent status data")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
            } else {
                HStack(spacing: 10) {
                    ForEach(statuses) { entry in
                        agentStatusCard(entry)
                    }
                    if statuses.count < 2 {
                        Spacer()
                    }
                }
            }
        }
    }

    private func agentStatusCard(_ entry: AgentStatusEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(agentEmoji(entry.agent) + " " + entry.agent.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                agentStatusBadge(entry.status)
            }

            Text(entry.currentTask.isEmpty ? "No active task" : entry.currentTask)
                .font(.system(size: 12))
                .foregroundStyle(entry.currentTask.isEmpty ? .secondary : .primary)
                .lineLimit(2)

            Text("Updated: \(entry.updated)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    private func agentEmoji(_ agent: String) -> String {
        switch agent.lowercased() {
        case "daneel": return "🤖"
        case "quentin": return "🔬"
        case "argus": return "⚙️"
        default: return "🔹"
        }
    }

    private func agentStatusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(agentStatusColor(status), in: Capsule())
            .opacity(status.lowercased() == "offline" ? 0.5 : 1.0)
    }

    private func agentStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "idle": return .gray
        case "working": return .blue
        case "blocked": return .orange
        case "offline": return .gray
        default: return .gray
        }
    }

    // MARK: - Active Handoffs

    private var handoffsSection: some View {
        let activeHandoffs = appState.coordinationService.handoffs
            .filter { $0.status != "done" && $0.status != "rejected" }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Active Handoffs")
                .font(.system(size: 18, weight: .semibold))

            if activeHandoffs.isEmpty {
                HStack {
                    Spacer()
                    Text("No active handoffs")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(activeHandoffs) { handoff in
                        handoffRow(handoff)
                    }
                }
            }
        }
    }

    private func handoffRow(_ handoff: HandoffEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(agentEmoji(handoff.fromAgent)) → \(agentEmoji(handoff.toAgent))")
                    .font(.system(size: 13))

                Text(handoff.task)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                handoffStatusBadge(handoff.status)

                Text(handoff.date)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if expandedHandoffID == handoff.id {
                Text(handoff.context)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedHandoffID = expandedHandoffID == handoff.id ? nil : handoff.id
            }
        }
    }

    private func handoffStatusBadge(_ status: String) -> some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(handoffStatusColor(status), in: Capsule())
    }

    private func handoffStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "accepted", "in_progress": return .blue
        case "done": return .green
        case "rejected": return .red
        default: return .gray
        }
    }

    // MARK: - Sessions Table

    private var sessionTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.system(size: 18, weight: .semibold))
            agentTable
        }
    }

    private var rows: [AgentRow] {
        let remoteByID = Dictionary(uniqueKeysWithValues: appState.remoteChatSessions.map { ($0.id, $0) })
        var tableRows: [AgentRow] = appState.sessions.map { session in
            let remote = remoteByID[session.id]
            return AgentRow(
                id: session.id,
                name: session.name,
                agentType: session.agentType.rawValue,
                model: session.model ?? remote?.model ?? "—",
                project: session.projectPath?.lastPathComponent ?? remoteProjectName(remote?.projectPath),
                bead: session.beadId ?? remote?.beadID ?? "—",
                status: session.status.rawValue,
                elapsed: session.elapsed,
                tokenUsage: remote?.totalTokens,
                estimatedCostUSD: remote?.estimatedCostUSD,
                startedAt: session.startedAt
            )
        }

        let localIDs = Set(appState.sessions.map(\.id))
        for remote in appState.remoteChatSessions where !localIDs.contains(remote.id) {
            tableRows.append(
                AgentRow(
                    id: remote.id,
                    name: remote.name,
                    agentType: "remote",
                    model: remote.model ?? "—",
                    project: remoteProjectName(remote.projectPath),
                    bead: remote.beadID ?? "—",
                    status: remote.status ?? "unknown",
                    elapsed: elapsedFromRemote(remote),
                    tokenUsage: remote.totalTokens,
                    estimatedCostUSD: remote.estimatedCostUSD,
                    startedAt: remote.startedAt
                )
            )
        }

        return tableRows.sorted { lhs, rhs in
            if statusRank(lhs.status) != statusRank(rhs.status) {
                return statusRank(lhs.status) < statusRank(rhs.status)
            }
            return (lhs.startedAt ?? .distantPast) > (rhs.startedAt ?? .distantPast)
        }
    }

    private var sessionsToday: Int {
        let calendar = Calendar.current
        return rows.filter { row in
            guard let startedAt = row.startedAt else { return false }
            return calendar.isDateInToday(startedAt)
        }.count
    }

    private var totalTokens: Int {
        rows.reduce(0) { partialResult, row in
            partialResult + (row.tokenUsage ?? 0)
        }
    }

    private var totalEstimatedCost: Double {
        rows.reduce(0) { partialResult, row in
            partialResult + (row.estimatedCostUSD ?? 0)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statChip("Sessions Today", value: "\(sessionsToday)")
            statChip("Total Tokens", value: "\(totalTokens)")
            statChip("Estimated Cost", value: String(format: "$%.2f", totalEstimatedCost))
            Spacer()
        }
    }

    private func statChip(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    private var agentTable: some View {
        Table(rows) {
            TableColumn("Name") { row in
                Text(row.name)
                    .lineLimit(1)
            }
            .width(min: 180, ideal: 220, max: 280)

            TableColumn("Agent") { row in
                Text(row.agentType)
                    .font(.system(size: 11, design: .monospaced))
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Model") { row in
                Text(row.model)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 150, max: 220)

            TableColumn("Project") { row in
                Text(row.project)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 140, max: 180)

            TableColumn("Bead") { row in
                Text(row.bead)
                    .font(.system(size: 11, design: .monospaced))
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Status") { row in
                Text(row.status)
                    .font(.system(size: 11, weight: .semibold))
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Elapsed") { row in
                Text(elapsedLabel(row.elapsed))
                    .font(.system(size: 11, design: .monospaced))
            }
            .width(min: 80, ideal: 90, max: 120)

            TableColumn("Tokens") { row in
                Text(row.tokenUsage.map(String.init) ?? "—")
                    .font(.system(size: 11, design: .monospaced))
            }
            .width(min: 70, ideal: 90, max: 130)

            TableColumn("Cost") { row in
                if let estimatedCost = row.estimatedCostUSD {
                    Text(String(format: "$%.2f", estimatedCost))
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    Text("—")
                }
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    private func remoteProjectName(_ rawPath: String?) -> String {
        guard let rawPath, !rawPath.isEmpty else { return "—" }
        return URL(fileURLWithPath: rawPath).lastPathComponent
    }

    private func elapsedFromRemote(_ session: OpenClawRemoteSession) -> TimeInterval? {
        guard let startedAt = session.startedAt else { return nil }
        return Date().timeIntervalSince(startedAt)
    }

    private func elapsedLabel(_ elapsed: TimeInterval?) -> String {
        guard let elapsed else { return "—" }
        let total = max(0, Int(elapsed))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func statusRank(_ status: String) -> Int {
        switch status.lowercased() {
        case "running":
            return 0
        case "idle":
            return 1
        case "stopped", "done", "completed":
            return 2
        case "error", "failed":
            return 3
        default:
            return 4
        }
    }
}
