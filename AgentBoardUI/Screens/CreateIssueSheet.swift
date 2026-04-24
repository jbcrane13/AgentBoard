import AgentBoardCore
import SwiftUI

struct CreateIssueSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepository: ConfiguredRepository?
    @State private var title = ""
    @State private var issueBody = ""
    @State private var labels = ""
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

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Labels (comma-separated)").font(.headline).foregroundStyle(NeuPalette.textPrimary)
                                NeuTextField(placeholder: "bug, enhancement", text: $labels)
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
            .navigationBarTitleDisplayMode(.inline)
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

        let parsedLabels = labels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task {
            await appModel.workStore.createIssue(
                repository: repo,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: issueBody.trimmingCharacters(in: .whitespacesAndNewlines),
                labels: parsedLabels
            )
            isCreating = false
            if appModel.workStore.errorMessage == nil {
                dismiss()
            }
        }
    }
}
