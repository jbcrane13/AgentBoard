import SwiftUI

struct EpicsView: View {
    @Environment(AppState.self) private var appState

    @State private var expandedEpicIDs: Set<String> = []
    @State private var showingCreateEpic = false
    @State private var epicTitle = ""
    @State private var epicDescription = ""
    @State private var selectedChildIssueIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Epics")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    showingCreateEpic = true
                } label: {
                    Label("Create Epic", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if appState.epicBeads.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("No epics yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.epicBeads) { epic in
                            epicCard(epic)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            if let status = appState.statusMessage {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showingCreateEpic) {
            createEpicSheet
                .frame(minWidth: 560, minHeight: 500)
        }
    }

    private func epicCard(_ epic: Bead) -> some View {
        let children = appState.beads
            .filter { $0.epicId == epic.id && $0.kind != .epic }
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
        let doneCount = children.filter { $0.status == .done }.count
        let totalCount = max(children.count, 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(epic.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(epic.title)
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()
                Text("\(doneCount)/\(children.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(doneCount), total: Double(totalCount))

            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedEpicIDs.contains(epic.id) },
                    set: { expanded in
                        if expanded {
                            expandedEpicIDs.insert(epic.id)
                        } else {
                            expandedEpicIDs.remove(epic.id)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    if children.isEmpty {
                        Text("No child issues")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(children) { child in
                            HStack(spacing: 8) {
                                Text(child.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text(child.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Text(child.status.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Child Issues")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private var createEpicSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Epic")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Divider()
            }

            Form {
                TextField("Epic title", text: $epicTitle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $epicDescription)
                        .frame(minHeight: 120)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Child issues")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if candidateChildren.isEmpty {
                        Text("No available child issues")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidateChildren) { bead in
                            Toggle(
                                isOn: Binding(
                                    get: { selectedChildIssueIDs.contains(bead.id) },
                                    set: { selected in
                                        if selected {
                                            selectedChildIssueIDs.insert(bead.id)
                                        } else {
                                            selectedChildIssueIDs.remove(bead.id)
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(bead.id) - \(bead.title)")
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    if let assignee = bead.assignee, !assignee.isEmpty {
                                        Text(assignee)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    closeCreateEpicSheet()
                }
                Button("Create") {
                    let title = epicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let description = epicDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    let childIDs = Array(selectedChildIssueIDs)
                    closeCreateEpicSheet()
                    Task {
                        await appState.createEpic(title: title, description: description, childIssueIDs: childIDs)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(epicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    private var candidateChildren: [Bead] {
        appState.beads
            .filter { $0.kind != .epic }
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }

    private func closeCreateEpicSheet() {
        showingCreateEpic = false
        epicTitle = ""
        epicDescription = ""
        selectedChildIssueIDs = []
    }
}
