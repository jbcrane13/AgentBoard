import Foundation

struct AgentStatusEntry: Identifiable, Sendable {
    let id: String
    let agent: String
    let status: String
    let currentTask: String
    let updated: String
}

struct HandoffEntry: Identifiable, Sendable {
    let id: String
    let fromAgent: String
    let toAgent: String
    let task: String
    let context: String
    let status: String
    let beadId: String?
    let date: String
}

@Observable
@MainActor
final class CoordinationService {
    var agentStatuses: [AgentStatusEntry] = []
    var handoffs: [HandoffEntry] = []

    private var pollingTask: Task<Void, Never>?
    private let filePath: String

    init(filePath: String = NSString(string: "~/.openclaw/shared/coordination.jsonl").expandingTildeInPath) {
        self.filePath = filePath
    }

    func startPolling() {
        stopPolling()
        reload()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                self?.reload()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func reload() {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        let entities = JSONLEntityParser.parse(filePath: filePath)

        var statuses: [AgentStatusEntry] = []
        var handoffList: [HandoffEntry] = []

        for (entityId, entity) in entities {
            switch entity.type {
            case "AgentStatus":
                statuses.append(AgentStatusEntry(
                    id: entityId,
                    agent: entity.properties["agent"] ?? "unknown",
                    status: entity.properties["status"] ?? "offline",
                    currentTask: entity.properties["current_task"] ?? "",
                    updated: entity.properties["updated"] ?? ""
                ))

            case "Handoff":
                handoffList.append(HandoffEntry(
                    id: entityId,
                    fromAgent: entity.properties["from_agent"] ?? "",
                    toAgent: entity.properties["to_agent"] ?? "",
                    task: entity.properties["task"] ?? "",
                    context: entity.properties["context"] ?? "",
                    status: entity.properties["status"] ?? "pending",
                    beadId: entity.properties["bead_id"],
                    date: entity.properties["date"] ?? ""
                ))

            default:
                break
            }
        }

        statuses.sort { $0.agent < $1.agent }
        handoffList.sort { $0.date > $1.date }

        agentStatuses = statuses
        handoffs = handoffList
    }
}
