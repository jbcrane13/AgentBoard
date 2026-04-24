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
        Group {
            if appModel.agentsStore.tasks.isEmpty, appModel.agentsStore.summaries.isEmpty {
                EmptyStateCard(
                    title: "No agent activity yet",
                    message: appModel.agentsStore.statusMessage
                        ??
                        "Start the companion service and point Settings at it to watch tasks and live execution state.",
                    systemImage: "person.3.sequence"
                )
            } else {
                if isCompact {
                    compactTaskList
                } else {
                    kanbanBoard
                }
            }
        }
        .navigationTitle("Agents")
        .refreshable {
            await appModel.agentsStore.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
                .disabled(appModel.workStore.items.isEmpty)
                .accessibilityIdentifier("agents_button_new_task")
            }
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

    private var kanbanBoard: some View {
        VStack(spacing: 0) {
            agentSummaryRail
                .padding()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(groupedTasks, id: \.state) { column in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(column.state.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(columnTint(for: column.state))
                                Spacer()
                                Text("\(column.tasks.count)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            if column.tasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(column.tasks) { task in
                                            TaskCard(task: task) {
                                                selectedTask = task
                                            }
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
    }

    private var compactTaskList: some View {
        List {
            if !appModel.agentsStore.summaries.isEmpty {
                Section("Active Agents") {
                    ForEach(appModel.agentsStore.summaries) { summary in
                        AgentSummaryRow(summary: summary)
                    }
                }
            }

            ForEach(AgentTaskState.allCases) { state in
                let tasks = appModel.agentsStore.tasks.filter { $0.status == state }
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            TaskListRow(task: task) { selectedTask = task }
                                .accessibilityIdentifier("agents_cell_task_\(task.id)")
                        }
                    } header: {
                        HStack {
                            Text(state.title)
                                .foregroundStyle(columnTint(for: state))
                            Spacer()
                            Text("\(tasks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var agentSummaryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(appModel.agentsStore.summaries) { summary in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(summary.name).font(.headline)
                                Spacer()
                                AgentHealthPill(health: summary.health)
                            }
                            Text(summary.recentActivity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Label("\(summary.activeTaskCount)", systemImage: "checkmark.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                Label("\(summary.activeSessionCount)", systemImage: "bolt.horizontal.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(16)
                    .frame(width: 240)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func columnTint(for state: AgentTaskState) -> Color {
        switch state {
        case .backlog: Color.secondary
        case .inProgress: Color.blue
        case .blocked: Color.red
        case .done: Color.green
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

private struct AgentSummaryRow: View {
    let summary: AgentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.name).font(.headline)
                Spacer()
                AgentHealthPill(health: summary.health)
            }
            Text(summary.recentActivity)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label("\(summary.activeTaskCount) Tasks", systemImage: "checkmark.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                Label("\(summary.activeSessionCount) Sessions", systemImage: "bolt.horizontal.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TaskListRow: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: AgentTask
    let onTap: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.workItem.issueReference)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    PriorityPill(priority: task.priority)
                }

                Text(task.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    BoardChip(label: task.assignedAgent, systemImage: "person.fill", tint: .orange)
                    Spacer()
                    if let sessionID = task.sessionID {
                        Text(sessionID)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 100)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .contextMenu {
            Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
        }
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await appModel.agentsStore.deleteTask(id: task.id) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct TaskCard: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: AgentTask
    let onTap: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(task.workItem.issueReference)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("Edit") { onTap() }
                        Divider()
                        Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    PriorityPill(priority: task.priority)
                    BoardChip(label: task.assignedAgent, systemImage: "person.fill", tint: .orange)
                }

                HStack {
                    if let sessionID = task.sessionID {
                        Text(sessionID)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(task.updatedAt, style: .relative)
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
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await appModel.agentsStore.deleteTask(id: task.id) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}
