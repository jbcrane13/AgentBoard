import AgentBoardCore
import SwiftUI

struct CreateIssueSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepository: ConfiguredRepository?
    @State private var title = ""
    @State private var body = ""
    @State private var labels = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BoardSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                BoardSectionTitle("New GitHub Issue")

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Repository").font(.headline).foregroundStyle(.white)
                                    Picker("Repository", selection: $selectedRepository) {
                                        Text("Select…").tag(Optional<ConfiguredRepository>.none)
                                        ForEach(appModel.settingsStore.repositories) { repo in
                                            Text(repo.fullName).tag(Optional(repo))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Title").font(.headline).foregroundStyle(.white)
                                    TextField("Issue title", text: $title)
                                        .fieldStyle()
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Description").font(.headline).foregroundStyle(.white)
                                    TextEditor(text: $body)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 120)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Labels (comma-separated)").font(.headline).foregroundStyle(.white)
                                    TextField("bug, priority:p1", text: $labels)
                                        .fieldStyle()
                                }
                            }
                        }

                        if let error = appModel.workStore.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(BoardPalette.coral)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Issue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .buttonStyle(.borderedProminent)
                        .tint(BoardPalette.cobalt)
                        .disabled(
                            selectedRepository == nil ||
                                title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                isCreating
                        )
                }
            }
        }
    }

    private func create() {
        guard let repo = selectedRepository else { return }
        isCreating = true
        let parsed = labels
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        Task {
            await appModel.workStore.createIssue(
                repository: repo,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                labels: parsed
            )
            isCreating = false
            if appModel.workStore.errorMessage == nil {
                dismiss()
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .foregroundStyle(.white)
    }
}
