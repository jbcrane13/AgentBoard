import AgentBoardCore
import Foundation

public struct CompanionProbeSnapshot: Sendable {
    public let sessions: [AgentSession]
    public let agents: [AgentSummary]

    public init(sessions: [AgentSession], agents: [AgentSummary]) {
        self.sessions = sessions
        self.agents = agents
    }
}

public actor CompanionLocalProbe {
    private struct AgentSignature: Sendable {
        let keyword: String
        let name: String
    }

    private let signatures: [AgentSignature] = [
        AgentSignature(keyword: "codex", name: "Codex"),
        AgentSignature(keyword: "claude", name: "Claude"),
        AgentSignature(keyword: "aider", name: "Aider"),
        AgentSignature(keyword: "cursor", name: "Cursor")
    ]

    public init() {}

    public func snapshot(tasks: [AgentTask]) -> CompanionProbeSnapshot {
        let now = Date()
        let machineName = Host.current().localizedName ?? "Local Machine"
        let processes = runningProcesses()

        let sessions = processes.compactMap { process -> AgentSession? in
            guard let signature = signatures.first(where: { process.commandLine.contains($0.keyword) }) else {
                return nil
            }

            let linkedTask = tasks.first {
                $0.sessionID == "proc-\(process.pid)" ||
                    $0.assignedAgent.compare(signature.name, options: .caseInsensitive) == .orderedSame
            }

            return AgentSession(
                id: "proc-\(process.pid)",
                source: machineName,
                status: .running,
                linkedTaskID: linkedTask?.id,
                workItem: linkedTask?.workItem,
                model: linkedTask == nil ? nil : "hermes-agent",
                startedAt: now,
                lastSeenAt: now
            )
        }

        let agentNames = Set(
            sessions.map { inferredAgentName(from: $0.linkedTaskID, tasks: tasks, fallback: $0.id) } +
                tasks.map(\.assignedAgent)
        )

        let summaries = agentNames
            .filter { !$0.isEmpty }
            .map { agentName -> AgentSummary in
                let activeTasks = tasks.filter {
                    $0.assignedAgent.compare(agentName, options: .caseInsensitive) == .orderedSame &&
                        $0.status != .done
                }
                let activeSessions = sessions.filter { session in
                    if let linkedTaskID = session.linkedTaskID,
                       let task = tasks.first(where: { $0.id == linkedTaskID }) {
                        return task.assignedAgent.compare(agentName, options: .caseInsensitive) == .orderedSame
                    }

                    return session.id.lowercased().contains(agentName.lowercased())
                }

                let health: AgentHealthStatus = if !activeSessions.isEmpty {
                    .online
                } else if !activeTasks.isEmpty {
                    .idle
                } else {
                    .offline
                }

                let activity: String
                if !activeSessions.isEmpty {
                    activity = "\(activeSessions.count) live process\(activeSessions.count == 1 ? "" : "es") running on \(machineName)."
                } else if !activeTasks.isEmpty {
                    activity = "\(activeTasks.count) task\(activeTasks.count == 1 ? "" : "s") queued."
                } else {
                    activity = "No live processes detected."
                }

                return AgentSummary(
                    id: agentName
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-"),
                    name: agentName,
                    health: health,
                    activeTaskCount: activeTasks.count,
                    activeSessionCount: activeSessions.count,
                    recentActivity: activity,
                    updatedAt: now
                )
            }
            .sorted { lhs, rhs in
                if lhs.activeSessionCount != rhs.activeSessionCount {
                    return lhs.activeSessionCount > rhs.activeSessionCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return CompanionProbeSnapshot(sessions: sessions, agents: summaries)
    }

    private func inferredAgentName(from linkedTaskID: String?, tasks: [AgentTask], fallback: String) -> String {
        if let linkedTaskID,
           let task = tasks.first(where: { $0.id == linkedTaskID }) {
            return task.assignedAgent
        }

        return signatures.first(where: { fallback.lowercased().contains($0.keyword) })?.name ?? ""
    }

    private func runningProcesses() -> [(pid: Int, commandLine: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,args="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard let data = try? output.fileHandleForReading.readToEnd(),
              let raw = String(data: data, encoding: .utf8) else {
            return []
        }

        return raw
            .split(separator: "\n")
            .compactMap { line -> (Int, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let pieces = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard pieces.count == 2, let pid = Int(pieces[0]) else { return nil }
                let commandLine = String(pieces[1]).lowercased()
                return (pid, commandLine)
            }
            .filter { process in
                signatures.contains { process.commandLine.contains($0.keyword) }
            }
    }
}
