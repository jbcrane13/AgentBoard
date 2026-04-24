import AgentBoardCore
import SwiftUI

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var isPresentingCreateSheet = false
    @State private var selectedTask: AgentTask?
    @State private var selectedWorkItemID: String?
    @State private var taskTitle = ""
    @State private var assignedAgent = ""
    @State private var note = ""
    @State private var status: AgentTaskState = .backlog
    @State private var priority: WorkPriority = .medium

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
                    if isCompact {
                        compactTaskList
                    } else {
                        kanbanBoard
                    }
                }
            }
        }
        .navigationBarHidden(true)
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
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AGENTS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(NeuPalette.accentCyan)
                Text("Task Board")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            Spacer()
            Button {
                assignedAgent = appModel.agentsStore.summaries.first?.name ?? "Codex"
                selectedWorkItemID = appModel.workStore.items.first?.id
                taskTitle = ""
                note = ""
                status = .backlog
                priority = .medium
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
                                    .foregroundStyle(.green)
                                Text("\(summary.activeTaskCount)")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.horizontal.circle.fill")
                                    .foregroundStyle(.blue)
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

    private var kanbanBoard: some View {
        VStack(spacing: 0) {
            agentSummaryRail

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(groupedTasks, id: \.state) { column in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(column.state.title.uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(1)
                                    .foregroundStyle(NeuPalette.textSecondary)
                                Spacer()
                                Text("\(column.tasks.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NeuPalette.textSecondary)
                            }
                            .padding(.horizontal, 4)

                            if column.tasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(NeuPalette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 24)
                            } else {
                                ScrollView(showsIndicators: false) {
                                    LazyVStack(spacing: 16) {
                                        ForEach(column.tasks) { task in
                                            TaskCardNeu(task: task) {
                                                selectedTask = task
                                            }
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
    }

    private var compactTaskList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 32) {
                if !appModel.agentsStore.summaries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVE AGENTS")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(NeuPalette.textSecondary)
                            .padding(.horizontal, 8)

                        ForEach(appModel.agentsStore.summaries) { summary in
                            AgentSummaryRowNeu(summary: summary)
                        }
                    }
                }

                ForEach(AgentTaskState.allCases) { state in
                    let tasks = appModel.agentsStore.tasks.filter { $0.status == state }
                    if !tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(state.title.uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(1)
                                    .foregroundStyle(NeuPalette.textSecondary)
                                Spacer()
                                Text("\(tasks.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NeuPalette.textSecondary)
                            }
                            .padding(.horizontal, 8)

                            ForEach(tasks) { task in
                                TaskListRowNeu(task: task) { selectedTask = task }
                                    .accessibilityIdentifier("agents_cell_task_\(task.id)")
                            }
                        }
                    }
                }
            }
            .padding(16)
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
            .navigationBarTitleDisplayMode(.inline)
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
                    .foregroundStyle(.green)
                Label("\(summary.activeSessionCount) Sessions", systemImage: "bolt.horizontal.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
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
                .fill(health == .online ? .green : health == .idle ? .blue : health == .warning ? NeuPalette
                    .accentOrange : .red)
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
}
