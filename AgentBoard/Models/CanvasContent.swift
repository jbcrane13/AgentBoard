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
        case .markdown(let id, _, _): id
        case .html(let id, _, _): id
        case .image(let id, _, _): id
        case .diff(let id, _, _, _, _): id
        case .diagram(let id, _, _): id
        case .terminal(let id, _, _): id
        }
    }
}
