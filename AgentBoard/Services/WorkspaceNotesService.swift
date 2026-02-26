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

    private let workspaceRoot: String
    private let ontologyPath: String

    init(workspaceRoot: String = NSString(string: "~/.openclaw/workspace").expandingTildeInPath,
         ontologyPath: String = NSString(string: "~/.openclaw/workspace/memory/ontology/graph.jsonl").expandingTildeInPath) {
        self.workspaceRoot = workspaceRoot
        self.ontologyPath = ontologyPath
    }

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
            goToDate(prev)
        }
    }

    func goToNextDay() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            goToDate(next)
        }
    }

    func goToToday() {
        goToDate(Date())
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
        let entities = JSONLEntityParser.parse(filePath: ontologyPath)

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
