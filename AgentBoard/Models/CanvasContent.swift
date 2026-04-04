import Foundation

enum CanvasContent: Identifiable, Hashable {
    case markdown(id: UUID, title: String, content: String)
    case html(id: UUID, title: String, content: String)
    case image(id: UUID, title: String, url: URL)
    case diff(id: UUID, title: String, before: String, after: String, filename: String)
    case diagram(id: UUID, title: String, mermaid: String)
    case terminal(id: UUID, title: String, output: String)

    var id: UUID {
        switch self {
        case let .markdown(id, _, _): id
        case let .html(id, _, _): id
        case let .image(id, _, _): id
        case let .diff(id, _, _, _, _): id
        case let .diagram(id, _, _): id
        case let .terminal(id, _, _): id
        }
    }
}
