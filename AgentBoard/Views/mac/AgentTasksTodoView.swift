// macOS Todo List view for Agent Tasks — replaces old Kanban board
import SwiftUI

#if os(macOS)
    struct AgentTasksTodoView: View {
        @State private var viewModel = AgentTasksViewModel()
        @State private var showCreateSheet = false
        @State private var newTitle = ""
        @State private var newAssignee = "daneel"
        @State private var detailTask: AgentTask?

        var body: some View {
            VStack(spacing: 0) {
                header
                Divider()
                if !viewModel.tasks.isEmpty {
                    taskListBody
                } else {
                    emptyState
                }
            }
            .sheet(item: $detailTask) { task in
                MacTaskDetailSheet(task: task, onClose: { detailTask = nil })
            }
            .sheet(isPresented: $showCreateSheet) {
                MacCreateTaskSheet(
                    title: $newTitle,
                    assignee: $newAssignee,
                    onCreate: {
                        viewModel.createTask(
                            title: newTitle,
                            description: "",
                            assignee: newAssignee,
                            priority: 2
                        )
                        showCreateSheet = false
                        newTitle = ""
                        newAssignee = "daneel"
                    },
                    onCancel: { showCreateSheet = false }
                )
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
                    Text("Agent Tasks")
                        .font(.system(size: 22, weight: .semibold))
                }
                Spacer()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Button {
                    newTitle = ""
                    newAssignee = "daneel"
                    showCreateSheet = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }

        private var dateHeader: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE · MMMM d"
            return formatter.string(from: Date())
        }

        // MARK: - Task List

        private var taskListBody: some View {
            let sorted = viewModel.tasks.sorted { taskA, taskB in
                let aVal = taskA.isCompleted ? 1 : 0
                let bVal = taskB.isCompleted ? 1 : 0
                return aVal < bVal
            }
            return ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sorted) { task in
                        MacTaskRow(
                            task: task,
                            onExpand: { detailTask = task },
                            onToggleComplete: {
                                let newStatus = task.isCompleted ? "open" : "done"
                                viewModel.updateStatus(taskID: task.id, status: newStatus)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }

        private var emptyState: some View {
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No tasks yet")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Button("Create First Task") {
                    newTitle = ""
                    newAssignee = "daneel"
                    showCreateSheet = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 60)
        }
    }

    // MARK: - Mac Task Row

    private struct MacTaskRow: View {
        let task: AgentTask
        let onExpand: () -> Void
        let onToggleComplete: () -> Void

        private var agent: AgentDefinition {
            AgentDefinition.find(task.assignee)
        }

        var body: some View {
            HStack(spacing: 10) {
                // Completion circle
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(task.isCompleted ? agent.color : .secondary)
                }
                .buttonStyle(.plain)

                // Title
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Ticket ref badge
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

                // Agent badge
                Circle()
                    .fill(agent.backgroundColor)
                    .overlay(
                        Text(agent.initials)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(agent.color)
                    )
                    .frame(width: 26, height: 26)

                // Expand
                Button(action: onExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Mac Task Detail Sheet

    private struct MacTaskDetailSheet: View {
        let task: AgentTask
        let onClose: () -> Void

        private var agent: AgentDefinition {
            AgentDefinition.find(task.assignee)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(task.id)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))

                if !task.ticketRef.isEmpty {
                    HStack(spacing: 4) {
                        Text("Ticket:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(task.ticketRef)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }

                if !task.note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(task.note)
                            .font(.system(size: 13))
                    }
                }

                HStack(spacing: 8) {
                    Text("Status:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(task.status.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(task.statusColor)
                }

                HStack(spacing: 8) {
                    Text("Assigned to:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(agent.backgroundColor)
                        .overlay(
                            Text(agent.initials)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(agent.color)
                        )
                        .frame(width: 22, height: 22)
                    Text(agent.name)
                        .font(.system(size: 12, weight: .medium))
                }

                HStack(spacing: 8) {
                    Text("Priority:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(task.priorityLevel.color)
                        .frame(width: 7, height: 7)
                    Text(task.priorityLevel.rawValue)
                        .font(.system(size: 12))
                }

                Spacer()

                HStack {
                    Spacer()
                    Button("Close") { onClose() }
                        .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding(20)
            .frame(minWidth: 440, minHeight: 300)
        }
    }

    // MARK: - Mac Create Task Sheet

    private struct MacCreateTaskSheet: View {
        @Binding var title: String
        @Binding var assignee: String
        var onCreate: () -> Void
        var onCancel: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("New Task")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(16)
                .overlay(alignment: .bottom) { Divider() }

                Form {
                    TextField("Title", text: $title)

                    Picker("Assignee", selection: $assignee) {
                        ForEach(AgentDefinition.knownAgents) { agent in
                            Text("\(agent.emoji) \(agent.name)").tag(agent.id)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.escape, modifiers: [])
                    Button("Create", action: onCreate)
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(16)
                .overlay(alignment: .top) { Divider() }
            }
            .frame(minWidth: 420, minHeight: 220)
        }
    }
#endif
