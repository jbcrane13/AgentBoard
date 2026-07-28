import AgentBoardCore
import SwiftUI

// MARK: - Drag undo / error feedback

/// A captured kanban task move, surfaced as a transient Undo toast that
/// reverts to `priorStatus` when tapped (or auto-dismisses after 5s).
struct KanbanUndoOpportunity: Identifiable {
    let id: String
    let taskID: String
    let taskTitle: String
    let priorStatus: KanbanStatus
    let until: Date

    init(taskID: String, taskTitle: String, priorStatus: KanbanStatus, until: Date) {
        self.id = "\(taskID)-\(until.timeIntervalSince1970)"
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.priorStatus = priorStatus
        self.until = until
    }
}

extension AgentsScreen {
    /// The transient Undo capsule pinned to the bottom of the board area.
    @ViewBuilder
    func undoToast(for opportunity: KanbanUndoOpportunity) -> some View {
        HStack(spacing: 10) {
            Text("Moved \"\(opportunity.taskTitle)\" — undo?")
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
            Button("Undo") {
                revertUndo(opportunity)
            }
            .buttonStyle(AppButtonStyle(isAccent: true))
            .accessibilityIdentifier("kanban_button_undo_move")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: 360)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    func scheduleUndoDismiss() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if let opportunity = undoOpportunity, Date() >= opportunity.until {
                withAnimation { undoOpportunity = nil }
            }
        }
    }

    func revertUndo(_ opportunity: KanbanUndoOpportunity) {
        let prior = opportunity.priorStatus
        let taskID = opportunity.taskID
        undoOpportunity = nil
        Task { @MainActor in
            await appModel.agentsStore.moveTask(id: taskID, to: prior)
        }
    }

    func surfaceDropError(_ message: String, in status: KanbanStatus) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dropErrorMessage = message
            dropErrorStatus = status
        }
        dropErrorTask?.cancel()
        dropErrorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation { dropErrorMessage = nil }
            }
        }
    }
}
