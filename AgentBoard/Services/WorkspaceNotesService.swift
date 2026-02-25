import Foundation

struct OntologyDayEntry: Identifiable, Sendable {
    let id: String
    let type: String
    let title: String
    let summary: String
    let projectId: String?
    let status: String?
}

@Observable
@MainActor
final class WorkspaceNotesService {
    var selectedDate: Date = Date()
    var dailyNotes: String = ""
    var ontologyEntries: [OntologyDayEntry] = []

    private let workspaceRoot = NSString(string: "~/.openclaw/workspace").expandingTildeInPath
    private let ontologyPath = NSString(string: "~/.openclaw/workspace/memory/ontology/graph.jsonl").expandingTildeInPath

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func goToDate(_ date: Date) {
        selectedDate = date
        reload()
    }

    func goToPreviousDay() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = prev
            reload()
        }
    }

    func goToNextDay() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = next
            reload()
        }
    }

    func goToToday() {
        selectedDate = Date()
        reload()
    }

    private func reload() {
        loadDailyNotes()
        loadOntology()
    }

    private func loadDailyNotes() {
        let dateStr = dayFormatter.string(from: selectedDate)
        let path = (workspaceRoot as NSString).appendingPathComponent("memory/\(dateStr).md")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let text = String(data: data, encoding: .utf8) {
            dailyNotes = text
        } else {
            dailyNotes = ""
        }
    }

    private func loadOntology() {
        let dateStr = dayFormatter.string(from: selectedDate)
        let allowedTypes: Set<String> = ["Decision", "Lesson", "Bug"]

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: ontologyPath)),
              let text = String(data: data, encoding: .utf8) else {
            ontologyEntries = []
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

        var results: [OntologyDayEntry] = []
        for (entityId, entity) in entities {
            guard allowedTypes.contains(entity.type),
                  entity.properties["date"] == dateStr else { continue }
            results.append(OntologyDayEntry(
                id: entityId,
                type: entity.type,
                title: entity.properties["title"] ?? entity.properties["summary"] ?? entityId,
                summary: entity.properties["summary"] ?? "",
                projectId: entity.properties["project_id"],
                status: entity.properties["status"]
            ))
        }

        results.sort { $0.type < $1.type }
        ontologyEntries = results
    }
}
