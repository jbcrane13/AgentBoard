import AgentBoardCore
import SwiftUI

struct CreateIssueSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepository: ConfiguredRepository?
    @State private var title = ""
    @State private var issueBody = ""
    @State private var selectedType: IssueType = .task
    @State private var selectedPriority: WorkPriority = .p2
    @State private var selectedStatus: WorkState = .ready
    @State private var selectedAgent: AgentName?
    @State private var milestoneText = ""
    @State private var isCreating = false

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
                            }

                            // ── Title (required) ──
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                    Text("•").foregroundStyle(.red).font(.caption)
                                }
                                NeuTextField(placeholder: "Issue title", text: $title)
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
                            }

                            // ── Milestone (optional) ──
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Milestone").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "Optional milestone", text: $milestoneText)
                            }

                            // ── Attachment (optional) ──
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Attachment").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                Button {
                                    // TODO: file picker integration
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .buttonStyle(NeuButtonTarget(isAccent: true))
                        .disabled(isCreating || title.trimmedOrNil == nil || selectedRepository == nil)
                }
            }
        }
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

        Task {
            await appModel.workStore.createIssue(
                repository: repo,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: issueBody.trimmingCharacters(in: .whitespacesAndNewlines),
                labels: mergedLabels.sorted(),
                assignees: [],
                milestone: Int(milestoneText.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            isCreating = false
            if appModel.workStore.errorMessage == nil {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    /// Consistent row layout: "Label:" followed by a dropdown field.
    private func labelDropdown<Content: View>(
        label: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label).font(.headline).foregroundStyle(NeuPalette.textPrimary)
                if required {
                    Text("•").foregroundStyle(.red).font(.caption)
                }
            }
            content()
                .tint(NeuPalette.accentCyan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .neuRecessed(cornerRadius: 16, depth: 6)
        }
    }
}
