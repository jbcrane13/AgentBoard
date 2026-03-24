import SwiftUI

struct TaskDetailSheet: View {
    @Environment(AppState.self) private var appState
    let bead: Bead
    let onDismiss: () -> Void

    @State private var draft: BeadDraft
    @State private var closeReason = ""
    @State private var showCloseConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isSaving = false
    @State private var isAttaching = false
    @State private var showFilePicker = false
    @State private var attachedURLs: [String] = []

    init(bead: Bead, onDismiss: @escaping () -> Void) {
        self.bead = bead
        self.onDismiss = onDismiss
        _draft = State(initialValue: BeadDraft.from(bead))
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
                    attachmentsSection
                    datesSection
                    closeSection
                }
                .padding(20)
            }

            Divider()
            sheetFooter
        }
        .frame(
            minWidth: 560,
            idealWidth: 620,
            maxWidth: 720,
            minHeight: 400,
            idealHeight: 600,
            maxHeight: 680
        )
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
                .accessibilityIdentifier("task_detail_title_field")
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
                    .accessibilityIdentifier("task_detail_picker_status")
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
                    .accessibilityIdentifier("task_detail_picker_priority")
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
                    .accessibilityIdentifier("task_detail_picker_type")
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assignee")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("", selection: $draft.assignee) {
                        ForEach(AgentDefinition.knownAgents) { agent in
                            Text(agent.displayName).tag(agent.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                    .accessibilityIdentifier("task_detail_picker_assignee")
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
                        .accessibilityIdentifier("task_detail_picker_epic")
                    }
                }

                if !appState.cachedMilestones.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Milestone")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Picker("", selection: Binding(
                            get: { draft.milestoneNumber ?? 0 },
                            set: { draft.milestoneNumber = $0 == 0 ? nil : $0 }
                        )) {
                            Text("None").tag(0)
                            ForEach(appState.cachedMilestones) { milestone in
                                Text(milestone.title).tag(milestone.number)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 180)
                        .accessibilityIdentifier("task_detail_picker_milestone")
                    }
                }
            }
        }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Labels")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GitHubLabelPicker(labelsText: $draft.labelsText)

            TextField("Custom labels (comma-separated)", text: $draft.labelsText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("task_detail_labels_field")
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

    // MARK: - Attachments

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if !attachedURLs.isEmpty {
                ForEach(attachedURLs, id: \.self) { urlString in
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(URL(string: urlString)?.lastPathComponent ?? urlString)
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    showFilePicker = true
                } label: {
                    Label(
                        isAttaching ? "Uploading..." : "Attach File",
                        systemImage: "paperclip"
                    )
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .disabled(isAttaching || !appState.isGitHubConfigured)
                .accessibilityIdentifier("task_detail_button_attach")

                Button {
                    attachFromClipboard()
                } label: {
                    Label("Paste Screenshot", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .disabled(isAttaching || !appState.isGitHubConfigured)
                .accessibilityIdentifier("task_detail_button_paste_screenshot")
            }

            if !appState.isGitHubConfigured {
                Text("GitHub must be configured to attach files.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            attachFile(url)
        }
    }

    private func attachFile(_ fileURL: URL) {
        guard !isAttaching else { return }
        isAttaching = true
        let beadToAttach = bead
        Task<Void, Never> { @MainActor in
            if let downloadURL = await appState.attachFileToIssue(beadToAttach, fileURL: fileURL) {
                attachedURLs.append(downloadURL)
            }
            isAttaching = false
        }
    }

    private func attachFromClipboard() {
        guard let pasteboard = NSPasteboard.general.pasteboardItems?.first else { return }

        // Check for image data on the clipboard
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for imageType in imageTypes {
            if let data = pasteboard.data(forType: imageType) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clipboard-\(Int(Date().timeIntervalSince1970)).png")
                do {
                    // Convert TIFF to PNG if needed
                    let pngData: Data
                    if imageType == .tiff, let image = NSImage(data: data),
                       let tiffRep = image.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffRep),
                       let converted = bitmapRep.representation(using: .png, properties: [:]) {
                        pngData = converted
                    } else {
                        pngData = data
                    }
                    try pngData.write(to: tempURL)
                    attachFile(tempURL)
                } catch {
                    appState.setError("Failed to read clipboard: \(error.localizedDescription)")
                }
                return
            }
        }

        // Check for file URLs on the clipboard
        if let urlString = pasteboard.string(forType: .fileURL),
           let url = URL(string: urlString) {
            attachFile(url)
            return
        }

        appState.setError("No image or file found on clipboard.")
    }
}

// MARK: - Dates, Close, Footer sections (outside struct body for lint compliance)

extension TaskDetailSheet {
    var datesSection: some View {
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

    // MARK: - Actions Section

    var closeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Close
            if bead.status != .done {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Close Issue")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        TextField("Close reason (optional)", text: $closeReason)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .accessibilityIdentifier("task_detail_close_reason_field")

                        Button("Close") {
                            showCloseConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityIdentifier("task_detail_button_close_issue")
                    }
                }
            } else {
                Text("This issue is closed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Delete
            HStack {
                Spacer()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Issue", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityIdentifier("task_detail_button_delete")
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .alert("Close \(bead.id)?", isPresented: $showCloseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Close Issue", role: .destructive) {
                let reason = closeReason
                let beadToClose = bead
                let state = appState
                let dismiss = onDismiss
                Task {
                    await state.closeBeadWithReason(beadToClose, reason: reason)
                    await MainActor.run { dismiss() }
                }
            }
        } message: {
            Text("This will mark the issue as done. \(closeReason.isEmpty ? "" : "Reason: \(closeReason)")")
        }
        .alert("Delete \(bead.id)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) {
                let beadToDelete = bead
                let state = appState
                let dismiss = onDismiss
                Task {
                    await state.deleteBead(beadToDelete)
                    await MainActor.run { dismiss() }
                }
            }
        } message: {
            Text("This will permanently delete the issue. This cannot be undone.")
        }
    }

    // MARK: - Footer

    var sheetFooter: some View {
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
            .accessibilityIdentifier("task_detail_button_cancel")

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
            .accessibilityIdentifier("task_detail_button_save")
        }
        .padding(16)
    }

    // MARK: - Helpers

    var kindBadge: some View {
        Text(draft.kind.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(draft.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(draft.kind.color)
    }

    var priorityBadge: some View {
        let color = priorityColor(for: draft.priority)
        return Text("P\(draft.priority)")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    var dependencyText: String? {
        guard !bead.dependencies.isEmpty else { return nil }
        return "Depends on: \(bead.dependencies.joined(separator: ", "))"
    }

    func statusLabel(_ status: BeadStatus) -> String {
        switch status {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done / Closed"
        }
    }
}
