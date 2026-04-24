import AgentBoardCore
import SwiftUI

private enum WorkLayoutMode: String, CaseIterable, Identifiable {
    case board
    case list

    var id: String { rawValue }
}

struct WorkScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var layoutMode: WorkLayoutMode = .board
    @State private var selectedItem: WorkItem?
    @State private var isPresentingCreate = false
    @State private var selectedRepo: String = "all"

    var body: some View {
        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 14) {
                header

                filterBar

                if filteredItems.isEmpty {
                    EmptyStateCard(
                        title: "No work items",
                        message: appModel.workStore.statusMessage
                            ?? "Connect a GitHub token and repository in Settings.",
                        systemImage: "tray"
                    )
                } else if layoutMode == .board {
                    boardLayout
                } else {
                    listLayout
                }
            }
            .padding(24)
        }
        .navigationTitle("Work")
        .refreshable {
            await appModel.workStore.refresh()
        }
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WORK".uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(BoardPalette.gold)
                Text("GitHub Issues")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 10) {
                Picker("Layout", selection: $layoutMode) {
                    ForEach(WorkLayoutMode.allCases) { mode in
                        Image(systemName: mode == .board ? "square.grid.2x2" : "list.bullet")
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 100)

                HStack(spacing: 8) {
                    Button("Refresh") {
                        Task { await appModel.workStore.refresh() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button("New Issue") {
                        isPresentingCreate = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BoardPalette.cobalt)
                    .disabled(!appModel.settingsStore.isGitHubConfigured)
                }
            }
        }
    }

    private var filterBar: some View {
        BoardSurface {
            HStack(spacing: 12) {
                TextField("Search issues, labels, references…", text: Bindable(appModel.workStore).searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.24)))

                if appModel.settingsStore.repositories.count > 1 {
                    Picker("Repo", selection: $selectedRepo) {
                        Text("All repos").tag("all")
                        ForEach(appModel.settingsStore.repositories) { repo in
                            Text(repo.shortName).tag(repo.fullName)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(.white)
                    .tint(.white)
                }

                Text("\(filteredItems.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BoardPalette.paper.opacity(0.78))
            }
        }
    }

    private var boardLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(groupedFilteredItems, id: \.state) { column in
                    BoardSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                WorkStatusPill(state: column.state)
                                Spacer()
                                Text("\(column.items.count)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }

                            if column.items.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(BoardPalette.paper.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(column.items) { item in
                                    WorkCard(item: item) { selectedItem = item }
                                }
                            }
                        }
                        .frame(width: 300, alignment: .topLeading)
                    }
                }
            }
            .padding(.trailing, 4)
        }
    }

    private var listLayout: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    WorkCard(item: item) { selectedItem = item }
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
        BoardSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.issueReference)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BoardPalette.gold)
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }

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
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.subheadline)
                        .foregroundStyle(BoardPalette.paper.opacity(0.78))
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
                        .foregroundStyle(BoardPalette.paper.opacity(0.68))
                    Spacer()
                    Text(item.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(BoardPalette.paper.opacity(0.68))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
