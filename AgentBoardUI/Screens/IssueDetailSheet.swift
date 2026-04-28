import AgentBoardCore
import SwiftUI

// swiftlint:disable:next type_body_length
struct IssueDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let item: WorkItem

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var editType: IssueType = .task
    @State private var editPriority: WorkPriority = .p2
    @State private var editStatus: WorkState = .ready
    @State private var editAgent: AgentName?
    @State private var editMilestone = ""
    @State private var isSaving = false
    @State private var isClosing = false
    @State private var isPresentingLaunchSession = false
    @State private var showAttachmentPicker = false
    @State private var pendingAttachments: [ChatAttachment] = []

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
                ToolbarItemGroup(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") { save() }
                            .buttonStyle(NeuButtonTarget(isAccent: true))
                            .disabled(isSaving || editTitle.trimmedOrNil == nil)
                    } else {
                        if item.status == .done {
                            Button("Reopen") { closeOrReopen() }
                                .buttonStyle(NeuButtonTarget(isAccent: false))
                                .disabled(isClosing)
                        } else {
                            Button("Close Issue") { closeOrReopen() }
                                .buttonStyle(NeuButtonTarget(isAccent: true))
                                .disabled(isClosing)
                        }
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
        .sheet(isPresented: $showAttachmentPicker) {
            AttachmentPickerSheet { attachment in
                pendingAttachments.append(attachment)
            }
        }
    }

    // MARK: - Read View

    private var readView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header card
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(NeuPalette.textPrimary)

                // Structured pills
                FlowLayout(spacing: 8) {
                    WorkStatusPill(state: item.status)
                    PriorityPill(priority: item.priority)
                    if let typeLabel = parsedTypeLabel {
                        LabelPill(text: typeLabel, color: .purple)
                    }
                    if let agentLabel = parsedAgentLabel {
                        LabelPill(text: agentLabel, color: .green)
                    }
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)

            descriptionCard
            closeActionCard
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

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                Text("EDIT ISSUE")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(NeuPalette.textSecondary)

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Issue title", text: $editTitle)
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    TextEditor(text: $editBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(12)
                        .neuRecessed(cornerRadius: 16, depth: 6)
                        .foregroundStyle(NeuPalette.textPrimary)
                }

                // Type (required)
                editDropdown(label: "Type", required: true) {
                    Picker("Type", selection: $editType) {
                        ForEach(IssueType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("edit_issue_picker_type")
                }

                // Priority (required)
                editDropdown(label: "Priority", required: true) {
                    Picker("Priority", selection: $editPriority) {
                        ForEach(WorkPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("edit_issue_picker_priority")
                }

                // Status (required)
                editDropdown(label: "Status", required: true) {
                    Picker("Status", selection: $editStatus) {
                        ForEach(WorkState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("edit_issue_picker_status")
                }

                // Agent (optional)
                editDropdown(label: "Agent", required: false) {
                    Picker("Agent", selection: $editAgent) {
                        Text("None").tag(AgentName?.none)
                        ForEach(AgentName.allCases) { agent in
                            Text(agent.title).tag(Optional(agent))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("edit_issue_picker_agent")
                }

                // Milestone (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Milestone").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    NeuTextField(placeholder: "Optional milestone", text: $editMilestone)
                }

                // Attachment (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Attachment").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                    if !pendingAttachments.isEmpty {
                        AttachmentPreviewStrip(attachments: $pendingAttachments)
                    }
                    Button {
                        showAttachmentPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperclip")
                            Text("Add attachment…")
                        }
                        .font(.subheadline)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .neuRecessed(cornerRadius: 16, depth: 6)
                    }
                    .buttonStyle(.plain)
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

    private var closeActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.status == .done {
                Button {
                    closeOrReopen()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.uturn.right")
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reopen Issue")
                                .font(.subheadline.weight(.bold))
                            Text("Move back to Ready")
                                .font(.caption)
                                .foregroundStyle(NeuPalette.textSecondary)
                        }
                        Spacer()
                        if isClosing {
                            ProgressView()
                        }
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
                .disabled(isClosing)
            } else {
                Button {
                    closeOrReopen()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Close Issue")
                                .font(.subheadline.weight(.bold))
                            Text("Mark as Done")
                                .font(.caption)
                                .foregroundStyle(NeuPalette.textSecondary)
                        }
                        Spacer()
                        if isClosing {
                            ProgressView()
                        }
                    }
                    .foregroundStyle(NeuPalette.accentGreen)
                    .padding(16)
                    .background(NeuPalette.accentGreen.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NeuPalette.accentGreen.opacity(0.2), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isClosing)
            }
        }
        .padding(24)
        .neuExtruded(cornerRadius: 24, elevation: 8)
    }

    // MARK: - Actions

    private func closeOrReopen() {
        isClosing = true
        Task {
            if item.status == .done {
                await appModel.workStore.reopenIssue(item)
            } else {
                await appModel.workStore.closeIssue(item)
            }
            isClosing = false
            dismiss()
        }
    }

    private func beginEditing() {
        editTitle = item.title
        editBody = item.bodySummary
        editType = parsedType ?? .task
        editPriority = item.priority
        editStatus = item.status
        editAgent = parsedAgent
        editMilestone = item.milestone.map { String($0.number) } ?? ""
        isEditing = true
    }

    private func save() {
        isSaving = true

        let mergedLabels = [
            editType.labelValue,
            editPriority.labelValue,
            editStatus.labelValue
        ] + (editAgent.map { [$0.labelValue] } ?? [])

        var bodyText = editBody.trimmedOrNil ?? ""
        if !pendingAttachments.isEmpty {
            let attachmentNote = pendingAttachments.map { attachment in
                let name: String
                switch attachment.payload {
                case let .file(payload): name = payload.fileName
                case let .image(payload): name = payload.localURL.lastPathComponent
                default: name = "attachment"
                }
                return "- 📎 \(name)"
            }.joined(separator: "\n")
            if !bodyText.isEmpty { bodyText += "\n\n" }
            bodyText += "**Attachments:**\n\(attachmentNote)"
        }

        Task {
            await appModel.workStore.updateIssue(
                item,
                title: editTitle.trimmedOrNil,
                body: bodyText,
                labels: mergedLabels.sorted(),
                assignees: [],
                milestone: Int(editMilestone.trimmingCharacters(in: .whitespacesAndNewlines)),
                state: editStatus
            )
            isSaving = false
            isEditing = false
            dismiss()
        }
    }

    // MARK: - Label Parsing Helpers

    /// Parse the issue's labels into a structured IssueType.
    private var parsedType: IssueType? {
        for label in item.labels {
            if label.hasPrefix("type:"),
               let type = IssueType(rawValue: String(label.dropFirst(5))) {
                return type
            }
        }
        return nil
    }

    /// Parse the issue's labels into a structured AgentName.
    private var parsedAgent: AgentName? {
        for label in item.labels {
            if label.hasPrefix("agent:"),
               let agent = AgentName(rawValue: String(label.dropFirst(6))) {
                return agent
            }
        }
        return nil
    }

    private var parsedTypeLabel: String? {
        parsedType?.title
    }

    private var parsedAgentLabel: String? {
        parsedAgent?.title
    }

    // MARK: - Helpers

    /// Inline row: label on the left, picker rendered as a tightly-hugged
    /// capsule chip on the right. Matches `CreateIssueSheet.labelDropdown`.
    private func editDropdown<Content: View>(
        label: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.headline).foregroundStyle(NeuPalette.textPrimary)
            if required {
                Text("•").foregroundStyle(.red).font(.caption)
            }
            Spacer(minLength: 8)
            content()
                .tint(NeuPalette.accentCyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(NeuPalette.inset.opacity(0.55))
                        .overlay(
                            Capsule()
                                .stroke(NeuPalette.borderSoft, lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Shared Layout & Pills

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

struct LabelPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
