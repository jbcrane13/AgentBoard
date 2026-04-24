import Foundation

public enum DemoFixtures {
    public static let repositories: [ConfiguredRepository] = [
        ConfiguredRepository(owner: "every", name: "market-map"),
        ConfiguredRepository(owner: "hermes-ai", name: "gateway")
    ]

    public static let workItems: [WorkItem] = [
        WorkItem(
            repository: repositories[0],
            issueNumber: 184,
            title: "Ship mobile-first Hermes conversation shell",
            bodySummary:
            "Tighten the composer, streaming behavior, and offline history caching across both app shells.",
            isClosed: false,
            assignees: ["blake"],
            milestone: WorkMilestone(number: 3, title: "Mobile Rebuild"),
            labels: ["status:in-progress", "priority:p1", "agent:codex"],
            status: .inProgress,
            priority: .high,
            agentHint: "codex",
            createdAt: .now.addingTimeInterval(-86400),
            updatedAt: .now.addingTimeInterval(-900)
        ),
        WorkItem(
            repository: repositories[0],
            issueNumber: 188,
            title: "Design the agent task companion API",
            bodySummary:
            "Define task CRUD, live sessions, and the streaming event contract the client will consume.",
            isClosed: false,
            assignees: ["blake"],
            milestone: WorkMilestone(number: 3, title: "Mobile Rebuild"),
            labels: ["status:open", "priority:p0", "agent:claude"],
            status: .open,
            priority: .critical,
            agentHint: "claude",
            createdAt: .now.addingTimeInterval(-172_800),
            updatedAt: .now.addingTimeInterval(-7200)
        ),
        WorkItem(
            repository: repositories[1],
            issueNumber: 52,
            title: "Audit Hermes model discovery fallback",
            bodySummary:
            "Make the app resilient when `/v1/models` is unavailable and preserve a chosen default model.",
            isClosed: false,
            assignees: [],
            milestone: nil,
            labels: ["status:blocked", "priority:p2"],
            status: .blocked,
            priority: .medium,
            agentHint: nil,
            createdAt: .now.addingTimeInterval(-240_000),
            updatedAt: .now.addingTimeInterval(-18000)
        )
    ]

    public static let tasks: [AgentTask] = [
        AgentTask(
            id: "task-chat-shell",
            workItem: workItems[0].reference,
            title: "Polish streaming composer states",
            status: .inProgress,
            priority: .high,
            assignedAgent: "Codex",
            sessionID: "proc-1208",
            note: "Mobile shell first, then macOS parity.",
            createdAt: .now.addingTimeInterval(-7200),
            updatedAt: .now.addingTimeInterval(-600)
        ),
        AgentTask(
            id: "task-companion-contract",
            workItem: workItems[1].reference,
            title: "Draft task update payloads",
            status: .backlog,
            priority: .critical,
            assignedAgent: "Claude",
            note: "Need CRUD plus SSE events.",
            createdAt: .now.addingTimeInterval(-10000),
            updatedAt: .now.addingTimeInterval(-4800)
        )
    ]

    public static let sessions: [AgentSession] = [
        AgentSession(
            id: "proc-1208",
            source: "Blake's MacBook Pro",
            status: .running,
            linkedTaskID: tasks[0].id,
            workItem: tasks[0].workItem,
            model: "hermes-agent",
            startedAt: .now.addingTimeInterval(-5400),
            lastSeenAt: .now.addingTimeInterval(-30)
        )
    ]

    public static let agents: [AgentSummary] = [
        AgentSummary(
            id: "codex",
            name: "Codex",
            health: .online,
            activeTaskCount: 1,
            activeSessionCount: 1,
            recentActivity: "Streaming a fresh shell build to the new chat surface.",
            updatedAt: .now
        ),
        AgentSummary(
            id: "claude",
            name: "Claude",
            health: .idle,
            activeTaskCount: 1,
            activeSessionCount: 0,
            recentActivity:
            "Waiting on the companion contract before starting implementation.",
            updatedAt: .now.addingTimeInterval(-120)
        )
    ]
}
