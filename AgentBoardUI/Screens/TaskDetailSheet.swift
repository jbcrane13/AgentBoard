import AgentBoardCore
import SwiftUI

struct TaskDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let task: AgentTask

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editAssignedAgent = ""
    @State private var editNote = ""
    @State private var editStatus: AgentTaskState = .backlog
    @State private var editPriority: WorkPriority = .p2

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                NeuBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if isEditing {
                            editForm
                        } else {
                            readView
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Task Details")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(NeuPalette.textPrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") { save() }
                            .buttonStyle(NeuButtonTarget(isAccent: true))
                            .disabled(editTitle.trimmedOrNil == nil)
                    } else {
                        Button("Edit") { beginEditing() }
                            .buttonStyle(NeuButtonTarget(isAccent: false))
                    }
                }
            }
        }
    }

    private var readView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(task.workItem.issueReference)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NeuPalette.accentCyan)
                    Spacer()
                    PriorityNeu(priority: task.priority)
                }

                Text(task.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(task.status.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .neuRecessed(cornerRadius: 12, depth: 3)

                    HStack(spacing: 6) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text(task.assignedAgent).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(NeuPalette.accentOrange)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)

            if !task.note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(NeuPalette.textSecondary)
                    Text(task.note)
                        .font(.body)
                        .foregroundStyle(NeuPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .padding(24)
                .neuExtruded(cornerRadius: 24, elevation: 8)
            }

            if let sessionID = task.sessionID {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE SESSION")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(NeuPalette.textSecondary)
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.horizontal.fill")
                            .foregroundStyle(NeuPalette.accentCyan)
                        Text(sessionID)
                            .font(.caption.monospaced())
                            .foregroundStyle(NeuPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(24)
                .neuExtruded(cornerRadius: 24, elevation: 8)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("TIMELINE")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(NeuPalette.textSecondary)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NeuPalette.textSecondary)
                        Text(task.createdAt, style: .relative)
                            .font(.body.weight(.medium))
                            .foregroundStyle(NeuPalette.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Updated")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NeuPalette.textSecondary)
                        Text(task.updatedAt, style: .relative)
                            .font(.body.weight(.medium))
                            .foregroundStyle(NeuPalette.textPrimary)
                    }
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                Text("EDIT TASK")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(NeuPalette.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Task title", text: $editTitle)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Assigned agent").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Agent Name", text: $editAssignedAgent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    TextEditor(text: $editNote)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(12)
                        .neuRecessed(cornerRadius: 16, depth: 6)
                        .foregroundStyle(NeuPalette.textPrimary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Status").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    Picker("Status", selection: $editStatus) {
                        ForEach(AgentTaskState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(NeuPalette.accentCyan)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Priority").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    Picker("Priority", selection: $editPriority) {
                        ForEach(WorkPriority.allCases) { prio in
                            Text(prio.title).tag(prio)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(NeuPalette.accentOrange)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    private func beginEditing() {
        editTitle = task.title
        editAssignedAgent = task.assignedAgent
        editNote = task.note
        editStatus = task.status
        editPriority = task.priority
        isEditing = true
    }

    private func save() {
        let patch = AgentTaskPatch(
            title: editTitle.trimmedOrNil ?? task.title,
            status: editStatus,
            priority: editPriority,
            assignedAgent: editAssignedAgent.trimmedOrNil ?? "Codex",
            note: editNote.trimmed,
        )

        Task {
            await appModel.agentsStore.updateTask(id: task.id, patch: patch)
            isEditing = false
            dismiss()
        }
    }
}
