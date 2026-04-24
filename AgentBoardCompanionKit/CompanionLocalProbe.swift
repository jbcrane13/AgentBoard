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
        let tmuxPanes = listTmuxPanes()
        let sessions = runningProcesses().compactMap {
            makeSession(process: $0, tasks: tasks, tmuxPanes: tmuxPanes, now: now, machineName: machineName)
        }
        let summaries = makeSummaries(sessions: sessions, tasks: tasks, now: now, machineName: machineName)
        return CompanionProbeSnapshot(sessions: sessions, agents: summaries)
    }

    private func makeSession(
        process: (pid: Int, commandLine: String),
        tasks: [AgentTask],
        tmuxPanes: [TmuxPane],
        now: Date,
        machineName: String
    ) -> AgentSession? {
        guard let signature = signatures.first(where: { process.commandLine.contains($0.keyword) }) else {
            return nil
        }
        let linkedTask = tasks.first {
            $0.sessionID == "proc-\(process.pid)" ||
                $0.assignedAgent.compare(signature.name, options: .caseInsensitive) == .orderedSame
        }
        let matchedPane = tmuxPanes.first { $0.pid == process.pid }
        let output = matchedPane.flatMap { capturePane(paneID: $0.paneID) }
        return AgentSession(
            id: "proc-\(process.pid)",
            source: machineName,
            status: .running,
            linkedTaskID: linkedTask?.id,
            workItem: linkedTask?.workItem,
            model: linkedTask == nil ? nil : "hermes-agent",
            startedAt: now,
            lastSeenAt: now,
            pid: process.pid,
            tmuxSession: matchedPane?.sessionName,
            tmuxPaneID: matchedPane?.paneID,
            lastOutput: output
        )
    }

    private func makeSummaries(
        sessions: [AgentSession],
        tasks: [AgentTask],
        now: Date,
        machineName: String
    ) -> [AgentSummary] {
        let agentNames = Set(
            sessions.map { inferredAgentName(from: $0.linkedTaskID, tasks: tasks, fallback: $0.id) } +
                tasks.map(\.assignedAgent)
        )
        return agentNames
            .filter { !$0.isEmpty }
            .map { makeSummary(agentName: $0, sessions: sessions, tasks: tasks, now: now, machineName: machineName) }
            .sorted {
                if $0.activeSessionCount != $1.activeSessionCount { return $0.activeSessionCount > $1.activeSessionCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func makeSummary(
        agentName: String,
        sessions: [AgentSession],
        tasks: [AgentTask],
        now: Date,
        machineName: String
    ) -> AgentSummary {
        let activeTasks = tasks.filter {
            $0.assignedAgent.compare(agentName, options: .caseInsensitive) == .orderedSame && $0.status != .done
        }
        let activeSessions = sessions.filter { sessionMatchesAgent($0, agentName: agentName, tasks: tasks) }
        let health = agentHealth(sessions: activeSessions, tasks: activeTasks)
        return AgentSummary(
            id: agentName.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: agentName,
            health: health,
            activeTaskCount: activeTasks.count,
            activeSessionCount: activeSessions.count,
            recentActivity: agentActivity(sessions: activeSessions, tasks: activeTasks, machineName: machineName),
            updatedAt: now
        )
    }

    private func sessionMatchesAgent(_ session: AgentSession, agentName: String, tasks: [AgentTask]) -> Bool {
        if let linkedTaskID = session.linkedTaskID,
           let task = tasks.first(where: { $0.id == linkedTaskID }) {
            return task.assignedAgent.compare(agentName, options: .caseInsensitive) == .orderedSame
        }
        return session.id.lowercased().contains(agentName.lowercased())
    }

    private func agentHealth(sessions: [AgentSession], tasks: [AgentTask]) -> AgentHealthStatus {
        if !sessions.isEmpty { return .online }
        if !tasks.isEmpty { return .idle }
        return .offline
    }

    private func agentActivity(sessions: [AgentSession], tasks: [AgentTask], machineName: String) -> String {
        if !sessions.isEmpty {
            let count = sessions.count
            return "\(count) live process\(count == 1 ? "" : "es") running on \(machineName)."
        }
        if !tasks.isEmpty {
            let count = tasks.count
            return "\(count) task\(count == 1 ? "" : "s") queued."
        }
        return "No live processes detected."
    }

    public func captureOutput(for session: AgentSession) -> String? {
        let target = session.tmuxPaneID ?? session.tmuxSession
        guard let target else { return nil }
        return shell("/usr/bin/env", ["tmux", "capture-pane", "-t", target, "-p", "-S", "-200"])
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    public func nudge(session: AgentSession) -> Bool {
        let target = session.tmuxPaneID ?? session.tmuxSession
        if let target {
            return shell("/usr/bin/env", ["tmux", "send-keys", "-t", target, "", "Enter"]) != nil
        }
        if let pid = session.pid {
            return kill(Int32(pid), SIGCONT) == 0
        }
        return false
    }

    public func stop(session: AgentSession) -> Bool {
        if let tmuxSession = session.tmuxSession {
            return shell("/usr/bin/env", ["tmux", "kill-session", "-t", tmuxSession]) != nil
        }
        if let pid = session.pid {
            return kill(Int32(pid), SIGTERM) == 0
        }
        return false
    }

    private struct TmuxPane: Sendable {
        let pid: Int
        let sessionName: String
        let paneID: String
    }

    private func listTmuxPanes() -> [TmuxPane] {
        guard let output = shell(
            "/usr/bin/env",
            ["tmux", "list-panes", "-a", "-F", "#{pane_pid} #{session_name} #{pane_id}"]
        ) else {
            return []
        }

        return output
            .split(separator: "\n")
            .compactMap { line -> TmuxPane? in
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count == 3,
                      let pid = Int(parts[0]) else {
                    return nil
                }
                return TmuxPane(
                    pid: pid,
                    sessionName: String(parts[1]),
                    paneID: String(parts[2])
                )
            }
    }

    private func capturePane(paneID: String) -> String? {
        shell("/usr/bin/env", ["tmux", "capture-pane", "-t", paneID, "-p", "-S", "-200"])
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
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

    @discardableResult
    private func shell(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = output
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard let data = try? output.fileHandleForReading.readToEnd() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
