import SwiftUI

enum CenterTab: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
    case agents = "Agents"
    case history = "History"
}

enum SidebarNavItem: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
    case history = "History"
    case settings = "Settings"
}

enum RightPanelMode: String, CaseIterable, Sendable {
    case chat = "Chat"
    case canvas = "Canvas"
    case split = "Split"
}

@Observable
@MainActor
final class AppState {
    var projects: [Project] = Project.samples
    var selectedProject: Project? = Project.samples.first
    var beads: [Bead] = Bead.samples
    var sessions: [CodingSession] = CodingSession.samples
    var chatMessages: [ChatMessage] = ChatMessage.samples

    var selectedTab: CenterTab = .board
    var rightPanelMode: RightPanelMode = .split
    var sidebarNavSelection: SidebarNavItem? = .board
}
