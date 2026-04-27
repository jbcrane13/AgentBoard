import AgentBoardCore
import SwiftUI

struct IssueDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let item: WorkItem

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var editLabels = ""
    @State private var editAssignees = ""
    @State private var editState: WorkState = .open
    @State private var editPriority: WorkPriority = .medium
    @State private var editMilestone = ""
    @State private var isSaving = false
    @State private var isPresentingLaunchSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                NeuBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            editForm
                        } else {
                            readView
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(item.issueReference)
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
                            .disabled(isSaving || editTitle.trimmedOrNil == nil)
                    } else {
                        Button("Edit") { beginEditing() }
                            .buttonStyle(NeuButtonTarget(isAccent: false))
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingLaunchSession) {
            LaunchSessionSheet(workItem: item)
                .environment(appModel)
        }
    }

    private var readView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(NeuPalette.textPrimary)
                HStack(spacing: 8) {
                    WorkStatusPill(state: item.status)
                    PriorityPill(priority: item.priority)
                }
                if !item.assignees.isEmpty {
                    Label(item.assignees.joined(separator: ", "), systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
                if let milestone = item.milestone {
                    Label(milestone.title, systemImage: "flag")
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.accentOrange)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)

            descriptionCard
            labelsCard
            launchSessionCard
            timelineCard
        }
    }

    @ViewBuilder
    private var descriptionCard: some View {
        if !item.bodySummary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundStyle(NeuPalette.textPrimary)
                Text(item.bodySummary)
                    .font(.body)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    @ViewBuilder
    private var labelsCard: some View {
        if !item.labels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Labels")
                    .font(.headline)
                    .foregroundStyle(NeuPalette.textPrimary)
                FlowLayout(spacing: 8) {
                    ForEach(item.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NeuPalette.accentCyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .neuRecessed(cornerRadius: 12, depth: 3)
                    }
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    private var timelineCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Created")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NeuPalette.textSecondary)
                Text(item.createdAt, style: .relative)
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Updated")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NeuPalette.textSecondary)
                Text(item.updatedAt, style: .relative)
                    .foregroundStyle(NeuPalette.textPrimary)
            }
        }
        .padding(24)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }

    private var launchSessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CODING SESSION")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(NeuPalette.textSecondary)

            Button {
                isPresentingLaunchSession = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch Session")
                            .font(.subheadline.weight(.bold))
                        Text("Start an agent session for this issue")
                            .font(.caption)
                            .foregroundStyle(NeuPalette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(NeuPalette.accentCyanBright)
                .padding(16)
                .background(NeuPalette.accentCyan.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NeuPalette.accentCyan.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("issue_detail_launch_session")
        }
        .padding(24)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                Text("EDIT ISSUE")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(NeuPalette.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Issue title", text: $editTitle)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    TextEditor(text: $editBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(12)
                        .neuRecessed(cornerRadius: 16, depth: 6)
                        .foregroundStyle(NeuPalette.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Labels").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "bug, priority:p1", text: $editLabels)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Assignees").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "alice, bob", text: $editAssignees)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Status").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    Picker("Status", selection: $editState) {
                        ForEach(WorkState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(NeuPalette.accentCyan)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Priority").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    Picker("Priority", selection: $editPriority) {
                        ForEach(WorkPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(NeuPalette.accentOrange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Milestone Number").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Optional milestone number", text: $editMilestone)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)

            if isSaving {
                ProgressView("Saving…")
                    .foregroundStyle(NeuPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func beginEditing() {
        editTitle = item.title
        editBody = item.bodySummary
        editLabels = item.labels.joined(separator: ", ")
        editAssignees = item.assignees.joined(separator: ", ")
        editState = item.status
        editPriority = item.priority
        editMilestone = item.milestone.map { String($0.number) } ?? ""
        isEditing = true
    }

    private func save() {
        isSaving = true
        let labels = editLabels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !$0.lowercased().hasPrefix("status:") && !$0.lowercased().hasPrefix("priority:") }
        let mergedLabels = Array(Set(labels + [editState.labelValue, editPriority.labelValue])).sorted()
        let assignees = editAssignees.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let milestone = Int(editMilestone.trimmingCharacters(in: .whitespacesAndNewlines))
        Task {
            await appModel.workStore.updateIssue(
                item,
                title: editTitle.trimmedOrNil,
                body: editBody.trimmedOrNil,
                labels: mergedLabels,
                assignees: assignees,
                milestone: milestone,
                state: editState
            )
            isSaving = false
            isEditing = false
            dismiss()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
