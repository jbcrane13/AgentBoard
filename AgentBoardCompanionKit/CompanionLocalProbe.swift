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
        AgentSignature(keyword: "cursor", name: "Cursor"),
        AgentSignature(keyword: "hermes-agent", name: "Hermes"),
        AgentSignature(keyword: "/hermes/", name: "Hermes")
    ]

    public init() {}

    /// Snapshot the local machine — session discovery is purely process-based.
    /// Tasks now live in kanban.db; the companion snapshots sessions + agents only.
    public func snapshot() async -> CompanionProbeSnapshot {
        let now = Date()
        let machineName = Host.current().localizedName ?? "Local Machine"
        let tmuxPanes = await listTmuxPanes()
        var sessions: [AgentSession] = []
        for proc in await runningProcesses() {
            if let session = await makeSession(
                process: proc,
                tmuxPanes: tmuxPanes,
                now: now,
                machineName: machineName
            ) {
                sessions.append(session)
            }
        }
        let summaries = Self.makeSummaries(sessions: sessions, now: now, machineName: machineName)
        return CompanionProbeSnapshot(sessions: sessions, agents: summaries)
    }

    private func makeSession(
        process: (pid: Int, commandLine: String),
        tmuxPanes: [TmuxPane],
        now: Date,
        machineName: String
    ) async -> AgentSession? {
        guard let signature = signatures.first(where: { process.commandLine.contains($0.keyword) }) else {
            return nil
        }
        let matchedPane = tmuxPanes.first { $0.pid == process.pid }
        let output: String?
        if let matchedPane {
            output = await capturePane(paneID: matchedPane.paneID)
        } else {
            output = nil
        }
        return AgentSession(
            id: "proc-\(process.pid)",
            source: machineName,
            status: .running,
            linkedTaskID: nil,
            workItem: nil,
            model: signature.name,
            startedAt: now,
            lastSeenAt: now,
            pid: process.pid,
            tmuxSession: matchedPane?.sessionName,
            tmuxPaneID: matchedPane?.paneID,
            lastOutput: output
        )
    }

    static func makeSummaries(
        sessions: [AgentSession],
        now: Date,
        machineName: String
    ) -> [AgentSummary] {
        let groupedSessions = Dictionary(grouping: sessions) { session in
            Self.agentName(for: session)
        }
        return Array(groupedSessions.keys)
            .compactMap { agentName -> AgentSummary? in
                guard let agentName,
                      !agentName.isEmpty,
                      let sessions = groupedSessions[agentName] else {
                    return nil
                }
                return Self.makeSummary(
                    agentName: agentName,
                    sessions: sessions,
                    now: now,
                    machineName: machineName
                )
            }
            .sorted {
                if $0.activeSessionCount != $1.activeSessionCount {
                    return $0.activeSessionCount > $1.activeSessionCount
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func agentName(for session: AgentSession) -> String? {
        if let model = session.model?.trimmingCharacters(in: .whitespacesAndNewlines),
           !model.isEmpty {
            return model
        }
        return nil
    }

    private static func makeSummary(
        agentName: String,
        sessions: [AgentSession],
        now: Date,
        machineName: String
    ) -> AgentSummary {
        let activeSessions = sessions
        return AgentSummary(
            id: agentName.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: agentName,
            health: activeSessions.isEmpty ? .offline : .online,
            activeTaskCount: 0, // tasks now tracked via kanban.db, not companion
            activeSessionCount: activeSessions.count,
            recentActivity: activeSessions.isEmpty
                ? "No live processes detected."
                :
                "\(activeSessions.count) live process\(activeSessions.count == 1 ? "" : "es") running on \(machineName).",
            updatedAt: now
        )
    }

    public func captureOutput(for session: AgentSession) async -> String? {
        let target = session.tmuxPaneID ?? session.tmuxSession
        guard let target else { return nil }
        let raw = await shell("/usr/bin/env", ["tmux", "capture-pane", "-t", target, "-p", "-S", "-2000"])
        return raw.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    public func nudge(session: AgentSession) async -> Bool {
        let target = session.tmuxPaneID ?? session.tmuxSession
        if let target {
            return await shell("/usr/bin/env", ["tmux", "send-keys", "-t", target, "", "Enter"]) != nil
        }
        if let pid = session.pid {
            return kill(Int32(pid), SIGCONT) == 0
        }
        return false
    }

    public func stop(session: AgentSession) async -> Bool {
        if let tmuxSession = session.tmuxSession {
            return await shell("/usr/bin/env", ["tmux", "kill-session", "-t", tmuxSession]) != nil
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

    private func listTmuxPanes() async -> [TmuxPane] {
        guard let output = await shell(
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

    private func capturePane(paneID: String) async -> String? {
        let raw = await shell("/usr/bin/env", ["tmux", "capture-pane", "-t", paneID, "-p", "-S", "-200"])
        return raw.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    private func runningProcesses() async -> [(pid: Int, commandLine: String)] {
        let result: ProcessResult
        do {
            result = try await Process.runAsync(
                executablePath: "/bin/ps",
                arguments: ["-axo", "pid=,args="]
            )
        } catch {
            return []
        }
        guard result.succeeded else { return [] }
        let raw = result.stdoutString
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
    private func shell(_ executable: String, _ arguments: [String]) async -> String? {
        do {
            let result = try await Process.runAsync(
                executablePath: executable,
                arguments: arguments
            )
            guard result.succeeded else { return nil }
            return result.stdoutString
        } catch {
            return nil
        }
    }
}
