import SwiftUI
import UniformTypeIdentifiers

// MARK: - Agent Task Model

struct AgentTask: Identifiable, Hashable {
    let id: String
    var title: String
    var status: String
    var priority: Int
    var assignee: String
    var issueType: String
    var createdAt: Date
    var updatedAt: Date

    var statusColor: Color {
        switch status.lowercased() {
        case "open": return .gray
        case "in_progress", "in-progress": return .blue
        case "done", "closed": return .green
        case "blocked": return .orange
        default: return .gray
        }
    }

    var isCompleted: Bool {
        let s = status.lowercased()
        return s == "done" || s == "closed"
    }
}

// MARK: - View Model

@Observable
@MainActor
final class AgentTasksViewModel {
    var tasks: [AgentTask] = []
    var isLoading = false
    var errorMessage: String?

    private var pollingTask: Task<Void, Never>?
    private let workingDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".openclaw/agent-tasks")

    func startPolling() {
        stopPolling()
        loadTasks()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                self?.loadTasks()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadTasks() {
        Task {
            do {
                let result = try await ShellCommand.runAsync(
                    arguments: ["bd", "list", "--json"],
                    workingDirectory: workingDirectory
                )
                let parsed = parseTasksJSON(result.stdout)
                self.tasks = parsed
                self.errorMessage = nil
            } catch {
                self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
            }
        }
    }

    func createTask(title: String, assignee: String, priority: Int = 2) {
        Task {
            do {
                var args = ["bd", "create", title, "-p", "\(priority)", "--json"]
                if !assignee.isEmpty {
                    args += ["-a", assignee]
                }
                _ = try await ShellCommand.runAsync(
                    arguments: args,
                    workingDirectory: workingDirectory
                )
                loadTasks()
            } catch {
                self.errorMessage = "Failed to create task: \(error.localizedDescription)"
            }
        }
    }

    func updateAssignee(taskID: String, assignee: String) {
        Task {
            do {
                _ = try await ShellCommand.runAsync(
                    arguments: ["bd", "update", taskID, "-a", assignee, "--json"],
                    workingDirectory: workingDirectory
                )
                loadTasks()
            } catch {
                self.errorMessage = "Failed to update assignee: \(error.localizedDescription)"
            }
        }
    }

    func updateStatus(taskID: String, status: String) {
        Task {
            do {
                _ = try await ShellCommand.runAsync(
                    arguments: ["bd", "update", taskID, "--status", status, "--json"],
                    workingDirectory: workingDirectory
                )
                loadTasks()
            } catch {
                self.errorMessage = "Failed to update status: \(error.localizedDescription)"
            }
        }
    }

    func closeTask(taskID: String) {
        Task {
            do {
                _ = try await ShellCommand.runAsync(
                    arguments: ["bd", "close", taskID, "--reason", "done", "--json"],
                    workingDirectory: workingDirectory
                )
                loadTasks()
            } catch {
                self.errorMessage = "Failed to close task: \(error.localizedDescription)"
            }
        }
    }

    func updateTask(taskID: String, title: String, description: String, priority: Int, assignee: String, status: String) {
        Task {
            do {
                var args = ["bd", "update", taskID,
                            "--title", title,
                            "-p", "\(priority)",
                            "-a", assignee,
                            "--status", status]
                if !description.isEmpty {
                    args += ["-d", description]
                }
                _ = try await ShellCommand.runAsync(
                    arguments: args,
                    workingDirectory: workingDirectory
                )
                loadTasks()
            } catch {
                self.errorMessage = "Failed to update task: \(error.localizedDescription)"
            }
        }
    }

    private func parseTasksJSON(_ json: String) -> [AgentTask] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return array.compactMap { dict -> AgentTask? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let status = dict["status"] as? String else { return nil }

            let priority = dict["priority"] as? Int ?? 2
            let assignee = dict["assignee"] as? String ?? dict["owner"] as? String ?? ""
            let issueType = dict["issue_type"] as? String ?? "task"
            let createdAt = (dict["created_at"] as? String).flatMap { formatter.date(from: $0) } ?? .distantPast
            let updatedAt = (dict["updated_at"] as? String).flatMap { formatter.date(from: $0) } ?? createdAt

            return AgentTask(
                id: id,
                title: title,
                status: status,
                priority: priority,
                assignee: assignee,
                issueType: issueType,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
}

// MARK: - Agent Tasks View

struct AgentTasksView: View {
    @State private var viewModel = AgentTasksViewModel()
    @State private var showCreateSheet = false
    @State private var createTitle = ""
    @State private var createAssignee = ""
    @State private var createPriority = 2
    @State private var detailTask: AgentTask?
    @State private var draggedTaskID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            kanbanBoard
        }
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
        .sheet(isPresented: $showCreateSheet) {
            createTaskSheet
        }
        .sheet(item: $detailTask) { task in
            AgentTaskDetailSheet(task: task, viewModel: viewModel) {
                detailTask = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("Agent Tasks")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Button {
                createAssignee = ""
                createTitle = ""
                createPriority = 2
                showCreateSheet = true
            } label: {
                Label("New Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Kanban Board

    private var kanbanBoard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(AgentDefinition.knownAgents) { agent in
                    agentColumn(agent)
                }
            }
            .padding(14)
        }
    }

    private func agentColumn(_ agent: AgentDefinition) -> some View {
        let agentTasks = viewModel.tasks.filter { taskBelongsToAgent($0, agent: agent) }
        let activeTasks = agentTasks.filter { !$0.isCompleted }
        let doneTasks = agentTasks.filter { $0.isCompleted }

        return AgentColumnView(
            agent: agent,
            activeTasks: activeTasks,
            doneTasks: doneTasks,
            draggedTaskID: $draggedTaskID,
            onCreateTask: {
                createAssignee = agent.id
                createTitle = ""
                createPriority = 2
                showCreateSheet = true
            },
            onTapTask: { task in
                detailTask = task
            },
            onDropTask: { taskID in
                viewModel.updateAssignee(taskID: taskID, assignee: agent.id)
            }
        )
    }

    private func taskBelongsToAgent(_ task: AgentTask, agent: AgentDefinition) -> Bool {
        if agent.id.isEmpty {
            return task.assignee.isEmpty
        }
        return task.assignee.lowercased() == agent.id.lowercased()
    }

    // MARK: - Create Sheet

    private var createTaskSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Agent Task")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) { Divider() }

            Form {
                TextField("Title", text: $createTitle)

                Picker("Assignee", selection: $createAssignee) {
                    ForEach(AgentDefinition.knownAgents) { agent in
                        Text("\(agent.emoji) \(agent.name)").tag(agent.id)
                    }
                }

                Picker("Priority", selection: $createPriority) {
                    Text("P0 - Critical").tag(0)
                    Text("P1 - High").tag(1)
                    Text("P2 - Medium").tag(2)
                    Text("P3 - Low").tag(3)
                    Text("P4 - Backlog").tag(4)
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    showCreateSheet = false
                }
                Button("Create") {
                    viewModel.createTask(title: createTitle, assignee: createAssignee, priority: createPriority)
                    showCreateSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(createTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .overlay(alignment: .top) { Divider() }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

// MARK: - Agent Column View

private struct AgentColumnView: View {
    let agent: AgentDefinition
    let activeTasks: [AgentTask]
    let doneTasks: [AgentTask]
    @Binding var draggedTaskID: String?
    let onCreateTask: () -> Void
    let onTapTask: (AgentTask) -> Void
    let onDropTask: (String) -> Void

    @State private var showCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnHeader
            taskList
        }
        .frame(width: 260)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("\(agent.emoji) \(agent.name)")
                .font(.system(size: 14, weight: .semibold))

            Text("\(activeTasks.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.04), in: Capsule())

            Spacer()

            Button {
                onCreateTask()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if activeTasks.isEmpty && doneTasks.isEmpty {
                    Text("No tasks")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(activeTasks) { task in
                        AgentTaskCard(task: task)
                            .onDrag {
                                draggedTaskID = task.id
                                return NSItemProvider(object: task.id as NSString)
                            }
                            .onTapGesture {
                                onTapTask(task)
                            }
                    }

                    if !doneTasks.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCompleted.toggle()
                            }
                        } label: {
                            Text(showCompleted ? "Hide \(doneTasks.count) completed" : "Show \(doneTasks.count) completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        if showCompleted {
                            ForEach(doneTasks) { task in
                                AgentTaskCard(task: task)
                                    .opacity(0.6)
                                    .onTapGesture {
                                        onTapTask(task)
                                    }
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let itemID: String?
                if let data = item as? Data {
                    itemID = String(data: data, encoding: .utf8)
                } else if let string = item as? NSString {
                    itemID = string as String
                } else if let string = item as? String {
                    itemID = string
                } else {
                    itemID = nil
                }
                guard let rawID = itemID?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                Task { @MainActor in
                    onDropTask(rawID)
                }
            }
            return true
        }
    }
}

// MARK: - Agent Task Card

private struct AgentTaskCard: View {
    let task: AgentTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(task.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                priorityBadge
            }

            Text(task.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .padding(.bottom, 2)

            HStack(spacing: 6) {
                statusDot

                Spacer()

                Text(task.createdAt.formatted(.dateTime.month(.twoDigits).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
    }

    private var priorityBadge: some View {
        let color = priorityColor(for: task.priority)
        return Text("P\(task.priority)")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var statusDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(task.statusColor)
                .frame(width: 7, height: 7)
            Text(task.status.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Agent Task Detail Sheet

private struct AgentTaskDetailSheet: View {
    let task: AgentTask
    let viewModel: AgentTasksViewModel
    let onDismiss: () -> Void

    @State private var editTitle: String
    @State private var editDescription = ""
    @State private var editPriority: Int
    @State private var editAssignee: String
    @State private var editStatus: String
    @State private var showCloseConfirm = false

    init(task: AgentTask, viewModel: AgentTasksViewModel, onDismiss: @escaping () -> Void) {
        self.task = task
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self._editTitle = State(initialValue: task.title)
        self._editPriority = State(initialValue: task.priority)
        self._editAssignee = State(initialValue: task.assignee)
        self._editStatus = State(initialValue: task.status)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(task.id)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            Form {
                TextField("Title", text: $editTitle)

                Picker("Status", selection: $editStatus) {
                    Text("Open").tag("open")
                    Text("In Progress").tag("in_progress")
                    Text("Blocked").tag("blocked")
                }

                Picker("Priority", selection: $editPriority) {
                    Text("P0 - Critical").tag(0)
                    Text("P1 - High").tag(1)
                    Text("P2 - Medium").tag(2)
                    Text("P3 - Low").tag(3)
                    Text("P4 - Backlog").tag(4)
                }

                Picker("Assignee", selection: $editAssignee) {
                    ForEach(AgentDefinition.knownAgents) { agent in
                        Text("\(agent.emoji) \(agent.name)").tag(agent.id)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $editDescription)
                        .frame(minHeight: 100)
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack(spacing: 8) {
                if !task.isCompleted {
                    Button("Close Task") {
                        showCloseConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()

                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    viewModel.updateTask(
                        taskID: task.id,
                        title: editTitle,
                        description: editDescription,
                        priority: editPriority,
                        assignee: editAssignee,
                        status: editStatus
                    )
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
        }
        .frame(minWidth: 500, minHeight: 480)
        .alert("Close \(task.id)?", isPresented: $showCloseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Close Task", role: .destructive) {
                viewModel.closeTask(taskID: task.id)
                onDismiss()
            }
        } message: {
            Text("This will mark the task as done.")
        }
    }
}
