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
    public func snapshot() -> CompanionProbeSnapshot {
        let now = Date()
        let machineName = Host.current().localizedName ?? "Local Machine"
        let tmuxPanes = listTmuxPanes()
        let sessions = runningProcesses().compactMap {
            makeSession(
                process: $0,
                tmuxPanes: tmuxPanes,
                now: now,
                machineName: machineName
            )
        }
        let summaries = makeSummaries(sessions: sessions, now: now, machineName: machineName)
        return CompanionProbeSnapshot(sessions: sessions, agents: summaries)
    }

    private func makeSession(
        process: (pid: Int, commandLine: String),
        tmuxPanes: [TmuxPane],
        now: Date,
        machineName: String
    ) -> AgentSession? {
        guard let signature = signatures.first(where: { process.commandLine.contains($0.keyword) }) else {
            return nil
        }
        let matchedPane = tmuxPanes.first { $0.pid == process.pid }
        let output = matchedPane.flatMap { capturePane(paneID: $0.paneID) }
        return AgentSession(
            id: "proc-\(process.pid)",
            source: machineName,
            status: .running,
            linkedTaskID: nil,
            workItem: nil,
            model: "hermes-agent",
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
        now: Date,
        machineName: String
    ) -> [AgentSummary] {
        let agentNames = Set(sessions.map {
            signatures
                .first(where: { $0.keyword == "hermes-agent" || (try? Regex($0.keyword).wholeMatch(in: $0.id)) != nil
                })?.name ?? "Unknown"
        })
        return agentNames
            .filter { !$0.isEmpty }
            .map { makeSummary(agentName: $0, sessions: sessions, now: now, machineName: machineName) }
            .sorted {
                if $0.activeSessionCount != $1.activeSessionCount {
                    return $0.activeSessionCount > $1.activeSessionCount
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func makeSummary(
        agentName: String,
        sessions: [AgentSession],
        now: Date,
        machineName: String
    ) -> AgentSummary {
        let activeSessions = sessions.filter { _ in true } // all matched sessions belong to this agent
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
