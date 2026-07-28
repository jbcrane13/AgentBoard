import AgentBoardCore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

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
    @SceneStorage("work.selectedRepository") private var selectedRepo: String = "all"
    /// The column currently being hovered by a drag (`isTargeted`), used to
    /// render the pre-drop affordance (semantic border + transition caption).
    @State private var dropTargetColumn: WorkBoardColumn?
    /// The most recent successful drop, surfaced as a transient Undo toast.
    @State private var undoOpportunity: UndoOpportunity?
    /// Inline rejection message rendered under a column header for 3s after
    /// the backend refuses a transition.
    @State private var dropErrorMessage: String?
    @State private var dropErrorColumn: WorkBoardColumn?
    @State private var dropErrorTask: Task<Void, Never>?

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
            AppBackground()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, isCompact ? 22 : 28)
                    .padding(.top, isCompact ? 16 : 14)
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("work_section_header")

                // macOS always shows board layout; status banner shown when empty
                if isMac || (!isCompact && layoutMode == .board) {
                    if let statusMessage = appModel.workStore.statusMessage, filteredItems.isEmpty {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
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
            CreateIssueSheet(initialRepository: selectedCreateRepository)
                .environment(appModel)
        }
        .onChange(of: appModel.settingsStore.repositories) { _, repositories in
            guard selectedRepo != "all",
                  !repositories.contains(where: { $0.fullName == selectedRepo }) else {
                return
            }
            selectedRepo = "all"
        }
        .accessibilityIdentifier("screen_work")
    }

    private var filteredItems: [WorkItem] {
        let base = appModel.workStore.filteredItems
        guard selectedRepo != "all" else { return base }
        return base.filter { $0.repository.fullName == selectedRepo }
    }

    private var selectedCreateRepository: ConfiguredRepository? {
        if selectedRepo == "all" {
            return appModel.settingsStore.repositories.count == 1
                ? appModel.settingsStore.repositories.first
                : nil
        }

        return appModel.settingsStore.repositories.first { $0.fullName == selectedRepo }
    }

    private var groupedFilteredItems: [(column: WorkBoardColumn, items: [WorkItem])] {
        WorkBoardColumn.allCases.map { column in
            (column, filteredItems.filter { WorkBoardColumn.column(for: $0.status) == column })
        }
    }

    private var statusCounts: (open: Int, inProgress: Int, done: Int) {
        filteredItems.reduce(into: (open: 0, inProgress: 0, done: 0)) { counts, item in
            switch WorkBoardColumn.column(for: item.status) {
            case .todo: counts.open += 1
            case .inProgress: counts.inProgress += 1
            case .resolved: counts.done += 1
            }
        }
    }

    private var header: some View {
        @Bindable var workStore = appModel.workStore
        let counts = statusCounts

        return HStack(spacing: 12) {
            filterRepositoryPicker
                .frame(minWidth: 140)

            if !isCompact {
                HStack(spacing: 10) {
                    statChip(
                        label: "Open",
                        count: counts.open,
                        color: AppTheme.accentCyan
                    )
                    statChip(
                        label: "In Progress",
                        count: counts.inProgress,
                        color: AppTheme.accentOrange
                    )
                    statChip(
                        label: "Done",
                        count: counts.done,
                        color: AppTheme.accentGreen
                    )
                }
            }

            Spacer()

            if isCompact {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Search")
                    .accessibilityIdentifier("work_button_search")
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Search issues…", text: $workStore.searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: 180)
                        .accessibilityIdentifier("work_textfield_search")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                isPresentingCreate = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.accentForeground)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentCyan)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.borderSoft, lineWidth: 0.5))
                    .shadow(color: AppTheme.shadowDark.opacity(0.4), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(!appModel.settingsStore.isGitHubConfigured)
            .help("Create new issue")
            .accessibilityIdentifier("work_button_create_issue")
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
                .pickerStyle(.menu)
                .tint(AppTheme.accentOrange)
                .accessibilityIdentifier("work_picker_repository")
            } else {
                AgentBoardPill(text: "All repos", color: AppTheme.accentOrange)
            }
        }
    }

    private func statChip(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: color, size: 7)
            Text("\(count)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var boardLayout: some View {
        GeometryReader { proxy in
            let columnWidth: CGFloat = 170
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(groupedFilteredItems, id: \.column) { column in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                StatusDot(color: workBoardColumnColor(column.column), size: 7)
                                Text(column.column.title.uppercased())
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("\(column.items.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.inset)
                                    .clipShape(Capsule())
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(AppTheme.borderSoft)
                                    .frame(height: 1)
                            }

                            boardColumnContent(for: column)
                        }
                        .frame(width: columnWidth, height: proxy.size.height - 28, alignment: .topLeading)
                        .padding(12)
                        .background(AppTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    dropTargetColumn == column.column
                                        ? workBoardColumnColor(column.column)
                                        : AppTheme.border,
                                    lineWidth: dropTargetColumn == column.column ? 2 : 1
                                )
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
                .padding(.horizontal, 28)
                .overlay(alignment: .bottom) {
                    if let undoOpportunity {
                        undoToast(for: undoOpportunity)
                    }
                }
            }
        }
    }

    private func boardColumnContent(for column: (column: WorkBoardColumn, items: [WorkItem])) -> some View {
        VStack(spacing: 8) {
            if let dropErrorMessage, dropErrorColumn == column.column {
                Text(dropErrorMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
            if column.items.isEmpty {
                Spacer()
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(column.items) { item in
                            WorkCard(item: item) { selectedItem = item }
                                .draggable(WorkItemID(item.id))
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .accessibilityIdentifier("work_column_\(column.column.rawValue)")
        .dropDestination(for: WorkItemID.self) { ids, _ in
            dropTargetColumn = nil
            guard let id = ids.first?.rawValue,
                  let item = filteredItems.first(where: { $0.id == id }) else {
                return false
            }
            let priorStatus = item.status
            let targetState = column.column.dropTargetState

            Task { @MainActor in
                await appModel.workStore.updateStatus(for: item, to: targetState)
                if appModel.workStore.errorMessage != nil {
                    surfaceDropError(appModel.workStore.errorMessage ?? "Transition rejected", in: column.column)
                } else if item.status != targetState {
                    // Optimistically no-op (e.g. same-status drop); no toast.
                } else {
                    undoOpportunity = UndoOpportunity(
                        itemID: item.id,
                        priorStatus: priorStatus,
                        until: Date().addingTimeInterval(5)
                    )
                    scheduleUndoDismiss()
                }
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                dropTargetColumn = targeted ? column.column : nil
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
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 8)

                ForEach(filteredItems) { item in
                    WorkCard(item: item) { selectedItem = item }
                }
            }
            .padding(isCompact ? 16 : 24)
        }
    }
}

private struct WorkCard: View {
    let item: WorkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(item.issueReference)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.accentCyan)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        if item.status == .blocked {
                            Text("Blocked")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppTheme.accentCoral)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentCoral.opacity(0.15))
                                .clipShape(Capsule())
                                .accessibilityIdentifier("work_badge_blocked_\(item.id)")
                        }
                        StatusDot(color: workStateColor(item.status))
                        PriorityFlag(priority: item.priority)
                    }
                }

                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !item.bodySummary.isEmpty {
                    Text(item.bodySummary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    HStack(spacing: -8) {
                        if item.assignees.isEmpty {
                            Circle()
                                .fill(AppTheme.background)
                                .frame(width: 24, height: 24)
                                .overlay(Image(systemName: "person").font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary))
                        } else {
                            ForEach(Array(item.assignees.prefix(3).enumerated()), id: \.offset) { index, assignee in
                                Circle()
                                    .fill(AppTheme.surface)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Text(String(assignee.prefix(1).uppercased()))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                    )
                                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                                    .zIndex(Double(3 - index))
                            }
                        }
                    }

                    Spacer()
                    Text(item.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(10)
            .cardSurface(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private func workStateColor(_ state: WorkState) -> Color {
    switch state {
    case .ready: AppTheme.accentCyan
    case .inProgress: AppTheme.accentOrange
    case .blocked: AppTheme.accentCoral
    case .review: .purple
    case .done: AppTheme.accentGreen
    }
}

@MainActor
private func workBoardColumnColor(_ column: WorkBoardColumn) -> Color {
    switch column {
    case .todo: AppTheme.accentCyan
    case .inProgress: AppTheme.accentOrange
    case .resolved: AppTheme.accentGreen
    }
}

// MARK: - Drag undo / error feedback

private struct UndoOpportunity: Identifiable {
    let id: String
    let itemID: String
    let priorStatus: WorkState
    let until: Date

    init(itemID: String, priorStatus: WorkState, until: Date) {
        self.id = "\(itemID)-\(until.timeIntervalSince1970)"
        self.itemID = itemID
        self.priorStatus = priorStatus
        self.until = until
    }
}

extension WorkScreen {
    /// The transient Undo capsule pinned to the bottom of the board area.
    @ViewBuilder
    fileprivate func undoToast(for opportunity: UndoOpportunity) -> some View {
        HStack(spacing: 10) {
            Text("Moved — undo?")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
            Button("Undo") {
                revertUndo(opportunity)
            }
            .buttonStyle(AppButtonStyle(isAccent: true))
            .accessibilityIdentifier("work_button_undo_move")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: 320)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    fileprivate func scheduleUndoDismiss() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if let opportunity = undoOpportunity, Date() >= opportunity.until {
                withAnimation { undoOpportunity = nil }
            }
        }
    }

    fileprivate func revertUndo(_ opportunity: UndoOpportunity) {
        guard let item = appModel.workStore.items.first(where: { $0.id == opportunity.itemID }) else {
            undoOpportunity = nil
            return
        }
        let prior = opportunity.priorStatus
        undoOpportunity = nil
        Task { @MainActor in
            await appModel.workStore.updateStatus(for: item, to: prior)
        }
    }

    fileprivate func surfaceDropError(_ message: String, in column: WorkBoardColumn) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dropErrorMessage = message
            dropErrorColumn = column
        }
        dropErrorTask?.cancel()
        dropErrorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation { dropErrorMessage = nil }
            }
        }
    }
}

private struct WorkItemID: Codable, Hashable, Transferable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}
