import AgentBoardCore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var isPresentingCreateSheet = false
    @State private var selectedTask: KanbanTask?
    @State private var launchTask: KanbanTask?
    @State private var draftTitle = ""
    @State private var draftAssignee = ""
    @State private var draftBody = ""
    @State private var draftPriority = 2
    @State private var isCreating = false
    @State private var createError: String?
    /// Increments whenever a create attempt is started, cancelled, or the sheet
    /// is reopened. The in-flight Task captures the value at launch and bails
    /// out before mutating view state if the counter has moved on, so a
    /// dismissed-then-reopened sheet can't be slammed shut by a stale write.
    @State private var createGeneration = 0

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                if appModel.agentsStore.tasks.isEmpty {
                    EmptyStateCard(
                        title: "No kanban tasks yet",
                        message: appModel.agentsStore.statusMessage
                            ??
                            "Create tasks here or via `hermes kanban create`. The gateway dispatcher will pick up ready tasks automatically.",
                        systemImage: "square.grid.3x3.topleft.filled"
                    )
                    .padding(isCompact ? 16 : 24)
                } else {
                    taskList
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
        .refreshable {
            await appModel.agentsStore.refresh()
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
                .environment(appModel)
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            createTaskSheet
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $launchTask) { task in
            LaunchSessionSheet(task: task)
                .environment(appModel)
        }
        .accessibilityIdentifier("screen_kanban")
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "KANBAN")
                Text("Task Board")
                    .font(.system(size: isCompact ? 34 : 30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                draftTitle = ""
                draftAssignee = appModel.agentsStore.summaries.first?.name ?? ""
                draftBody = ""
                draftPriority = 2
                createError = nil
                isCreating = false
                createGeneration &+= 1
                isPresentingCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(AppButtonStyle(isAccent: true))
            .accessibilityIdentifier("kanban_button_new_task")
        }
    }

    private var agentSummaryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(appModel.agentsStore.summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(summary.name).font(.title3.weight(.bold)).foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            AgentHealthNeu(health: summary.health)
                        }
                        Text(summary.recentActivity)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.statusSuccess)
                            Text("\(summary.activeTaskCount)")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(20)
                    .frame(width: 260)
                    .cardSurface(cornerRadius: 24, elevation: 8)
                }
            }
            .padding(24)
        }
    }

    private var taskList: some View {
        Group {
            if isCompact {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        if !appModel.agentsStore.summaries.isEmpty {
                            agentSummaryRail
                        }

                        ForEach(KanbanStatus.boardColumns, id: \.self) { status in
                            let columnTasks = appModel.agentsStore.tasks.filter { $0.status == status }
                            VStack(alignment: .leading, spacing: 12) {
                                kanbanColumnHeader(status: status, count: columnTasks.count)

                                if columnTasks.isEmpty {
                                    compactDropzonePlaceholder(status: status)
                                } else {
                                    ForEach(columnTasks) { task in
                                        KanbanTaskRow(
                                            task: task,
                                            onTap: { selectedTask = task },
                                            onLaunch: { launchTask = task }
                                        )
                                        .accessibilityIdentifier("kanban_cell_task_\(task.id)")
                                        .draggable(KanbanTaskID(task.id))
                                    }
                                }
                            }
                            .dropDestination(for: KanbanTaskID.self) { ids, _ in
                                handleDrop(ids, to: status)
                            }
                        }
                    }
                    .padding(24)
                }
            } else {
                VStack(spacing: 0) {
                    if !appModel.agentsStore.summaries.isEmpty {
                        agentSummaryRail
                    }
                    taskBoardLayout
                }
            }
        }
    }

    private var taskBoardLayout: some View {
        GeometryReader { proxy in
            let columnWidth = max((proxy.size.width - 42) / CGFloat(KanbanStatus.boardColumns.count), 140)
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(KanbanStatus.boardColumns, id: \.self) { status in
                        let columnTasks = appModel.agentsStore.tasks.filter { $0.status == status }
                        VStack(alignment: .leading, spacing: 10) {
                            kanbanColumnHeader(status: status, count: columnTasks.count)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 10)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(AppTheme.borderSoft)
                                        .frame(height: 1)
                                }

                            if columnTasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 24)
                            } else {
                                ScrollView(showsIndicators: false) {
                                    LazyVStack(spacing: 8) {
                                        ForEach(columnTasks) { task in
                                            KanbanTaskRow(
                                                task: task,
                                                onTap: { selectedTask = task },
                                                onLaunch: { launchTask = task }
                                            )
                                            .accessibilityIdentifier("kanban_cell_task_\(task.id)")
                                            .draggable(KanbanTaskID(task.id))
                                        }
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                        .padding(12)
                        .background(AppTheme.background.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.borderSoft, lineWidth: 1)
                        }
                        .dropDestination(for: KanbanTaskID.self) { ids, _ in
                            handleDrop(ids, to: status)
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    /// Drops a dragged task onto `status`. `AgentsStore.moveTask` maps the
    /// drop onto the one legal Hermes transition (or surfaces a rejection
    /// message) — this just forwards the drag payload.
    private func handleDrop(_ ids: [KanbanTaskID], to status: KanbanStatus) -> Bool {
        guard let id = ids.first?.rawValue else { return false }
        Task { @MainActor in
            await appModel.agentsStore.moveTask(id: id, to: status)
        }
        return true
    }

    private func kanbanColumnHeader(status: KanbanStatus, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kanbanStatusColor(status))
                .frame(width: 7, height: 7)
                .shadow(color: kanbanStatusColor(status).opacity(0.6), radius: 8)
            Text(status.title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.inset)
                .clipShape(Capsule())
            Spacer()
        }
    }

    /// Slim drop target for an empty compact-layout column. Keeps the section
    /// present (and droppable) even with no tasks, without the tall empty
    /// box the wide layout's "None" placeholder uses.
    private func compactDropzonePlaceholder(status: KanbanStatus) -> some View {
        Text("Drop tasks here")
            .font(.caption)
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.borderSoft, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .accessibilityIdentifier("kanban_dropzone_\(status.rawValue)")
    }

    private var createTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draftTitle)
                        .accessibilityIdentifier("kanban_textfield_title")
                    Picker("Assigned agent", selection: $draftAssignee) {
                        Text("Unassigned").tag("")
                        ForEach(appModel.agentsStore.summaries) { agent in
                            Text(agent.name).tag(agent.name)
                        }
                    }
                    .accessibilityIdentifier("kanban_picker_assignee")
                    TextField("Body", text: $draftBody, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityIdentifier("kanban_textfield_body")
                }

                Section("Priority") {
                    Picker("Priority", selection: $draftPriority) {
                        Text("P0").tag(0)
                        Text("P1").tag(1)
                        Text("P2").tag(2)
                        Text("P3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.accentOrange)
                    .accessibilityIdentifier("kanban_picker_priority")
                }

                if let error = createError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.yellow)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Abandon any in-flight create so its completion can't
                        // dismiss a sheet the user has since reopened.
                        createGeneration &+= 1
                        isCreating = false
                        isPresentingCreateSheet = false
                    }
                    .accessibilityIdentifier("kanban_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createGeneration &+= 1
                        let generation = createGeneration
                        isCreating = true
                        createError = nil
                        let draft = KanbanCreateDraft(
                            title: draftTitle.trimmedOrNil ?? "Untitled Task",
                            body: draftBody.trimmedOrNil,
                            assignee: draftAssignee.trimmedOrNil,
                            priority: draftPriority,
                            tenant: "agentboard"
                        )
                        Task {
                            await appModel.agentsStore.createTask(draft)
                            // Bail if the user cancelled, reopened the sheet,
                            // or kicked off another attempt while we awaited.
                            guard generation == createGeneration else { return }
                            if appModel.agentsStore.errorMessage != nil {
                                createError = appModel.agentsStore.errorMessage
                                isCreating = false
                            } else {
                                isCreating = false
                                isPresentingCreateSheet = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .controlSize(.small)
                            }
                            Text(isCreating ? "Creating…" : "Create")
                        }
                    }
                    .disabled(draftTitle.trimmedOrNil == nil || isCreating)
                    .accessibilityIdentifier("kanban_button_create")
                }
            }
            .navigationTitle("New Kanban Task")
            .agentBoardNavigationBarTitleInline()
        }
    }
}

// MARK: - Task Row

private struct KanbanTaskRow: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: KanbanTask
    let onTap: () -> Void
    var onLaunch: (() -> Void)?
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(task.displayPriority)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accentCyan)
                    Spacer()
                    if let tenant = task.tenant {
                        Text(tenant)
                            .font(.caption2.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .insetSurface(cornerRadius: 8, depth: 2)
                    }
                }

                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)

                if let body = task.body, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text(task.displayAssignee).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.accentOrange)

                    Spacer()

                    Text(task.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(20)
            .cardSurface(cornerRadius: 24, elevation: 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onLaunch {
                Button { onLaunch() } label: { Label("Launch Session", systemImage: "bolt.fill") }
                    .accessibilityIdentifier("kanban_menuitem_launch_session")
                Divider()
            }
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .accessibilityIdentifier("kanban_menuitem_archive")
        }
        .alert("Archive Task", isPresented: $showDeleteConfirm) {
            Button("Archive", role: .destructive) { Task { await appModel.agentsStore.archiveTask(id: task.id) } }
                .accessibilityIdentifier("kanban_alert_button_archive")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("kanban_alert_button_cancel")
        }
    }
}

// MARK: - Drag Payload

private struct KanbanTaskID: Codable, Hashable, Transferable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}

// MARK: - Helpers

@MainActor
private func kanbanStatusColor(_ status: KanbanStatus) -> Color {
    switch status {
    case .triage: Color.gray
    case .todo: AppTheme.statusIdle
    case .ready: AppTheme.accentCyan
    case .running: AppTheme.statusSuccess
    case .blocked: AppTheme.accentOrange
    case .done: AppTheme.textSecondary
    case .archived: AppTheme.textTertiary
    }
}

struct AgentHealthNeu: View {
    let health: AgentHealthStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(healthColor)
                .frame(width: 8, height: 8)
            Text(health.title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .insetSurface(cornerRadius: 12, depth: 3)
    }

    private var healthColor: Color {
        switch health {
        case .online: AppTheme.statusSuccess
        case .idle: AppTheme.statusIdle
        case .warning: AppTheme.accentOrange
        case .offline: .red
        }
    }
}
