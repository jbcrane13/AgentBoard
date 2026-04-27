import AgentBoardCore
import SwiftUI

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var isPresentingCreateSheet = false
    @State private var selectedTask: AgentTask?
    @State private var launchTask: AgentTask?
    @State private var selectedWorkItemID: String?
    @State private var taskTitle = ""
    @State private var assignedAgent = ""
    @State private var note = ""
    @State private var status: AgentTaskState = .backlog
    @State private var priority: WorkPriority = .p2

    private var groupedTasks: [(state: AgentTaskState, tasks: [AgentTask])] {
        AgentTaskState.allCases.map { state in
            (state, appModel.agentsStore.tasks.filter { $0.status == state })
        }
    }

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

                if appModel.agentsStore.tasks.isEmpty, appModel.agentsStore.summaries.isEmpty {
                    EmptyStateCard(
                        title: "No agent activity yet",
                        message: appModel.agentsStore.statusMessage
                            ??
                            "Start the companion service and point Settings at it to watch tasks and live execution state.",
                        systemImage: "person.3.sequence"
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
                AgentBoardEyebrow(text: "AGENTS")
                Text("Task Board")
                    .font(.system(size: isCompact ? 34 : 30, weight: .bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
            Button {
                assignedAgent = appModel.agentsStore.summaries.first?.name ?? "Codex"
                selectedWorkItemID = appModel.workStore.items.first?.id
                taskTitle = ""
                note = ""
                status = .backlog
                priority = .p2
                isPresentingCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(NeuButtonTarget(isAccent: true))
            .disabled(appModel.workStore.items.isEmpty)
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

                        ForEach(AgentTaskState.allCases) { state in
                            let tasks = appModel.agentsStore.tasks.filter { $0.status == state }
                            if !tasks.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    agentColumnHeader(state: state, count: tasks.count)

                                    ForEach(tasks) { task in
                                        TaskListRowNeu(
                                            task: task,
                                            onTap: { selectedTask = task },
                                            onLaunch: { launchTask = task }
                                        )
                                        .accessibilityIdentifier("agents_cell_task_\(task.id)")
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
            let columnWidth = max((proxy.size.width - 42) / 4, 160)
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(groupedTasks, id: \.state) { column in
                        VStack(alignment: .leading, spacing: 10) {
                            agentColumnHeader(state: column.state, count: column.tasks.count)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 10)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(NeuPalette.borderSoft)
                                        .frame(height: 1)
                                }

                            if column.tasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(NeuPalette.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 24)
                            } else {
                                ScrollView(showsIndicators: false) {
                                    LazyVStack(spacing: 8) {
                                        ForEach(column.tasks) { task in
                                            TaskListRowNeu(
                                                task: task,
                                                onTap: { selectedTask = task },
                                                onLaunch: { launchTask = task }
                                            )
                                            .accessibilityIdentifier("agents_cell_task_\(task.id)")
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

    private func agentColumnHeader(state: AgentTaskState, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(agentStateColor(state))
                .frame(width: 7, height: 7)
                .shadow(color: agentStateColor(state).opacity(0.6), radius: 8)
            Text(agentColumnTitle(state))
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
                Section("Work Item") {
                    Picker("Issue", selection: $selectedWorkItemID) {
                        ForEach(appModel.workStore.items) { item in
                            Text(item.issueReference).tag(Optional(item.id))
                        }
                    }
                }

                Section("Task Settings") {
                    TextField("Task title", text: $taskTitle)
                    TextField("Assigned agent", text: $assignedAgent)
                    Picker("Status", selection: $status) {
                        ForEach(AgentTaskState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(WorkPriority.allCases) { prio in
                            Text(prio.title).tag(prio)
                        }
                    }
                    TextField("Notes", text: $note, axis: .vertical)
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let selectedWorkItemID,
                              let workItem = appModel.workStore.items.first(where: { $0.id == selectedWorkItemID })
                        else { return }

                        let draft = AgentTaskDraft(
                            workItem: workItem.reference,
                            title: taskTitle.trimmedOrNil ?? workItem.title,
                            status: status,
                            priority: priority,
                            assignedAgent: assignedAgent.trimmedOrNil ?? "Codex",
                            note: note.trimmed
                        )
                        Task { await appModel.agentsStore.createTask(draft) }
                        isPresentingCreateSheet = false
                    }
                    .disabled(selectedWorkItemID == nil)
                }
            }
            .navigationTitle("New Agent Task")
            .agentBoardNavigationBarTitleInline()
        }
    }
}

private struct AgentSummaryRowNeu: View {
    let summary: AgentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.name).font(.title3.weight(.bold)).foregroundStyle(NeuPalette.textPrimary)
                Spacer()
                AgentHealthNeu(health: summary.health)
            }
            Text(summary.recentActivity)
                .font(.subheadline)
                .foregroundStyle(NeuPalette.textSecondary)
                .lineLimit(2)
            HStack(spacing: 20) {
                Label("\(summary.activeTaskCount) Tasks", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NeuPalette.statusSuccess)
                Label("\(summary.activeSessionCount) Sessions", systemImage: "bolt.horizontal.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NeuPalette.statusIdle)
            }
        }
        .padding(20)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }
}

private struct TaskListRowNeu: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: AgentTask
    let onTap: () -> Void
    var onLaunch: (() -> Void)?
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(task.workItem.issueReference)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.accentCyan)
                    Spacer()
                    PriorityNeu(priority: task.priority)
                }

                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text(task.assignedAgent).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(NeuPalette.accentOrange)

                    Spacer()

                    if let sessionID = task.sessionID {
                        Text(sessionID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(NeuPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 100)
                    }
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
            Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
        }
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await appModel.agentsStore.deleteTask(id: task.id) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct TaskCardNeu: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: AgentTask
    let onTap: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(task.workItem.issueReference)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.accentCyan)
                    Spacer()
                    Menu {
                        Button("Edit") { onTap() }
                        Divider()
                        Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(NeuPalette.textSecondary)
                    }
                }

                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .multilineTextAlignment(.leading)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 12) {
                    PriorityNeu(priority: task.priority)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text(task.assignedAgent).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(NeuPalette.accentOrange)
                }

                HStack {
                    if let sessionID = task.sessionID {
                        Text(sessionID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(NeuPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 100)
                    }
                    Spacer()
                    Text(task.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }
            .padding(20)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
        .buttonStyle(.plain)
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await appModel.agentsStore.deleteTask(id: task.id) } }
            Button("Cancel", role: .cancel) {}
        }
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

private func agentColumnTitle(_ state: AgentTaskState) -> String {
    switch state {
    case .backlog: "BACKLOG"
    case .inProgress: "RUNNING"
    case .blocked: "REVIEW"
    case .done: "DONE"
    }
}

@MainActor
private func agentStateColor(_ state: AgentTaskState) -> Color {
    switch state {
    case .backlog: NeuPalette.textTertiary
    case .inProgress: NeuPalette.accentCyanBright
    case .blocked: NeuPalette.accentOrange
    case .done: NeuPalette.statusClosed
    }
}
