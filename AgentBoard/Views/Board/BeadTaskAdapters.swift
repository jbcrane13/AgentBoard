import SwiftUI

/// Compatibility wrapper so the existing Bead-based board can render the newer PRD/task card UI.
struct BeadTaskCardAdapter: View {
    let bead: Bead
    @State private var issue: BeadIssue

    init(bead: Bead) {
        self.bead = bead
        _issue = State(initialValue: BeadIssue(bead: bead))
    }

    var body: some View {
        TaskCardView(issue: $issue)
    }
}

/// Compatibility wrapper so the existing Bead-based board can present the newer detail sheet.
struct BeadTaskDetailSheetAdapter: View {
    let bead: Bead
    let onClose: () -> Void
    @State private var epic: Epic

    init(bead: Bead, onClose: @escaping () -> Void) {
        self.bead = bead
        self.onClose = onClose
        _epic = State(initialValue: Epic(bead: bead))
    }

    var body: some View {
        TaskDetailSheet(epic: $epic)
            .onDisappear {
                onClose()
            }
    }
}
