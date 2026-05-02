import AgentBoardCore
import SwiftUI

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

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        ZStack {
            NeuBackground()

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
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "KANBAN")
                Text("Task Board")
                    .font(.system(size: isCompact ? 34 : 30, weight: .bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                draftTitle = ""
                draftAssignee = appModel.agentsStore.summaries.first?.name ?? ""
                draftBody = ""
                draftPriority = 2
                isPresentingCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(NeuButtonTarget(isAccent: true))
        }
    }

    private var agentSummaryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(appModel.agentsStore.summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(summary.name).font(.title3.weight(.bold)).foregroundStyle(NeuPalette.textPrimary)
                            Spacer()
                            AgentHealthNeu(health: summary.health)
                        }
                        Text(summary.recentActivity)
                            .font(.caption)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NeuPalette.statusSuccess)
                                Text("\(summary.activeTaskCount)")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.horizontal.circle.fill")
                                    .foregroundStyle(NeuPalette.statusIdle)
                                Text("\(summary.activeSessionCount)")
                            }
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.textPrimary)
                    }
                    .padding(20)
                    .frame(width: 260)
                    .neuExtruded(cornerRadius: 24, elevation: 8)
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
                            if !columnTasks.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    kanbanColumnHeader(status: status, count: columnTasks.count)

                                    ForEach(columnTasks) { task in
                                        KanbanTaskRow(
                                            task: task,
                                            onTap: { selectedTask = task },
                                            onLaunch: { launchTask = task }
                                        )
                                        .accessibilityIdentifier("kanban_cell_task_\(task.id)")
                                    }
                                }
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
                                        .fill(NeuPalette.borderSoft)
                                        .frame(height: 1)
                                }

                            if columnTasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(NeuPalette.textTertiary)
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
                                        }
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                        .padding(12)
                        .background(NeuPalette.background.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(NeuPalette.borderSoft, lineWidth: 1)
                        }
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
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
                .foregroundStyle(NeuPalette.textPrimary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeuPalette.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeuPalette.inset)
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var createTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draftTitle)
                    TextField("Assigned agent", text: $draftAssignee)
                    TextField("Body", text: $draftBody, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section("Priority") {
                    Picker("Priority", selection: $draftPriority) {
                        Text("P0").tag(0)
                        Text("P1").tag(1)
                        Text("P2").tag(2)
                        Text("P3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .tint(NeuPalette.accentOrange)
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let draft = KanbanCreateDraft(
                            title: draftTitle.trimmedOrNil ?? "Untitled Task",
                            body: draftBody.trimmedOrNil,
                            assignee: draftAssignee.trimmedOrNil,
                            priority: draftPriority,
                            tenant: "agentboard"
                        )
                        Task { await appModel.agentsStore.createTask(draft) }
                        isPresentingCreateSheet = false
                    }
                    .disabled(draftTitle.trimmedOrNil == nil)
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
                        .foregroundStyle(NeuPalette.accentCyan)
                    Spacer()
                    if let tenant = task.tenant {
                        Text(tenant)
                            .font(.caption2.monospaced())
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .neuRecessed(cornerRadius: 8, depth: 2)
                    }
                }

                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)

                if let body = task.body, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text(task.displayAssignee).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(NeuPalette.accentOrange)

                    Spacer()

                    Text(task.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(NeuPalette.textTertiary)
                }
            }
            .padding(20)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onLaunch {
                Button { onLaunch() } label: { Label("Launch Session", systemImage: "bolt.fill") }
                Divider()
            }
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
        .alert("Archive Task", isPresented: $showDeleteConfirm) {
            Button("Archive", role: .destructive) { Task { await appModel.agentsStore.archiveTask(id: task.id) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Helpers

@MainActor
private func kanbanStatusColor(_ status: KanbanStatus) -> Color {
    switch status {
    case .triage: Color.gray
    case .todo: NeuPalette.statusIdle
    case .ready: NeuPalette.accentCyan
    case .running: NeuPalette.statusSuccess
    case .blocked: NeuPalette.accentOrange
    case .done: NeuPalette.textSecondary
    case .archived: NeuPalette.textTertiary
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
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuRecessed(cornerRadius: 12, depth: 3)
    }

    private var healthColor: Color {
        switch health {
        case .online: NeuPalette.statusSuccess
        case .idle: NeuPalette.statusIdle
        case .warning: NeuPalette.accentOrange
        case .offline: .red
        }
    }
}
