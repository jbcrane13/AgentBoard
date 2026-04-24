import AgentBoardCore
import SwiftUI

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
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

    var body: some View {
        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 18) {
                header

                if appModel.agentsStore.tasks.isEmpty && appModel.agentsStore.summaries.isEmpty {
                    EmptyStateCard(
                        title: "No agent activity yet",
                        message: appModel.agentsStore.statusMessage
                            ?? "Start the companion service and point Settings at it to watch tasks and live execution state.",
                        systemImage: "person.3.sequence"
                    )
                } else {
                    if !appModel.agentsStore.summaries.isEmpty {
                        agentSummaryRail
                    }
                    kanbanBoard
                }
            }
            .padding(24)
        }
        .navigationTitle("Agents")
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerTitle
                Spacer(minLength: 20)
                headerControls
            }
            VStack(alignment: .leading, spacing: 16) {
                headerTitle
                headerControls
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AGENTS".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(BoardPalette.gold)
            Text("Task Board")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
        }
    }

    private var headerControls: some View {
        HStack(spacing: 8) {
            Button("Refresh") {
                Task { await appModel.agentsStore.refresh() }
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button("New Task") {
                assignedAgent = appModel.agentsStore.summaries.first?.name ?? "Codex"
                selectedWorkItemID = appModel.workStore.items.first?.id
                taskTitle = ""
                note = ""
                status = .backlog
                priority = .medium
                isPresentingCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(BoardPalette.coral)
            .disabled(appModel.workStore.items.isEmpty)
        }
    }

    private var agentSummaryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(appModel.agentsStore.summaries) { summary in
                    BoardSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(summary.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                AgentHealthPill(health: summary.health)
                            }
                            Text(summary.recentActivity)
                                .font(.caption)
                                .foregroundStyle(BoardPalette.paper.opacity(0.78))
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                Label("\(summary.activeTaskCount)", systemImage: "checkmark.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BoardPalette.mint)
                                Label("\(summary.activeSessionCount)", systemImage: "bolt.horizontal.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BoardPalette.cobalt)
                            }
                        }
                        .frame(width: 240, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var kanbanBoard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(groupedTasks, id: \.state) { column in
                    BoardSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(column.state.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(columnTint(for: column.state))
                                Spacer()
                                Text("\(column.tasks.count)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }

                            if column.tasks.isEmpty {
                                Text("None")
                                    .font(.subheadline)
                                    .foregroundStyle(BoardPalette.paper.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(column.tasks) { task in
                                    AgentTaskCard(task: task) {
                                        selectedTask = task
                                    }
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

    private func columnTint(for state: AgentTaskState) -> Color {
        switch state {
        case .backlog: BoardPalette.paper.opacity(0.78)
        case .inProgress: BoardPalette.cobalt
        case .blocked: BoardPalette.coral
        case .done: BoardPalette.mint
        }
    }

    private var createTaskSheet: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                Form {
                    Section("Work Item") {
                        Picker("Issue", selection: $selectedWorkItemID) {
                            ForEach(appModel.workStore.items) { item in
                                Text(item.issueReference).tag(Optional(item.id))
                            }
                        }
                    }

                    Section("Task") {
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
                .scrollContentBackground(.hidden)
            }
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
        }
    }
}

private struct AgentTaskCard: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let task: AgentTask
    let onTap: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.workItem.issueReference)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BoardPalette.gold)
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)

                    Menu {
                        Button("Edit") { onTap() }
                        Divider()
                        Button("Delete", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(BoardPalette.paper.opacity(0.78))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    PriorityPill(priority: task.priority)
                    BoardChip(label: task.assignedAgent, systemImage: "person.fill", tint: BoardPalette.gold)
                }

                if let sessionID = task.sessionID {
                    Text(sessionID)
                        .font(.caption)
                        .foregroundStyle(BoardPalette.paper.opacity(0.5))
                        .lineLimit(1)
                }

                Text(task.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(BoardPalette.paper.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await appModel.agentsStore.deleteTask(id: task.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(task.title)\"?")
        }
    }
}
