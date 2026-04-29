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
                    .padding(.horizontal, isCompact ? 22 : 28)
                    .padding(.top, isCompact ? 20 : 20)
                    .padding(.bottom, 14)
                    .accessibilityIdentifier("work_section_header")

                // macOS always shows board layout; status banner shown when empty
                if isMac || (!isCompact && layoutMode == .board) {
                    if let statusMessage = appModel.workStore.statusMessage, filteredItems.isEmpty {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }
                    boardLayout
                } else if filteredItems.isEmpty {
                    EmptyStateCard(
                        title: "No work items",
                        message: appModel.workStore
                            .statusMessage ?? "Connect a GitHub token and repository in Settings.",
                        systemImage: "tray"
                    )
                    .padding(isCompact ? 16 : 24)
                } else {
                    listLayout
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
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
        .accessibilityIdentifier("screen_work")
    }

    private var filteredItems: [WorkItem] {
        let base = appModel.workStore.filteredItems
        guard selectedRepo != "all" else { return base }
        return base.filter { $0.repository.fullName == selectedRepo }
    }

    private var groupedFilteredItems: [(state: WorkState, items: [WorkItem])] {
        // Show Ready, In Progress, Review, Done columns (skip Blocked)
        [.ready, .inProgress, .review, .done].map { state in
            (state, filteredItems.filter { $0.status == state })
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "WORKSPACE")
                Text("GitHub Issues")
                    .font(.system(size: isCompact ? 34 : 30, weight: .bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            HStack(spacing: 8) {
                filterRepositoryPicker
                Button {} label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
                .buttonStyle(NeuButtonTarget(isAccent: false))

                Button { isPresentingCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(NeuButtonTarget(isAccent: true))
                .disabled(!appModel.settingsStore.isGitHubConfigured)
            }
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
            } else {
                AgentBoardPill(text: "All repos", color: NeuPalette.accentOrange)
            }
        }
    }

    private var boardLayout: some View {
        GeometryReader { proxy in
            let columnWidth = max((proxy.size.width - 32) / 3, 190)
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(groupedFilteredItems, id: \.state) { column in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(workStateColor(column.state))
                                    .frame(width: 7, height: 7)
                                    .shadow(color: workStateColor(column.state).opacity(0.6), radius: 8)
                                Text(column.state.designColumnTitle)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundStyle(NeuPalette.textPrimary)
                                Text("\(column.items.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(NeuPalette.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(NeuPalette.inset)
                                    .clipShape(Capsule())
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(NeuPalette.textTertiary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(NeuPalette.borderSoft)
                                    .frame(height: 1)
                            }

                            if column.items.isEmpty {
                                Spacer()
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(NeuPalette.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Spacer()
                            } else {
                                ScrollView(showsIndicators: false) {
                                    LazyVStack(spacing: 8) {
                                        ForEach(column.items) { item in
                                            WorkCardNeu(item: item) { selectedItem = item }
                                        }
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .frame(width: columnWidth, height: proxy.size.height - 28, alignment: .topLeading)
                        .padding(12)
                        .background(NeuPalette.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(NeuPalette.border, lineWidth: 1)
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
                .padding(.horizontal, 28)
            }
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
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NeuPalette.accentCyanBright)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        WorkStatusNeu(state: item.status)
                        PriorityNeu(priority: item.priority)
                    }
                }

                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(NeuPalette.textTertiary)
                        .lineLimit(1)
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
            .padding(10)
            .neuExtruded(cornerRadius: 14, elevation: 7)
        }
        .buttonStyle(.plain)
    }
}

struct WorkStatusNeu: View {
    let state: WorkState
    var body: some View {
        Circle()
            .fill(workStateColor(state))
            .frame(width: 10, height: 10)
    }
}

struct PriorityNeu: View {
    let priority: WorkPriority
    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 10))
            .foregroundStyle(priorityColor(priority))
    }
}

@MainActor
private func workStateColor(_ state: WorkState) -> Color {
    switch state {
    case .ready: NeuPalette.statusBlue
    case .inProgress: NeuPalette.accentOrange
    case .blocked: NeuPalette.accentCoral
    case .review: .purple
    case .done: NeuPalette.accentGreen
    }
}

@MainActor
private func priorityColor(_ priority: WorkPriority) -> Color {
    switch priority {
    case .p0: NeuPalette.accentCoral
    case .p1: NeuPalette.accentCoral.opacity(0.82)
    case .p2: NeuPalette.accentOrange
    case .p3: NeuPalette.textTertiary
    }
}
