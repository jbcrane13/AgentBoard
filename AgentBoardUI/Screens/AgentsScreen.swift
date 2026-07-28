import AgentBoardCore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) var appModel
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
    /// The kanban column currently targeted by a drag (pre-drop affordance).
    /// Internal so the undo helpers in `AgentsScreen+Undo.swift` can mutate it.
    @State var dropTargetStatus: KanbanStatus?
    /// The most recent successful task move, surfaced as a transient Undo toast.
    @State var undoOpportunity: KanbanUndoOpportunity?
    /// Inline rejection message rendered under a column header for 3s.
    /// Internal so the undo helpers in `AgentsScreen+Undo.swift` can mutate it.
    @State var dropErrorMessage: String?
    @State var dropErrorStatus: KanbanStatus?
    @State var dropErrorTask: Task<Void, Never>?

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
                            AgentHealthPill(health: summary.health)
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
                    .cardSurface(cornerRadius: 16)
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
                                dropTargetStatus = nil
                                return handleDrop(ids, to: status)
                            } isTargeted: { targeted in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    dropTargetStatus = targeted ? status : nil
                                }
                            }
                        }
                    }
                    .padding(24)
                    .overlay(alignment: .bottom) {
                        if let undoOpportunity {
                            undoToast(for: undoOpportunity)
                        }
                    }
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

                            if let dropErrorMessage, dropErrorStatus == status {
                                Text(dropErrorMessage)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.bottom, 4)
                                    .transition(.opacity)
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
                                .stroke(
                                    dropTargetStatus == status
                                        ? kanbanStatusColor(status)
                                        : AppTheme.borderSoft,
                                    lineWidth: dropTargetStatus == status ? 2 : 1
                                )
                        }
                        .dropDestination(for: KanbanTaskID.self) { ids, _ in
                            dropTargetStatus = nil
                            return handleDrop(ids, to: status)
                        } isTargeted: { targeted in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                dropTargetStatus = targeted ? status : nil
                            }
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .overlay(alignment: .bottom) {
                    if let undoOpportunity {
                        undoToast(for: undoOpportunity)
                    }
                }
            }
        }
    }

    /// Drops a dragged task onto `status`. `AgentsStore.moveTask` maps the
    /// drop onto the one legal Hermes transition (or surfaces a rejection
    /// message) — this forwards the drag payload and records an Undo
    /// opportunity for legal moves.
    private func handleDrop(_ ids: [KanbanTaskID], to status: KanbanStatus) -> Bool {
        guard let id = ids.first?.rawValue,
              let task = appModel.agentsStore.tasks.first(where: { $0.id == id }) else {
            return false
        }
        let priorStatus = task.status
        let priorTitle = task.title
        Task { @MainActor in
            await appModel.agentsStore.moveTask(id: id, to: status)
            if appModel.agentsStore.errorMessage != nil {
                surfaceDropError(appModel.agentsStore.errorMessage ?? "Transition rejected", in: status)
            } else if let statusMessage = appModel.agentsStore.statusMessage,
                      statusMessage.contains("isn't supported") || statusMessage.contains("can't be dragged")
                || statusMessage.contains("already in") || statusMessage.contains("can't be moved") {
                surfaceDropError(statusMessage, in: status)
            } else if priorStatus != status {
                undoOpportunity = KanbanUndoOpportunity(
                    taskID: id,
                    taskTitle: priorTitle,
                    priorStatus: priorStatus,
                    until: Date().addingTimeInterval(5)
                )
                scheduleUndoDismiss()
            }
        }
        return true
    }

    private func kanbanColumnHeader(status: KanbanStatus, count: Int) -> some View {
        HStack(spacing: 8) {
            StatusDot(color: kanbanStatusColor(status), size: 7)
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
                            .insetSurface(cornerRadius: 8)
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
            .cardSurface(cornerRadius: 16)
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
    case .todo: AppTheme.accentCyan
    case .ready: AppTheme.accentCyan
    case .running: AppTheme.statusSuccess
    case .blocked: AppTheme.accentOrange
    case .done: AppTheme.textSecondary
    case .archived: AppTheme.textTertiary
    }
}
