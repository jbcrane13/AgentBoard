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

    /// Tracks the data fingerprint from the last successful refresh.
    /// Used to skip SwiftUI updates when the data hasn't actually changed.
    private var lastFingerprint: String = ""

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
            lastFingerprint = fingerprint(items)
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

        // Don't flash the loading state — keep existing data visible during refresh
        isLoading = true

        await service.configure(
            repositories: settingsStore.repositories,
            token: settingsStore.githubToken.trimmedOrNil
        )

        do {
            let fresh = try await service.fetchWorkItems()
            let newFingerprint = fingerprint(fresh)

            // Only update items if the data actually changed
            if newFingerprint != lastFingerprint {
                mergeItems(fresh)
                lastFingerprint = newFingerprint
                try cache.replaceWorkItems(items)
                statusMessage = "Loaded \(items.count) GitHub issues."
            }
            // Data unchanged — skip the update entirely, no SwiftUI invalidation
            // Also skip statusMessage update to avoid unnecessary re-renders
        } catch {
            logger.error("Failed to refresh work items: \(error.localizedDescription, privacy: .public)")
            // Keep existing items visible — don't clear on transient failures
            if items.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Computes a lightweight fingerprint for change detection.
    /// Uses item IDs + status + title to detect real changes without
    /// triggering false positives from timestamp drift.
    private func fingerprint(_ items: [WorkItem]) -> String {
        items.map { "\($0.id):\($0.status.rawValue):\($0.title)" }
            .joined(separator: "|")
    }

    /// Merge fresh items with existing items, preserving stable identity.
    /// Only updates rows that changed, avoiding full-board flash on refresh.
    private func mergeItems(_ fresh: [WorkItem]) {
        var existingByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in fresh {
            existingByID[item.id] = item
        }
        // Remove items that no longer exist in the fresh fetch
        let freshIDs = Set(fresh.map(\.id))
        items = existingByID.values
            .filter { freshIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.priority.rank != rhs.priority.rank {
                    return lhs.priority.rank < rhs.priority.rank
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    public func createIssue(
        repository: ConfiguredRepository,
        title: String,
        body: String,
        labels: [String] = [],
        assignees: [String] = [],
        milestone: Int? = nil
    ) async {
        errorMessage = nil
        statusMessage = nil
        guard settingsStore.isGitHubConfigured else {
            errorMessage = "Connect GitHub before creating issues."
            return
        }
        await service.configure(
            repositories: settingsStore.repositories,
            token: settingsStore.githubToken.trimmedOrNil
        )
        do {
            let item = try await service.createIssue(
                repository: repository,
                draft: GitHubIssueDraft(
                    title: title,
                    body: body,
                    labels: labels,
                    assignees: assignees,
                    milestone: milestone
                )
            )
            upsert(item)
            lastFingerprint = fingerprint(items)
            try cache.replaceWorkItems(items)
            errorMessage = nil
            statusMessage = "Created \(item.issueReference)."
        } catch {
            logger.error("Failed to create issue: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func updateIssue(
        _ item: WorkItem,
        title: String? = nil,
        body: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        milestone: Int? = nil,
        state: WorkState? = nil
    ) async {
        errorMessage = nil
        statusMessage = nil
        guard settingsStore.isGitHubConfigured else {
            errorMessage = "Connect GitHub before updating issues."
            return
        }
        await service.configure(
            repositories: settingsStore.repositories,
            token: settingsStore.githubToken.trimmedOrNil
        )
        let patch = GitHubIssuePatch(
            title: title,
            body: body,
            labels: labels,
            assignees: assignees,
            milestone: milestone,
            state: state
        )
        do {
            let updated = try await service.updateIssue(
                repository: item.repository,
                issueNumber: item.issueNumber,
                patch: patch
            )
            upsert(updated)
            lastFingerprint = fingerprint(items)
            try cache.replaceWorkItems(items)
            statusMessage = "Updated \(updated.issueReference)."
        } catch {
            logger.error("Failed to update issue: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
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
            lastFingerprint = fingerprint(items)
            try cache.replaceWorkItems(items)
            statusMessage = "Updated \(updated.issueReference) to \(state.title)."
        } catch {
            logger.error("Failed to update work item: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    public func closeIssue(_ item: WorkItem) async {
        await updateStatus(for: item, to: .done)
    }

    public func reopenIssue(_ item: WorkItem) async {
        await updateStatus(for: item, to: .ready)
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

    #if DEBUG
        /// Test-only helper to set items directly.
        public func setItemsForTesting(_ newItems: [WorkItem]) {
            items = newItems
        }
    #endif
}
