import Foundation

struct CodingSession: Identifiable, Hashable {
    let id: String
    let name: String
    let agentType: AgentType
    let projectPath: URL?
    let beadId: String?
    let status: SessionStatus
    let startedAt: Date
    let elapsed: TimeInterval
    let model: String?
    let processID: Int?
    let cpuPercent: Double
}

enum AgentType: String, CaseIterable, Sendable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case openCode = "opencode"
}

enum SessionStatus: String, Sendable {
    case running
    case idle
    case stopped
    case error
}

extension SessionStatus {
    var sortOrder: Int {
        switch self {
        case .running:
            return 0
        case .idle:
            return 1
        case .stopped:
            return 2
        case .error:
            return 3
        }
    }
}

extension CodingSession {
    static let samples: [CodingSession] = [
        CodingSession(
            id: "ses-001", name: "NetMonitor — NWPath",
            agentType: .claudeCode, projectPath: nil, beadId: "NM-096",
            status: .running, startedAt: .now.addingTimeInterval(-720),
            elapsed: 720, model: "claude-opus-4-6", processID: nil, cpuPercent: 2.6
        ),
        CodingSession(
            id: "ses-002", name: "NetMonitor — UI Tests",
            agentType: .claudeCode, projectPath: nil, beadId: "NM-094",
            status: .running, startedAt: .now.addingTimeInterval(-240),
            elapsed: 240, model: "claude-opus-4-6", processID: nil, cpuPercent: 1.2
        ),
        CodingSession(
            id: "ses-003", name: "JubileeTracker — API",
            agentType: .claudeCode, projectPath: nil, beadId: nil,
            status: .idle, startedAt: .now.addingTimeInterval(-3600),
            elapsed: 3600, model: "claude-sonnet-4-5", processID: nil, cpuPercent: 0
        ),
        CodingSession(
            id: "ses-004", name: "CabinetVision — ARKit",
            agentType: .codex, projectPath: nil, beadId: nil,
            status: .stopped, startedAt: .now.addingTimeInterval(-7200),
            elapsed: 1800, model: "gpt-5.3-codex", processID: nil, cpuPercent: 0
        ),
    ]
}
