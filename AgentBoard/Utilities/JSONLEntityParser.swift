import Foundation

/// Parses a JSONL event-sourced entity file (create/update/delete ops)
/// into a dictionary of live entities keyed by their ID.
///
/// Shared by CoordinationService and WorkspaceNotesService to avoid
/// duplicating the same JSONL entity-reduction logic.
struct JSONLEntity {
    let type: String
    var properties: [String: String]
}

enum JSONLEntityParser {
    /// Parse a JSONL file at the given path into a dictionary of live entities.
    /// Returns an empty dictionary if the file cannot be read.
    static func parse(filePath: String) -> [String: JSONLEntity] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let text = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return parse(text: text)
    }

    /// Parse JSONL text content into a dictionary of live entities.
    static func parse(text: String) -> [String: JSONLEntity] {
        var entities: [String: JSONLEntity] = [:]

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
                entities[entityId] = JSONLEntity(type: entityType, properties: stringProps)

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

        return entities
    }
}
