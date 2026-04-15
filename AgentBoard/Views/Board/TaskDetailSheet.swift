import SwiftUI

/// A sheet view that displays task details and allows agent assignment.
///
/// When an agent is assigned to a task, the `AgentNotificationService` is
/// automatically called to send a Telegram notification to the agent.
///
/// Usage:
/// ```swift
/// @State var showDetail = false
///
/// .sheet(isPresented: $showDetail) {
///     TaskDetailSheet(
///         epic: $epic,
///         notificationService: notificationService
///     )
/// }
/// ```
public struct TaskDetailSheet: View {
    @Binding public var epic: Epic
    @Environment(\.dismiss) private var dismiss

    private let notificationService: AgentNotificationService?

    @State private var selectedAssignee: String = ""
    @State private var isNotifying = false
    @State private var notificationMessage: String?

    /// Available agents for assignment
    public var availableAgents: [Agent]

    /// Initialize the task detail sheet
    /// - Parameters:
    ///   - epic: Binding to the epic model
    ///   - availableAgents: List of agents that can be assigned
    ///   - notificationService: Service for sending Telegram notifications (nil to disable)
    public init(
        epic: Binding<Epic>,
        availableAgents: [Agent] = Agent.defaultAgents,
        notificationService: AgentNotificationService? = nil
    ) {
        self._epic = epic
        self.availableAgents = availableAgents
        self.notificationService = notificationService
        self._selectedAssignee = State(initialValue: epic.wrappedValue.assignee ?? "")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    taskInfoSection
                    assignmentSection
                    subtasksOverviewSection

                    if let message = notificationMessage {
                        notificationBanner(message)
                    }
                }
                .padding(20)
            }

            // Footer
            footerSection
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Task Details")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Task Info

    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(epic.title)
                .font(.title3)
                .fontWeight(.semibold)

            if let description = epic.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label(epic.priority.rawValue.capitalized, systemImage: priorityIcon)
                    .font(.caption)
                    .foregroundColor(priorityColor)

                Label(epic.status.rawValue, systemImage: epic.status.iconName)
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .systemGray))

                if !epic.tags.isEmpty {
                    ForEach(epic.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Assignment Section

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assign Agent")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Assignee", selection: $selectedAssignee) {
                Text("Unassigned")
                    .tag("")

                Divider()

                ForEach(availableAgents) { agent in
                    Text(agent.name)
                        .tag(agent.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedAssignee) { newValue in
                assignAgent(newValue)
            }

            if let current = epic.assignee,
               let agent = availableAgents.first(where: { $0.id == current }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Assigned to \(agent.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Subtasks Overview

    private var subtasksOverviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subtasks")
                .font(.subheadline)
                .fontWeight(.semibold)

            if epic.subtasks.isEmpty {
                Text("No subtasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(epic.subtasks) { subtask in
                    HStack(spacing: 8) {
                        Image(systemName: subtask.status.iconName)
                            .font(.caption)
                            .foregroundColor(Color(nsColor: subtask.status == .done ? .systemGreen : .systemGray))
                        Text(subtask.title)
                            .font(.caption)
                            .foregroundColor(subtask.status == .done ? .secondary : .primary)
                        Spacer()
                        if let assignee = subtask.assignee {
                            Text(assignee)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Notification Banner

    private func notificationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            if isNotifying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: message.hasPrefix("✓") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(message.hasPrefix("✓") ? .green : .orange)
            }
            Text(message)
                .font(.caption)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Helpers

    private var priorityIcon: String {
        switch epic.priority {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "arrow.up.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }

    private var priorityColor: Color {
        switch epic.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private func assignAgent(_ agentId: String) {
        let oldAssignee = epic.assignee
        epic.assignee = agentId.isEmpty ? nil : agentId

        // Notify only when a new agent is assigned (not unassigned, not same agent)
        guard !agentId.isEmpty,
              agentId != oldAssignee,
              let service = notificationService,
              let agent = availableAgents.first(where: { $0.id == agentId })
        else { return }

        sendAssignmentNotification(agent: agent, service: service)
    }

    private func sendAssignmentNotification(agent: Agent, service: AgentNotificationService) {
        let task = AgentTask(
            id: epic.id,
            title: epic.title,
            description: epic.description ?? "",
            priority: epic.priority
        )

        isNotifying = true
        notificationMessage = "Sending notification..."

        Task {
            let result = await service.notifyAssignment(agent: agent, task: task)
            await MainActor.run {
                isNotifying = false
                switch result {
                case .success:
                    notificationMessage = "✓ Notified \(agent.name)"
                case .failure(let error):
                    notificationMessage = "! Failed: \(error.localizedDescription)"
                }

                // Clear message after a delay
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    await MainActor.run {
                        notificationMessage = nil
                    }
                }
            }
        }
    }
}

// MARK: - Default Agents

extension Agent {
    /// Default set of agents commonly used in AgentBoard
    public static let defaultAgents: [Agent] = [
        Agent(id: "codex", name: "Codex", telegramUserId: nil),
        Agent(id: "claude", name: "Claude", telegramUserId: nil),
        Agent(id: "gemini", name: "Gemini", telegramUserId: nil),
        Agent(id: "copilot", name: "Copilot", telegramUserId: nil),
    ]
}

// MARK: - Preview

#if DEBUG
struct TaskDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        TaskDetailSheet(
            epic: .constant(Epic.sample()),
            availableAgents: Agent.defaultAgents
        )
    }
}
#endif
