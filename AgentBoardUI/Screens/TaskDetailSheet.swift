import AgentBoardCore
import SwiftUI

struct TaskDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let task: AgentTask

    @State private var editTitle = ""
    @State private var editStatus: AgentTaskState = .backlog
    @State private var editPriority: WorkPriority = .medium
    @State private var editAgent = ""
    @State private var editNote = ""
    @State private var editSessionID: String?
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        editForm
                        workItemCard
                        if isSaving {
                            ProgressView("Saving…")
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        deleteButton
                    }
                    .padding(24)
                }
            }
            .navigationTitle(task.workItem.issueReference)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isSaving || editTitle.trimmedOrNil == nil)
                }
            }
            .alert("Delete Task", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await appModel.agentsStore.deleteTask(id: task.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(task.title)\"? This cannot be undone.")
            }
        }
        .onAppear { populate() }
    }

    private var editForm: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 14) {
                BoardSectionTitle("Edit Task")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.headline).foregroundStyle(.white)
                    TextField("Task title", text: $editTitle)
                        .taskFieldStyle()
                }

                statusAndPriorityRow

                VStack(alignment: .leading, spacing: 6) {
                    Text("Assigned Agent").font(.headline).foregroundStyle(.white)
                    TextField("agent name", text: $editAgent)
                        .taskFieldStyle()
                }

                sessionPicker

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.headline).foregroundStyle(.white)
                    TextEditor(text: $editNote)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var statusAndPriorityRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Status").font(.headline).foregroundStyle(.white)
                Picker("Status", selection: $editStatus) {
                    ForEach(AgentTaskState.allCases) { state in
                        Text(state.title).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(.white)
                .pickerBackground()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Priority").font(.headline).foregroundStyle(.white)
                Picker("Priority", selection: $editPriority) {
                    ForEach(WorkPriority.allCases) { prio in
                        Text(prio.title).tag(prio)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(.white)
                .pickerBackground()
            }
        }
    }

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Link Session").font(.headline).foregroundStyle(.white)
            Picker("Session", selection: $editSessionID) {
                Text("None").tag(String?.none)
                ForEach(appModel.sessionsStore.sessions) { session in
                    Text("\(session.source) — \(session.status.title)")
                        .tag(Optional(session.id))
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(.white)
            .pickerBackground()
        }
    }

    private var workItemCard: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 8) {
                Text("Work Item")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack {
                    Text(task.workItem.issueReference)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(task.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Task", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 4)
    }

    private func populate() {
        editTitle = task.title
        editStatus = task.status
        editPriority = task.priority
        editAgent = task.assignedAgent
        editNote = task.note
        editSessionID = task.sessionID
    }

    private func save() {
        isSaving = true
        let patch = AgentTaskPatch(
            title: editTitle.trimmedOrNil,
            status: editStatus,
            priority: editPriority,
            assignedAgent: editAgent.trimmedOrNil,
            sessionID: editSessionID,
            note: editNote.trimmedOrNil
        )
        Task {
            await appModel.agentsStore.updateTask(id: task.id, patch: patch)
            isSaving = false
            dismiss()
        }
    }
}

private extension View {
    func taskFieldStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .foregroundStyle(.white)
    }

    func pickerBackground() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.22)))
    }
}
