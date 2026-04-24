import Foundation
import Observation
import os

@MainActor
@Observable
public final class WorkStore {
    private let logger = Logger(subsystem: "com.agentboard.modern", category: "WorkStore")
    private let service: GitHubWorkService
    private let cache: AgentBoardCache
    private let settingsStore: SettingsStore

    public private(set) var items: [WorkItem] = []
    public var searchText = ""
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var statusMessage: String?

    private var didBootstrap = false

    public init(
        service: GitHubWorkService,
        cache: AgentBoardCache,
        settingsStore: SettingsStore
    ) {
        self.service = service
        self.cache = cache
        self.settingsStore = settingsStore
    }

    public var filteredItems: [WorkItem] {
        let needle = searchText.trimmedOrNil?.lowercased()
        guard let needle else { return items }
        return items.filter { item in
            item.title.lowercased().contains(needle) ||
                item.bodySummary.lowercased().contains(needle) ||
                item.issueReference.lowercased().contains(needle) ||
                item.labels.joined(separator: " ").lowercased().contains(needle)
        }
    }

    public var groupedItems: [(state: WorkState, items: [WorkItem])] {
        WorkState.allCases.map { state in
            (
                state,
                filteredItems.filter { $0.status == state }
            )
        }
    }

    public func bootstrap() async {
        guard !didBootstrap else { return }

        do {
            items = try cache.loadWorkItems()
        } catch {
            logger.error("Failed to load work cache: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        if settingsStore.isGitHubConfigured {
            await refresh()
        }

        didBootstrap = true
    }

    public func refresh() async {
        guard settingsStore.isGitHubConfigured else {
            if items.isEmpty {
                statusMessage = "Connect GitHub repositories in Settings to load work."
            }
            return
        }

        isLoading = true
        errorMessage = nil

        await service.configure(
            repositories: settingsStore.repositories,
            token: settingsStore.githubToken.trimmedOrNil
        )

        do {
            items = try await service.fetchWorkItems()
            try cache.replaceWorkItems(items)
            statusMessage = "Loaded \(items.count) GitHub issues."
        } catch {
            logger.error("Failed to refresh work items: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func updateStatus(for item: WorkItem, to state: WorkState) async {
        guard settingsStore.isGitHubConfigured else {
            errorMessage = "Connect GitHub before updating work items."
            return
        }

        await service.configure(
            repositories: settingsStore.repositories,
            token: settingsStore.githubToken.trimmedOrNil
        )

        let labels = replacingStatusLabels(in: item.labels, with: state)
        let patch = GitHubIssuePatch(
            labels: labels,
            state: state
        )

        do {
            let updated = try await service.updateIssue(
                repository: item.repository,
                issueNumber: item.issueNumber,
                patch: patch
            )
            upsert(updated)
            try cache.replaceWorkItems(items)
            statusMessage = "Updated \(updated.issueReference) to \(state.title)."
        } catch {
            logger.error("Failed to update work item: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func workItem(for reference: WorkReference) -> WorkItem? {
        items.first { $0.reference == reference }
    }

    private func upsert(_ item: WorkItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }

        items.sort { lhs, rhs in
            if lhs.priority.rank != rhs.priority.rank {
                return lhs.priority.rank < rhs.priority.rank
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func replacingStatusLabels(in labels: [String], with state: WorkState) -> [String] {
        var result = labels.filter { label in
            !label.lowercased().hasPrefix("status:")
        }
        result.append(state.labelValue)
        return Array(Set(result)).sortedCaseInsensitive()
    }
}
