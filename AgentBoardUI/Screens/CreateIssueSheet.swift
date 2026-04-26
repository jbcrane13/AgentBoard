import AgentBoardCore
import SwiftUI

struct CreateIssueSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepository: ConfiguredRepository?
    @State private var title = ""
    @State private var issueBody = ""
    @State private var selectedLabels: Set<String> = []
    @State private var customLabel = ""
    @State private var selectedAssignees: Set<String> = []
    @State private var customAssignee = ""
    @State private var selectedPriority: WorkPriority = .medium
    @State private var selectedStatus: WorkState = .open
    @State private var milestoneNumber = ""
    @State private var isCreating = false

    private var knownLabels: [String] {
        let allLabels = appModel.workStore.items.flatMap { $0.labels }
        return Array(Set(allLabels)).sorted()
    }

    private var knownAssignees: [String] {
        let allAssignees = appModel.workStore.items.flatMap { $0.assignees }
        return Array(Set(allAssignees)).sorted()
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

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Repository").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                Picker("Repository", selection: $selectedRepository) {
                                    Text("Select…").tag(ConfiguredRepository?.none)
                                    ForEach(appModel.settingsStore.repositories) { repo in
                                        Text(repo.fullName).tag(Optional(repo))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(NeuPalette.accentCyan)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .neuRecessed(cornerRadius: 16, depth: 6)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Title").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "Issue title", text: $title)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                TextEditor(text: $issueBody)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .neuRecessed(cornerRadius: 16, depth: 6)
                                    .foregroundStyle(NeuPalette.textPrimary)
                            }

                            // Labels — chip selector with known values
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Labels").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                if !knownLabels.isEmpty {
                                    FlowTagsView(items: knownLabels, selected: $selectedLabels) { label in
                                        Text(label).font(.caption)
                                    }
                                }
                                HStack(spacing: 8) {
                                    NeuTextField(placeholder: "Add custom label…", text: $customLabel)
                                    Button {
                                        let trimmed = customLabel.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            selectedLabels.insert(trimmed)
                                            customLabel = ""
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(NeuButtonTarget(isAccent: !customLabel.trimmed.isEmpty))
                                    .disabled(customLabel.trimmedOrNil == nil)
                                }
                            }

                            // Assignees — chip selector with known values
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assignees").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                if !knownAssignees.isEmpty {
                                    FlowTagsView(items: knownAssignees, selected: $selectedAssignees) { assignee in
                                        Text(assignee).font(.caption)
                                    }
                                }
                                HStack(spacing: 8) {
                                    NeuTextField(placeholder: "Add custom assignee…", text: $customAssignee)
                                    Button {
                                        let trimmed = customAssignee.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            selectedAssignees.insert(trimmed)
                                            customAssignee = ""
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(NeuButtonTarget(isAccent: !customAssignee.trimmed.isEmpty))
                                    .disabled(customAssignee.trimmedOrNil == nil)
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Priority").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                Picker("Priority", selection: $selectedPriority) {
                                    ForEach(WorkPriority.allCases) { priority in
                                        Text(priority.title).tag(priority)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(NeuPalette.accentOrange)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Status").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                Picker("Status", selection: $selectedStatus) {
                                    ForEach(WorkState.allCases) { state in
                                        Text(state.title).tag(state)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(NeuPalette.accentCyan)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Milestone Number").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "Optional milestone number", text: $milestoneNumber)
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

    private func create() {
        guard let repo = selectedRepository else { return }
        isCreating = true

        let mergedLabels = Array(selectedLabels + [selectedPriority.labelValue, selectedStatus.labelValue]).sorted()
        let assignees = Array(selectedAssignees)
        let milestone = Int(milestoneNumber.trimmingCharacters(in: .whitespacesAndNewlines))

        Task {
            await appModel.workStore.createIssue(
                repository: repo,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: issueBody.trimmingCharacters(in: .whitespacesAndNewlines),
                labels: mergedLabels,
                assignees: assignees,
                milestone: milestone
            )
            isCreating = false
            if appModel.workStore.errorMessage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - FlowTagsView

/// A simple wrapping tag layout for selectable chips.
private struct FlowTagsView<Item: Hashable, Content: View>: View {
    let items: [Item]
    @Binding var selected: Set<Item>
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        // Use a simple LazyVGrid with flexible columns for wrapping
        let columns = [GridItem(.adaptive(minimum: 60), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    if isSelected {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                } label: {
                    content(item)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? NeuPalette.accentCyan : NeuPalette.surface)
                        .foregroundStyle(isSelected ? NeuPalette.accentForeground : NeuPalette.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
