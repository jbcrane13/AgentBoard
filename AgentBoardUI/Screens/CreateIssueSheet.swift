import AgentBoardCore
import SwiftUI

struct CreateIssueSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    private let initialRepository: ConfiguredRepository?

    @State private var selectedRepository: ConfiguredRepository?
    @State private var title = ""
    @State private var issueBody = ""
    @State private var selectedType: IssueType = .task
    @State private var selectedPriority: WorkPriority = .p2
    @State private var selectedStatus: WorkState = .ready
    @State private var selectedAgent: AgentName?
    @State private var milestoneText = ""
    @State private var isCreating = false
    @State private var showAttachmentPicker = false
    @State private var pendingAttachments: [ChatAttachment] = []

    init(initialRepository: ConfiguredRepository? = nil) {
        self.initialRepository = initialRepository
        _selectedRepository = State(initialValue: initialRepository)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeuBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("NEW ISSUE")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)

                            // ── Repository (required) ──
                            labelDropdown(
                                label: "Repository",
                                required: true
                            ) {
                                Picker("Repository", selection: $selectedRepository) {
                                    Text("Select…").tag(ConfiguredRepository?.none)
                                    ForEach(appModel.settingsStore.repositories) { repo in
                                        Text(repo.fullName).tag(Optional(repo))
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityIdentifier("create_issue_picker_repository")
                            }

                            // ── Title (required) ──
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                    Text("•").foregroundStyle(.red).font(.caption)
                                }
                                NeuTextField(placeholder: "Issue title", text: $title)
                                    .accessibilityIdentifier("create_issue_textfield_title")
                            }

                            // ── Description ──
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                TextEditor(text: $issueBody)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .neuRecessed(cornerRadius: 16, depth: 6)
                                    .foregroundStyle(NeuPalette.textPrimary)
                                    .accessibilityIdentifier("create_issue_texteditor_body")
                            }

                            // ── Type (required) ──
                            labelDropdown(
                                label: "Type",
                                required: true
                            ) {
                                Picker("Type", selection: $selectedType) {
                                    ForEach(IssueType.allCases) { type in
                                        Text(type.title).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityIdentifier("create_issue_picker_type")
                            }

                            // ── Priority (required) ──
                            labelDropdown(
                                label: "Priority",
                                required: true
                            ) {
                                Picker("Priority", selection: $selectedPriority) {
                                    ForEach(WorkPriority.allCases) { priority in
                                        Text(priority.title).tag(priority)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityIdentifier("create_issue_picker_priority")
                            }

                            // ── Status (required) ──
                            labelDropdown(
                                label: "Status",
                                required: true
                            ) {
                                Picker("Status", selection: $selectedStatus) {
                                    ForEach(WorkState.allCases) { state in
                                        Text(state.title).tag(state)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityIdentifier("create_issue_picker_status")
                            }

                            // ── Agent (optional) ──
                            labelDropdown(
                                label: "Agent",
                                required: false
                            ) {
                                Picker("Agent", selection: $selectedAgent) {
                                    Text("None").tag(AgentName?.none)
                                    ForEach(AgentName.allCases) { agent in
                                        Text(agent.title).tag(Optional(agent))
                                    }
                                }
                                .pickerStyle(.menu)
                                .accessibilityIdentifier("create_issue_picker_agent")
                            }

                            // ── Milestone (optional) ──
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Milestone").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "Optional milestone", text: $milestoneText)
                                    .accessibilityIdentifier("create_issue_textfield_milestone")
                            }

                            // ── Attachment (optional) ──
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
                                .accessibilityIdentifier("create_issue_button_add_attachment")
                            }
                        }
                        .padding(24)
                        .neuExtruded(cornerRadius: 24, elevation: 8)

                        if isCreating {
                            ProgressView("Creating…")
                                .foregroundStyle(NeuPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if let error = appModel.workStore.errorMessage {
                            Text(error)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Issue")
            .agentBoardNavigationBarTitleInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NeuPalette.textPrimary)
                        .accessibilityIdentifier("create_issue_button_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .buttonStyle(NeuButtonTarget(isAccent: true))
                        .disabled(isCreating || title.trimmedOrNil == nil || selectedRepository == nil)
                        .accessibilityIdentifier("create_issue_button_create")
                }
            }
        }
        .sheet(isPresented: $showAttachmentPicker) {
            AttachmentPickerSheet { attachment in
                pendingAttachments.append(attachment)
            }
        }
        .onAppear {
            normalizeSelectedRepository()
        }
        .onChange(of: appModel.settingsStore.repositories) {
            normalizeSelectedRepository()
        }
        .accessibilityIdentifier("screen_create_issue")
    }

    // MARK: - Actions

    private func create() {
        guard let repo = selectedRepository else { return }
        isCreating = true

        let mergedLabels = [
            selectedType.labelValue,
            selectedPriority.labelValue,
            selectedStatus.labelValue
        ] + (selectedAgent.map { [$0.labelValue] } ?? [])

        var bodyText = issueBody.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let created = await appModel.workStore.createIssue(
                repository: repo,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText,
                labels: mergedLabels.sorted(),
                assignees: selectedAgent.map { [$0.githubUsername] } ?? [],
                milestone: Int(milestoneText.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            isCreating = false
            if created != nil {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func normalizeSelectedRepository() {
        let repositories = appModel.settingsStore.repositories
        if let selectedRepository,
           repositories.contains(selectedRepository) {
            return
        }

        if let initialRepository,
           repositories.contains(initialRepository) {
            selectedRepository = initialRepository
        } else if repositories.count == 1 {
            selectedRepository = repositories.first
        } else {
            selectedRepository = nil
        }
    }

    /// Inline row: label on the left, picker rendered as a tightly-hugged
    /// capsule chip on the right. No full-width recessed background, so the
    /// row no longer reads as an empty text field.
    private func labelDropdown<Content: View>(
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
