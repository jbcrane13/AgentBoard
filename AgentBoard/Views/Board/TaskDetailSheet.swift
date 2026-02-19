import SwiftUI

struct TaskDetailSheet: View {
    @Environment(AppState.self) private var appState
    let bead: Bead
    let onDismiss: () -> Void

    @State private var draft: BeadDraft
    @State private var closeReason = ""
    @State private var showCloseConfirm = false
    @State private var isSaving = false

    init(bead: Bead, onDismiss: @escaping () -> Void) {
        self.bead = bead
        self.onDismiss = onDismiss
        self._draft = State(initialValue: BeadDraft.from(bead))
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleSection
                    metadataSection
                    labelsSection
                    descriptionSection
                    datesSection
                    closeSection
                }
                .padding(20)
            }

            Divider()
            sheetFooter
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 580, idealHeight: 680)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(spacing: 10) {
            Text(bead.id)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            kindBadge

            priorityBadge

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("Issue title", text: $draft.title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
        }
    }

    // MARK: - Metadata (Status, Priority, Type, Assignee, Epic)

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("", selection: $draft.status) {
                        ForEach(BeadStatus.allCases, id: \.self) { status in
                            Text(statusLabel(status)).tag(status)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Priority")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("", selection: $draft.priority) {
                        Text("P0 - Critical").tag(0)
                        Text("P1 - High").tag(1)
                        Text("P2 - Medium").tag(2)
                        Text("P3 - Low").tag(3)
                        Text("P4 - Backlog").tag(4)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("", selection: $draft.kind) {
                        ForEach(BeadKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assignee")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("Unassigned", text: $draft.assignee)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                if draft.kind != .epic {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Epic")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Picker("", selection: Binding(
                            get: { draft.epicId ?? "All" },
                            set: { draft.epicId = $0 == "All" ? nil : $0 }
                        )) {
                            Text("None").tag("All")
                            ForEach(appState.epicBeads, id: \.id) { epic in
                                Text("\(epic.id) - \(epic.title)")
                                    .tag(epic.id)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 200)
                    }
                }
            }
        }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Labels")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("Comma-separated labels", text: $draft.labelsText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(text: $draft.description)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    // MARK: - Dates (read-only)

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timestamps")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Text("Created:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(bead.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 6) {
                    Text("Updated:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(bead.updatedAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Close Section

    private var closeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Close Issue")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                TextField("Close reason (optional)", text: $closeReason)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Button("Close") {
                    showCloseConfirm = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(bead.status == .done)
            }

            if bead.status == .done {
                Text("This issue is already closed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .alert("Close \(bead.id)?", isPresented: $showCloseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Close Issue", role: .destructive) {
                Task {
                    await appState.closeBeadWithReason(bead, reason: closeReason)
                    onDismiss()
                }
            }
        } message: {
            Text("This will mark the issue as done. \(closeReason.isEmpty ? "" : "Reason: \(closeReason)")")
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack(spacing: 8) {
            if let deps = dependencyText {
                Text(deps)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Save") {
                isSaving = true
                let draftToSave = draft
                Task {
                    await appState.updateBead(bead, with: draftToSave)
                    isSaving = false
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(16)
    }

    // MARK: - Helpers

    private var kindBadge: some View {
        Text(draft.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(kindColor(for: draft.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(kindColor(for: draft.kind))
    }

    private var priorityBadge: some View {
        let color = priorityColor(for: draft.priority)
        return Text("P\(draft.priority)")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var dependencyText: String? {
        guard !bead.dependencies.isEmpty else { return nil }
        return "Depends on: \(bead.dependencies.joined(separator: ", "))"
    }

    private func kindColor(for kind: BeadKind) -> Color {
        switch kind {
        case .task: .blue
        case .bug: .red
        case .feature: .green
        case .epic: .purple
        case .chore: .gray
        }
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 0: .red
        case 1: .orange
        case 2: .yellow
        case 3: .blue
        default: .gray
        }
    }

    private func statusLabel(_ status: BeadStatus) -> String {
        switch status {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done / Closed"
        }
    }
}
