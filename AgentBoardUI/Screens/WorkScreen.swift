import AgentBoardCore
import SwiftUI

private enum WorkLayoutMode: String, CaseIterable, Identifiable {
    case board
    case list

    var id: String {
        rawValue
    }
}

struct WorkScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var layoutMode: WorkLayoutMode = .board
    @State private var selectedItem: WorkItem?
    @State private var isPresentingCreate = false
    @State private var selectedRepo: String = "all"

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                EmptyStateCard(
                    title: "No work items",
                    message: appModel.workStore.statusMessage ?? "Connect a GitHub token and repository in Settings.",
                    systemImage: "tray"
                )
            } else if !isCompact, layoutMode == .board {
                boardLayout
            } else {
                listLayout
            }
        }
        .navigationTitle("Work")
        .refreshable {
            await appModel.workStore.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!appModel.settingsStore.isGitHubConfigured)
            }
            ToolbarItem(placement: .topBarLeading) {
                if !isCompact {
                    Picker("Layout", selection: $layoutMode) {
                        ForEach(WorkLayoutMode.allCases) { mode in
                            Image(systemName: mode == .board ? "square.grid.2x2" : "list.bullet")
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .searchable(text: Bindable(appModel.workStore).searchText, prompt: "Search issues, labels…")
        .sheet(item: $selectedItem) { item in
            IssueDetailSheet(item: item)
                .environment(appModel)
        }
        .sheet(isPresented: $isPresentingCreate) {
            CreateIssueSheet()
                .environment(appModel)
        }
    }

    private var filteredItems: [WorkItem] {
        let base = appModel.workStore.filteredItems
        guard selectedRepo != "all" else { return base }
        return base.filter { $0.repository.fullName == selectedRepo }
    }

    private var groupedFilteredItems: [(state: WorkState, items: [WorkItem])] {
        WorkState.allCases.map { state in
            (state, filteredItems.filter { $0.status == state })
        }
    }

    private var filterRepositoryPicker: some View {
        Group {
            if appModel.settingsStore.repositories.count > 1 {
                Picker("Repo", selection: $selectedRepo) {
                    Text("All repos").tag("all")
                    ForEach(appModel.settingsStore.repositories) { repo in
                        Text(repo.shortName).tag(repo.fullName)
                    }
                }
            }
        }
    }

    private var boardLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(groupedFilteredItems, id: \.state) { column in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            WorkStatusPill(state: column.state)
                            Spacer()
                            Text("\(column.items.count)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        if column.items.isEmpty {
                            Text("None")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(column.items) { item in
                                        WorkCard(item: item) { selectedItem = item }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 320, alignment: .topLeading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var listLayout: some View {
        List {
            Section {
                ForEach(filteredItems) { item in
                    WorkListRow(item: item) { selectedItem = item }
                }
            } header: {
                HStack {
                    filterRepositoryPicker
                        .textCase(nil)
                    Spacer()
                    Text("\(filteredItems.count) items").textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct WorkListRow: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let item: WorkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.issueReference)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        WorkStatusPill(state: item.status)
                        PriorityPill(priority: item.priority)
                    }
                }

                Text(item.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text(item.assignees.isEmpty ? "Unassigned" : item.assignees.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(item.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(WorkState.allCases) { state in
                Button(state.title) {
                    Task { await appModel.workStore.updateStatus(for: item, to: state) }
                }
            }
        }
    }
}

private struct WorkCard: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let item: WorkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(item.issueReference)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(WorkState.allCases) { state in
                            Button(state.title) {
                                Task { await appModel.workStore.updateStatus(for: item, to: state) }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    WorkStatusPill(state: item.status)
                    PriorityPill(priority: item.priority)
                }

                HStack {
                    Text(item.assignees.isEmpty ? "Unassigned" : item.assignees.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(item.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}
