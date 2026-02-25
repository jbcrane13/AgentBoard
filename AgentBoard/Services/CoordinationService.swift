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

    private var pollTimer: Timer?
    private let filePath: String

    init(filePath: String = NSString(string: "~/.openclaw/shared/coordination.jsonl").expandingTildeInPath) {
        self.filePath = filePath
    }

    func startPolling() {
        reload()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func reload() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        var entities: [String: (type: String, properties: [String: String])] = [:]

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let op = json["op"] as? String else {
                continue
            }

            switch op {
            case "create":
                guard let entity = json["entity"] as? [String: Any],
                      let entityId = entity["id"] as? String,
                      let entityType = entity["type"] as? String else { continue }
                let props = (entity["properties"] as? [String: Any]) ?? [:]
                var stringProps: [String: String] = [:]
                for (key, value) in props {
                    stringProps[key] = "\(value)"
                }
                entities[entityId] = (type: entityType, properties: stringProps)

            case "update":
                guard let entityId = json["id"] as? String,
                      let props = json["properties"] as? [String: Any] else { continue }
                if var existing = entities[entityId] {
                    for (key, value) in props {
                        existing.properties[key] = "\(value)"
                    }
                    entities[entityId] = existing
                }

            case "delete":
                if let entityId = json["id"] as? String {
                    entities.removeValue(forKey: entityId)
                }

            default:
                break
            }
        }

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
