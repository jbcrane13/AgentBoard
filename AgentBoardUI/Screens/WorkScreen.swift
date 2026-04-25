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
        #if os(macOS)
            return false // macOS should be the wide Board by default, regardless of internal window size class quirks
        #else
            return hSizeClass == .compact
        #endif
    }

    private var isMac: Bool {
        #if os(macOS)
            return true
        #else
            return false
        #endif
    }

    var body: some View {
        ZStack {
            NeuBackground()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.top, isCompact ? 16 : 24)
                    .padding(.bottom, 16)

                if filteredItems.isEmpty {
                    EmptyStateCard(
                        title: "No work items",
                        message: appModel.workStore
                            .statusMessage ?? "Connect a GitHub token and repository in Settings.",
                        systemImage: "tray"
                    )
                    .padding(isCompact ? 16 : 24)
                } else if isMac || (!isCompact && layoutMode == .board) {
                    boardLayout
                } else {
                    listLayout
                }
            }
        }
        .navigationBarHidden(true)
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
                Text("WORKSPACE")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(NeuPalette.accentCyan)
                Text("GitHub Issues")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            Spacer()
            Button { isPresentingCreate = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(NeuButtonTarget(isAccent: true))
            .disabled(!appModel.settingsStore.isGitHubConfigured)
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
                .tint(NeuPalette.accentOrange)
            }
        }
    }

    private var boardLayout: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 24) {
                ForEach(groupedFilteredItems, id: \.state) { column in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(column.state.title.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)
                            Spacer()
                            Text("\(column.items.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NeuPalette.textSecondary)
                        }
                        .padding(.horizontal, 4)

                        if column.items.isEmpty {
                            Text("None")
                                .font(.subheadline)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 16) {
                                    ForEach(column.items) { item in
                                        WorkCardNeu(item: item) { selectedItem = item }
                                    }
                                }
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    .frame(width: 320, alignment: .topLeading)
                    .padding(20)
                    .neuExtruded(cornerRadius: 32, elevation: 12)
                }
            }
            .padding(24)
        }
    }

    private var listLayout: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                HStack {
                    filterRepositoryPicker
                    Spacer()
                    Text("\(filteredItems.count) items")
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
                .padding(.horizontal, 8)

                ForEach(filteredItems) { item in
                    WorkCardNeu(item: item) { selectedItem = item }
                }
            }
            .padding(isCompact ? 16 : 24)
        }
    }
}

private struct WorkCardNeu: View {
    let item: WorkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(item.issueReference)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.accentCyan)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        WorkStatusNeu(state: item.status)
                        PriorityNeu(priority: item.priority)
                    }
                }

                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    HStack(spacing: -8) {
                        if item.assignees.isEmpty {
                            Circle()
                                .fill(NeuPalette.background)
                                .frame(width: 24, height: 24)
                                .overlay(Image(systemName: "person").font(.system(size: 10))
                                    .foregroundStyle(NeuPalette.textSecondary))
                        } else {
                            ForEach(Array(item.assignees.prefix(3).enumerated()), id: \.offset) { index, assignee in
                                Circle()
                                    .fill(NeuPalette.surface)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text(String(assignee.prefix(1).uppercased()))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(NeuPalette.textPrimary)
                                    )
                                    .overlay(Circle().stroke(NeuPalette.background, lineWidth: 2))
                                    .zIndex(Double(3 - index))
                            }
                        }
                    }

                    Spacer()
                    Text(item.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }
            .padding(20)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
        .buttonStyle(.plain)
    }
}

struct WorkStatusNeu: View {
    let state: WorkState
    var body: some View {
        Circle()
            .fill(state == .done ? NeuPalette.accentCyan : state == .inProgress ? NeuPalette
                .accentOrange : state == .blocked ? .red : NeuPalette.textSecondary)
            .frame(width: 10, height: 10)
    }
}

struct PriorityNeu: View {
    let priority: WorkPriority
    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 10))
            .foregroundStyle(priority == .critical ? .red : priority == .high ? NeuPalette.accentOrange : NeuPalette
                .textSecondary)
    }
}
