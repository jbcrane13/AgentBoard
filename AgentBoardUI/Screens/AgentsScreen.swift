import AgentBoardCore
import SwiftUI

struct AgentsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var isPresentingCreateSheet = false
    @State private var selectedWorkItemID: String?
    @State private var taskTitle = ""
    @State private var assignedAgent = ""
    @State private var note = ""
    @State private var status: AgentTaskState = .backlog
    @State private var priority: WorkPriority = .medium

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    BoardHeader(
                        eyebrow: "Agents",
                        title: "Execution state lives beside the work",
                        subtitle:
                        "Agent tasks are companion-managed execution objects linked back "
                            + "to GitHub issues, with summaries and sessions flowing into the same "
                            + "shared model."
                    )

                    Spacer(minLength: 20)

                    VStack(alignment: .trailing, spacing: 10) {
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

                if appModel.agentsStore.summaries.isEmpty && appModel.agentsStore.tasks.isEmpty {
                    EmptyStateCard(
                        title: "No agent activity yet",
                        message: appModel.agentsStore.statusMessage
                            ??
                            "Start the companion service and point Settings at it to watch tasks and live execution state.",
                        systemImage: "person.3.sequence"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(appModel.agentsStore.summaries) { summary in
                                    BoardSurface {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Text(summary.name)
                                                    .font(.title3.weight(.semibold))
                                                    .foregroundStyle(.white)

                                                Spacer()

                                                AgentHealthPill(health: summary.health)
                                            }

                                            Text(summary.recentActivity)
                                                .font(.subheadline)
                                                .foregroundStyle(BoardPalette.paper.opacity(0.78))

                                            HStack {
                                                StatBadge(label: "Tasks", value: "\(summary.activeTaskCount)")
                                                StatBadge(label: "Sessions", value: "\(summary.activeSessionCount)")
                                            }
                                        }
                                    }
                                }
                            }

                            BoardSectionTitle("Task Queue", subtitle: appModel.agentsStore.statusMessage)

                            ForEach(appModel.agentsStore.tasks) { task in
                                AgentTaskCard(task: task)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            createTaskSheet
                .presentationDetents([.medium, .large])
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

                Section("Task") {
                    TextField("Task title", text: $taskTitle)
                    TextField("Assigned agent", text: $assignedAgent)
                    Picker("Status", selection: $status) {
                        ForEach(AgentTaskState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(WorkPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    TextField("Notes", text: $note, axis: .vertical)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingCreateSheet = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let selectedWorkItemID,
                              let workItem = appModel.workStore.items.first(where: { $0.id == selectedWorkItemID })
                        else {
                            return
                        }

                        let draft = AgentTaskDraft(
                            workItem: workItem.reference,
                            title: taskTitle.trimmedOrNil ?? workItem.title,
                            status: status,
                            priority: priority,
                            assignedAgent: assignedAgent.trimmedOrNil ?? "Codex",
                            note: note.trimmed
                        )

                        Task {
                            await appModel.agentsStore.createTask(draft)
                        }
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

    var body: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(task.workItem.issueReference)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BoardPalette.gold)
                    }

                    Spacer()

                    Menu {
                        ForEach(AgentTaskState.allCases) { status in
                            Button(status.title) {
                                Task {
                                    await appModel.agentsStore.updateTask(
                                        id: task.id,
                                        patch: AgentTaskPatch(status: status)
                                    )
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                Text(task.note.isEmpty ? "No task notes yet." : task.note)
                    .font(.subheadline)
                    .foregroundStyle(BoardPalette.paper.opacity(0.78))

                HStack(spacing: 8) {
                    BoardChip(
                        label: task.status.title,
                        systemImage: "arrow.triangle.branch",
                        tint: task.status == .done ? BoardPalette.mint : BoardPalette.cobalt
                    )
                    PriorityPill(priority: task.priority)
                    BoardChip(label: task.assignedAgent, systemImage: "person.fill", tint: BoardPalette.gold)
                }

                HStack {
                    if let sessionID = task.sessionID {
                        Text(sessionID)
                            .font(.caption)
                            .foregroundStyle(BoardPalette.paper.opacity(0.68))
                    }

                    Spacer()

                    Text(task.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(BoardPalette.paper.opacity(0.68))
                }
            }
        }
    }
}

private struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(BoardPalette.paper.opacity(0.6))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
    }
}
