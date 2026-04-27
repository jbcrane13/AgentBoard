import Foundation
import Observation
import os

@MainActor
@Observable
public final class AgentsStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "AgentsStore")
    private let companionClient: CompanionClient
    private let cache: AgentBoardCache
    private let settingsStore: SettingsStore

    public private(set) var tasks: [AgentTask] = []
    public private(set) var summaries: [AgentSummary] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false
    private var lastFingerprint: String = ""

    public init(
        companionClient: CompanionClient,
        cache: AgentBoardCache,
        settingsStore: SettingsStore
    ) {
        self.companionClient = companionClient
        self.cache = cache
        self.settingsStore = settingsStore
    }

    public var tasksByAgent: [(agent: AgentSummary, tasks: [AgentTask])] {
        summaries.map { summary in
            (
                summary,
                tasks.filter {
                    $0.assignedAgent.compare(summary.name, options: .caseInsensitive) == .orderedSame ||
                        $0.assignedAgent.compare(summary.id, options: .caseInsensitive) == .orderedSame
                }
            )
        }
    }

    public func bootstrap() async {
        guard !didBootstrap else { return }

        do {
            tasks = try cache.loadTasks()
            summaries = try cache.loadAgentSummaries()
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
        } catch {
            logger.error("Failed to load agents cache: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        if settingsStore.isCompanionConfigured {
            await refresh()
        }

        didBootstrap = true
    }

    public func refresh() async {
        guard settingsStore.isCompanionConfigured else {
            if tasks.isEmpty, summaries.isEmpty {
                statusMessage = "Connect the companion service in Settings to load agent state."
            }
            return
        }

        isLoading = true

        do {
            try await configureCompanion()
            async let refreshedTasks = companionClient.listTasks()
            async let refreshedSummaries = companionClient.listAgents()
            let newTasks = try await refreshedTasks.sorted { $0.updatedAt > $1.updatedAt }
            let newSummaries = try await refreshedSummaries.sorted { lhs, rhs in
                if lhs.activeSessionCount != rhs.activeSessionCount {
                    return lhs.activeSessionCount > rhs.activeSessionCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            let newFingerprint = fingerprint(tasks: newTasks, summaries: newSummaries)
            if newFingerprint != lastFingerprint {
                tasks = newTasks
                summaries = newSummaries
                lastFingerprint = newFingerprint
                try cache.replaceTasks(tasks)
                try cache.replaceAgentSummaries(summaries)
            }
            // Data unchanged — skip SwiftUI invalidation entirely
        } catch {
            logger.error("Failed to refresh agents: \(error.localizedDescription, privacy: .public)")
            if tasks.isEmpty, summaries.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    public func createTask(_ draft: AgentTaskDraft) async {
        do {
            try await configureCompanion()
            let task = try await companionClient.createTask(draft)
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            try cache.replaceTasks(tasks)
            statusMessage = "Created task \(task.title)."
        } catch {
            logger.error("Failed to create task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func updateTask(id: String, patch: AgentTaskPatch) async {
        do {
            try await configureCompanion()
            let task = try await companionClient.updateTask(id: id, patch: patch)
            upsert(task)
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            try cache.replaceTasks(tasks)
            statusMessage = "Updated \(task.title)."
        } catch {
            logger.error("Failed to update task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func deleteTask(id: String) async {
        do {
            try await configureCompanion()
            try await companionClient.deleteTask(id: id)
            tasks.removeAll { $0.id == id }
            lastFingerprint = fingerprint(tasks: tasks, summaries: summaries)
            try cache.replaceTasks(tasks)
            statusMessage = "Task deleted."
        } catch {
            logger.error("Failed to delete task: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func handle(event: CompanionEventKind) async {
        switch event {
        case .tasksChanged, .agentsChanged, .snapshotRefreshed:
            await refresh()
        case .sessionsChanged:
            break
        }
    }

    private func configureCompanion() async throws {
        try await companionClient.configure(
            baseURL: settingsStore.companionURL,
            bearerToken: settingsStore.companionToken.trimmedOrNil
        )
    }

    private func upsert(_ task: AgentTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }

        tasks.sort { $0.updatedAt > $1.updatedAt }
    }

    private func fingerprint(tasks: [AgentTask], summaries: [AgentSummary]) -> String {
        let taskFP = tasks.map { "\($0.id):\($0.status.rawValue):\($0.title)" }.joined(separator: "|")
        let summaryFP = summaries.map { "\($0.id):\($0.activeSessionCount)" }.joined(separator: "|")
        return "\(taskFP)||\(summaryFP)"
    }
}
