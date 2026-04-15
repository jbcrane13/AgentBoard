import SwiftUI

// MARK: - Agent Board Daily View (iOS + macOS)

struct AgentBoardDailyView: View {
    @State private var viewModel: AgentTasksViewModel
    @State private var selectedTab: String = "all"
    @State private var expandedTaskID: String?
    @State private var viewMode: TaskViewMode = .list

    enum TaskViewMode: String, CaseIterable {
        case list = "List"
        case kanban = "Kanban"
    }

    init(viewModel: AgentTasksViewModel = AgentTasksViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            agentTabs
            taskList
        }
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateHeader)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(.system(size: 27, weight: .medium))
            }

            Spacer()

            #if os(macOS)
                Picker("", selection: $viewMode) {
                    ForEach(TaskViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            #endif

            Button {
                // Create new task
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(viewMode == .list ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 27, height: 27)
            .background(Circle().fill(Color.secondary.opacity(0.1)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Agent Tabs

    private var agentTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                AllTabBadge(
                    count: activeTaskCount,
                    isSelected: selectedTab == "all",
                    action: { selectedTab = "all" }
                )

                ForEach(AgentDefinition.knownAgents.filter { !$0.id.isEmpty }) { agent in
                    AgentTabBadge(
                        agent: agent,
                        count: activeCount(for: agent.id),
                        isSelected: selectedTab == agent.id,
                        action: { selectedTab = agent.id }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                let filteredTasks = filteredAndSortedTasks

                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTasks) { task in
                        TaskCard(
                            task: task,
                            isExpanded: expandedTaskID == task.id,
                            onToggleExpand: { toggleExpand(task.id) },
                            onToggleComplete: { toggleComplete(task.id) },
                            onStatusChange: { status in updateStatus(task.id, status: status) },
                            onPriorityChange: { priority in updatePriority(task.id, priority: priority) },
                            onAssigneeChange: { assignee in updateAssignee(task.id, assignee: assignee) },
                            onTicketRefChange: { ref in updateTicketRef(task.id, ticketRef: ref) },
                            onNoteChange: { note in updateNote(task.id, note: note) }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No tasks today")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Computed Properties

    private var activeTaskCount: Int {
        viewModel.tasks.filter { !$0.isCompleted }.count
    }

    private func activeCount(for agentID: String) -> Int {
        viewModel.tasks.filter { $0.assignee == agentID && !$0.isCompleted }.count
    }

    private var filteredAndSortedTasks: [AgentTask] {
        let filtered = selectedTab == "all"
            ? viewModel.tasks
            : viewModel.tasks.filter { $0.assignee == selectedTab }

        // Sort: incomplete first, then completed
        return filtered.sorted { taskA, taskB in
            let aComplete = taskA.isCompleted ? 1 : 0
            let bComplete = taskB.isCompleted ? 1 : 0
            return aComplete < bComplete
        }
    }

    // MARK: - Actions

    private func toggleExpand(_ taskID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedTaskID = expandedTaskID == taskID ? nil : taskID
        }
    }

    private func toggleComplete(_ taskID: String) {
        guard let task = viewModel.tasks.first(where: { $0.id == taskID }) else { return }
        let newStatus = task.isCompleted ? "open" : "done"
        viewModel.updateStatus(taskID: taskID, status: newStatus)
    }

    private func updateStatus(_ taskID: String, status: String) {
        viewModel.updateStatus(taskID: taskID, status: status)
    }

    private func updatePriority(_: String, priority: AgentTask.PriorityLevel) {
        let priorityInt: Int
        switch priority {
        case .high: priorityInt = 1
        case .medium: priorityInt = 2
        case .low: priorityInt = 3
        }
        // viewModel.updatePriority(taskID: taskID, priority: priorityInt)
    }

    private func updateAssignee(_ taskID: String, assignee: String) {
        viewModel.updateAssignee(taskID: taskID, assignee: assignee)
    }

    private func updateTicketRef(_: String, ticketRef _: String) {
        // TODO: Add ticket ref update to viewModel
    }

    private func updateNote(_: String, note _: String) {
        // TODO: Add note update to viewModel
    }
}

// MARK: - All Tab Badge

private struct AllTabBadge: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("All")
                // swiftlint:disable:next empty_count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.secondary.opacity(0.1) : .clear))
            )
            .foregroundColor(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Tab Badge

private struct AgentTabBadge: View {
    let agent: AgentDefinition
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(agent.name)
                // swiftlint:disable:next empty_count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(agent.color.opacity(0.2))
                        .foregroundColor(agent.color)
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? agent.color : Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 20).fill(isSelected ? agent.color.opacity(0.1) : .clear))
            )
            .foregroundColor(isSelected ? agent.color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Card

private struct TaskCard: View {
    let task: AgentTask
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onToggleComplete: () -> Void
    let onStatusChange: (String) -> Void
    let onPriorityChange: (AgentTask.PriorityLevel) -> Void
    let onAssigneeChange: (String) -> Void
    let onTicketRefChange: (String) -> Void
    let onNoteChange: (String) -> Void

    @State private var editingTicketRef: String = ""
    @State private var editingNote: String = ""

    var agent: AgentDefinition {
        AgentDefinition.find(task.assignee)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggleExpand) {
                HStack(spacing: 10) {
                    // Completion circle
                    Button(action: onToggleComplete) {
                        Circle()
                            .stroke(agent.color, lineWidth: 1.5)
                            .frame(width: 21, height: 21)
                            .overlay {
                                if task.isCompleted {
                                    Circle().fill(agent.color)
                                    Text("✓")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.black)
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    // Title
                    Text(task.title)
                        .font(.system(size: 15))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Ticket ref
                    if !task.ticketRef.isEmpty {
                        Text(task.ticketRef)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }

                    // Priority dot
                    Circle()
                        .fill(task.priorityLevel.color)
                        .frame(width: 7, height: 7)
                        .opacity(task.isCompleted ? 0.3 : 1)

                    // Agent initials
                    Circle()
                        .fill(agent.backgroundColor)
                        .overlay(
                            Text(agent.initials)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(agent.color)
                        )
                        .frame(width: 26, height: 26)

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    // Status buttons
                    HStack(spacing: 6) {
                        ForEach(["pending", "in-progress", "complete"], id: \.self) { status in
                            StatusButton(
                                status: status,
                                isSelected: task.status.lowercased() == status ||
                                    (status == "pending" && task.status.lowercased() == "open"),
                                color: statusColor(for: status),
                                action: { onStatusChange(status) }
                            )
                        }
                    }

                    // Priority buttons
                    HStack(spacing: 6) {
                        ForEach(AgentTask.PriorityLevel.allCases, id: \.self) { level in
                            PriorityButton(
                                level: level,
                                isSelected: task.priorityLevel == level,
                                action: { onPriorityChange(level) }
                            )
                        }
                    }

                    // Ticket ref input
                    HStack(spacing: 8) {
                        Text("Ticket ref")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 64, alignment: .leading)

                        TextField("e.g. CUL-42", text: $editingTicketRef)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: editingTicketRef) { _, newValue in
                                onTicketRefChange(newValue)
                            }
                    }

                    // Note input
                    TextField("Add a note...", text: $editingNote, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .lineLimit(2 ... 4)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: editingNote) { _, newValue in
                            onNoteChange(newValue)
                        }

                    // Assignee picker
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Assigned to")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(AgentDefinition.knownAgents.filter { !$0.id.isEmpty }) { agt in
                                AgentPickerButton(
                                    agent: agt,
                                    isSelected: task.assignee == agt.id,
                                    action: { onAssigneeChange(agt.id) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isExpanded ? agent.color.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            editingTicketRef = task.ticketRef
            editingNote = task.note
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "pending": return .secondary
        case "in-progress": return .blue
        case "complete": return .green
        default: return .secondary
        }
    }
}

// MARK: - Status Button

private struct StatusButton: View {
    let status: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var label: String {
        switch status {
        case "pending": return "Pending"
        case "in-progress": return "In progress"
        case "complete": return "Done"
        default: return status.capitalized
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 20).fill(isSelected ? color.opacity(0.1) : .clear))
                )
                .foregroundColor(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Priority Button

private struct PriorityButton: View {
    let level: AgentTask.PriorityLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(level.color)
                    .frame(width: 6, height: 6)
                Text(level.rawValue)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? level.color : Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 20).fill(isSelected ? level.color.opacity(0.1) : .clear))
            )
            .foregroundColor(isSelected ? level.color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Picker Button

private struct AgentPickerButton: View {
    let agent: AgentDefinition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? agent.color.opacity(0.2) : Color.secondary.opacity(0.1))
                    .overlay(
                        Text(agent.initials)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? agent.color : .secondary)
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().stroke(isSelected ? agent.color : Color.secondary.opacity(0.3), lineWidth: 2)
                    )

                Text(agent.name)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? agent.color : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AgentBoardDailyView(viewModel: AgentTasksViewModel(useFixtureData: true))
        .frame(width: 365, height: 700)
        .preferredColorScheme(.dark)
}
