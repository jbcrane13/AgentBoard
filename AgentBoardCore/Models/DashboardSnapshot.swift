import Foundation

/// Pure aggregation of the app's existing stores into the numbers the
/// Dashboard home screen renders. Holds no state of its own — callers
/// rebuild it from current store contents whenever they need a snapshot.
public struct DashboardSnapshot: Equatable, Sendable {
    public struct KanbanSummary: Equatable, Sendable {
        public let running: Int
        public let ready: Int
        public let blocked: Int
        public let done: Int
        public let total: Int

        public init(running: Int, ready: Int, blocked: Int, done: Int, total: Int) {
            self.running = running
            self.ready = ready
            self.blocked = blocked
            self.done = done
            self.total = total
        }
    }

    public struct WorkSummary: Equatable, Sendable {
        public let todo: Int
        public let inProgress: Int
        public let resolved: Int

        public init(todo: Int, inProgress: Int, resolved: Int) {
            self.todo = todo
            self.inProgress = inProgress
            self.resolved = resolved
        }
    }

    public struct SessionsSummary: Equatable, Sendable {
        public let active: Int
        public let total: Int
        public let syncStatus: SessionsSyncStatus

        public init(active: Int, total: Int, syncStatus: SessionsSyncStatus) {
            self.active = active
            self.total = total
            self.syncStatus = syncStatus
        }
    }

    public let kanban: KanbanSummary
    public let work: WorkSummary
    public let sessions: SessionsSummary
    public let runningTaskTitles: [String]
    public let recentConversations: [ChatConversation]
    public let chatConnection: ChatConnectionState

    public static func build(
        kanbanTasks: [KanbanTask],
        workItems: [WorkItem],
        sessions: [AgentSession],
        conversations: [ChatConversation],
        chatConnection: ChatConnectionState,
        syncStatus: SessionsSyncStatus = .offline
    ) -> DashboardSnapshot {
        let kanbanSummary = KanbanSummary(
            running: kanbanTasks.count { $0.status == .running },
            ready: kanbanTasks.count { $0.status == .ready },
            blocked: kanbanTasks.count { $0.status == .blocked },
            done: kanbanTasks.count { $0.status == .done },
            total: kanbanTasks.count
        )

        let workSummary = workItems.reduce(into: (todo: 0, inProgress: 0, resolved: 0)) { counts, item in
            switch WorkBoardColumn.column(for: item.status) {
            case .todo: counts.todo += 1
            case .inProgress: counts.inProgress += 1
            case .resolved: counts.resolved += 1
            }
        }

        let sessionsSummary = SessionsSummary(
            active: sessions.count { $0.status == .running },
            total: sessions.count,
            syncStatus: syncStatus
        )

        let runningTaskTitles = kanbanTasks
            .filter { $0.status == .running }
            .prefix(3)
            .map(\.title)

        let recentConversations = conversations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)

        return DashboardSnapshot(
            kanban: kanbanSummary,
            work: WorkSummary(
                todo: workSummary.todo,
                inProgress: workSummary.inProgress,
                resolved: workSummary.resolved
            ),
            sessions: sessionsSummary,
            runningTaskTitles: Array(runningTaskTitles),
            recentConversations: Array(recentConversations),
            chatConnection: chatConnection
        )
    }
}
