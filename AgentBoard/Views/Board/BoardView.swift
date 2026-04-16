import SwiftUI
import UniformTypeIdentifiers

struct BoardView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedKind: KindFilter = .all
    @State private var selectedAssignee: String = FilterOption.all
    @State private var selectedEpicID: String = FilterOption.all
    @State private var showingCreateSheet = false
    @State private var createDraft = BeadDraft()
    @State private var editDraft = BeadDraft()
    @State private var editingContext: EditingContext?
    @State private var detailContext: EditingContext?
    @State private var handledCreateRequestID = 0
    @State private var isRefreshing = false
    @AppStorage("boardHideBacklog") private var hideBacklog = true

    private struct Column: Identifiable {
        let id: String
        let title: String
        let status: BeadStatus
        let color: Color
    }

    private let columns: [Column] = [
        .init(id: "open", title: "Open", status: .open, color: .blue),
        .init(id: "in-progress", title: "In Progress", status: .inProgress, color: .orange),
        .init(id: "blocked", title: "Blocked", status: .blocked, color: .red),
        .init(id: "done", title: "Done", status: .done, color: .green)
    ]

    var body: some View {
        VStack(spacing: 12) {
            filterBar

            if let error = appState.githubError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.system(size: 12))
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        Task {
                            await appState.loadGitHubIssues()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        appState.githubError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if appState.beadsFileMissing {
                missingBeadsState
            } else {
                boardColumns
            }

            if let message = appState.statusMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .onAppear {
            handleCreateRequestIfNeeded()
        }
        .onChange(of: appState.createBeadSheetRequestID) { _, _ in
            handleCreateRequestIfNeeded()
        }
        .sheet(isPresented: $showingCreateSheet) {
            BeadEditorForm(
                title: "Create Bead",
                draft: $createDraft,
                availableEpics: appState.topLevelEpics,
                availableMilestones: appState.cachedMilestones,
                onCancel: {
                    showingCreateSheet = false
                    createDraft = BeadDraft()
                },
                onSave: {
                    let draft = createDraft
                    showingCreateSheet = false
                    createDraft = BeadDraft()
                    Task {
                        await appState.createBead(from: draft)
                    }
                }
            )
            .frame(minWidth: 540, minHeight: 500)
        }
        .sheet(item: $editingContext) { context in
            BeadEditorForm(
                title: "Edit \(context.bead.id)",
                draft: $editDraft,
                availableEpics: appState.topLevelEpics,
                availableMilestones: appState.cachedMilestones,
                onCancel: {
                    editingContext = nil
                    editDraft = BeadDraft()
                },
                onSave: {
                    let draft = editDraft
                    let bead = context.bead
                    editingContext = nil
                    editDraft = BeadDraft()
                    Task {
                        await appState.updateBead(bead, with: draft)
                    }
                }
            )
            .frame(minWidth: 540, minHeight: 500)
            .onAppear {
                editDraft = BeadDraft.from(context.bead)
            }
        }
        .sheet(item: $detailContext) { context in
            BeadTaskDetailSheetAdapter(bead: context.bead) {
                detailContext = nil
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Kind", selection: $selectedKind) {
                ForEach(KindFilter.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .accessibilityIdentifier("board_picker_kind")
            .frame(width: 140)

            Picker("Assignee", selection: $selectedAssignee) {
                Text(FilterOption.all).tag(FilterOption.all)
                ForEach(assignees, id: \.self) { assignee in
                    Text(assignee).tag(assignee)
                }
            }
            .accessibilityIdentifier("board_picker_assignee")
            .frame(width: 180)

            Picker("Epic", selection: $selectedEpicID) {
                Text(FilterOption.all).tag(FilterOption.all)
                ForEach(appState.topLevelEpics, id: \.id) { epic in
                    Text(epic.id).tag(epic.id)
                }
            }
            .accessibilityIdentifier("board_picker_epic")
            .frame(width: 170)

            Spacer()

            Button {
                hideBacklog.toggle()
            } label: {
                Label(
                    hideBacklog ? "Showing Active" : "Showing All",
                    systemImage: hideBacklog ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                )
                .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("board_button_backlog_filter")
            .help(hideBacklog ? "Show all issues including backlog" : "Hide backlog issues")

            Button {
                Task<Void, Never> {
                    isRefreshing = true
                    await appState.refreshBeads()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: isRefreshing ? "arrow.trianglehead.clockwise" : "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: isRefreshing)
            }
            .accessibilityIdentifier("board_button_refresh")
            .help("Refresh beads")
            .disabled(isRefreshing)

            Button {
                presentCreateSheet()
            } label: {
                Label(appState.isGitHubConfigured ? "New Issue" : "Create Bead", systemImage: "plus")
            }
            .accessibilityIdentifier("board_add_task_button")
            .buttonStyle(.borderedProminent)
        }
    }

    private var beadLookup: [String: Bead] {
        Dictionary(uniqueKeysWithValues: appState.beads.map { ($0.id, $0) })
    }

    private var boardColumns: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(columns) { column in
                boardColumn(column)
            }
        }
    }

    private func boardColumn(_ column: Column) -> some View {
        let columnBeads = filteredBeads.filter { $0.status == column.status }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(column.title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(column.color)

                Text("\(columnBeads.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.04), in: Capsule())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 8) {
                    if columnBeads.isEmpty {
                        Text(column.status == .done ? "All clear 🎉" : "No issues")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(columnBeads) { bead in
                            beadCard(bead)
                        }
                    }
                }
                .padding(8)
            }
            .background(columnBackground(for: column.status), in: RoundedRectangle(cornerRadius: 12))
            .onDrop(
                of: [UTType.plainText],
                delegate: BoardDropDelegate(
                    targetStatus: column.status,
                    beadLookup: beadLookup
                ) { bead, status in
                    Task {
                        await appState.moveBead(bead, to: status)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func beadCard(_ bead: Bead) -> some View {
        BeadTaskCardAdapter(bead: bead)
            .onDrag { NSItemProvider(object: bead.id as NSString) }
            .onTapGesture {
                appState.selectedBeadID = bead.id
                detailContext = EditingContext(bead: bead)
            }
            .contextMenu {
                Button("Edit") { editingContext = EditingContext(bead: bead) }
                    .accessibilityIdentifier("board_context_button_edit_\(bead.id)")
                if bead.status != .done {
                    Button("Close Issue") {
                        Task { await appState.closeBead(bead) }
                    }
                    .accessibilityIdentifier("board_context_button_close_\(bead.id)")
                }
                Button("Delete", role: .destructive) {
                    Task { await appState.deleteBead(bead) }
                }
                .accessibilityIdentifier("board_context_button_delete_\(bead.id)")
                Button("Assign to Agent") {
                    Task { await appState.assignBeadToAgent(bead) }
                }
                .accessibilityIdentifier("board_context_button_assign_\(bead.id)")
                Button("View in Terminal") {
                    Task { await appState.openBeadInTerminal(bead) }
                }
                .accessibilityIdentifier("board_context_button_terminal_\(bead.id)")
            }
    }

    private static let activeStatusLabels: Set<String> = [
        "status:ready", "status:in-progress", "status:blocked", "status:review"
    ]

    private var filteredBeads: [Bead] {
        appState.beads.filter { bead in
            let kindMatches = selectedKind == .all || bead.kind == selectedKind.beadKind
            let assigneeMatches = selectedAssignee == FilterOption.all || bead.assignee == selectedAssignee
            let epicMatches = selectedEpicID == FilterOption.all || appState.belongsToEpic(bead, epicID: selectedEpicID)

            let backlogMatches: Bool
            if hideBacklog, bead.status != .done {
                let lowered = Set(bead.labels.map { $0.lowercased() })
                backlogMatches = !lowered.isDisjoint(with: Self.activeStatusLabels)
                    || bead.labels.isEmpty // show issues with no labels (not yet triaged)
            } else {
                backlogMatches = true
            }

            return kindMatches && assigneeMatches && epicMatches && backlogMatches
        }
        .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }

    private var assignees: [String] {
        Set(appState.beads.compactMap { bead in
            let trimmed = bead.assignee?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        })
        .sorted()
    }

    private var missingBeadsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No .beads/issues.jsonl found for this project.")
                .font(.system(size: 13, weight: .semibold))

            Button("Initialize beads") {
                Task {
                    await appState.initializeBeadsForSelectedProject()
                }
            }
            .accessibilityIdentifier("board_button_initialize_beads")
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func columnBackground(for status: BeadStatus) -> Color {
        switch status {
        case .open:
            return Color.blue.opacity(0.03)
        case .inProgress:
            return Color.orange.opacity(0.04)
        case .blocked:
            return Color.red.opacity(0.04)
        case .done:
            return Color.green.opacity(0.03)
        }
    }

    private func presentCreateSheet() {
        createDraft = BeadDraft()
        showingCreateSheet = true
    }

    private func handleCreateRequestIfNeeded() {
        guard appState.createBeadSheetRequestID != handledCreateRequestID else { return }
        handledCreateRequestID = appState.createBeadSheetRequestID
        presentCreateSheet()
    }
}

private enum FilterOption {
    static let all = "All"
}

private enum KindFilter: String, CaseIterable {
    case all
    case task
    case bug
    case feature
    case epic
    case chore

    var label: String {
        switch self {
        case .all:
            return "All Kinds"
        case .task:
            return "Task"
        case .bug:
            return "Bug"
        case .feature:
            return "Feature"
        case .epic:
            return "Epic"
        case .chore:
            return "Chore"
        }
    }

    var beadKind: BeadKind? {
        switch self {
        case .all:
            return nil
        case .task:
            return .task
        case .bug:
            return .bug
        case .feature:
            return .feature
        case .epic:
            return .epic
        case .chore:
            return .chore
        }
    }
}

private struct EditingContext: Identifiable {
    let id = UUID()
    let bead: Bead
}

private struct BoardDropDelegate: DropDelegate {
    let targetStatus: BeadStatus
    let beadLookup: [String: Bead]
    let onMove: @MainActor (Bead, BeadStatus) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [UTType.plainText]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let itemID: String?
            if let data = item as? Data {
                itemID = String(data: data, encoding: .utf8)
            } else if let string = item as? NSString {
                itemID = string as String
            } else if let string = item as? String {
                itemID = string
            } else {
                itemID = nil
            }

            guard let rawID = itemID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let bead = beadLookup[rawID] else {
                return
            }

            Task { @MainActor in
                onMove(bead, targetStatus)
            }
        }

        return true
    }
}

private struct BeadEditorForm: View {
    let title: String
    @Binding var draft: BeadDraft
    let availableEpics: [Bead]
    let availableMilestones: [GitHubMilestone]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Divider()
            }

            Form {
                TextField("Title", text: $draft.title)
                    .accessibilityIdentifier("board_title_field")

                Picker("Kind", selection: $draft.kind) {
                    ForEach(BeadKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
                .accessibilityIdentifier("board_picker_bead_kind")

                Picker("Status", selection: $draft.status) {
                    ForEach(BeadStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .accessibilityIdentifier("board_picker_bead_status")

                Picker("Priority", selection: $draft.priority) {
                    Text("P0 - Critical").tag(0)
                    Text("P1 - High").tag(1)
                    Text("P2 - Medium").tag(2)
                    Text("P3 - Low").tag(3)
                    Text("P4 - Backlog").tag(4)
                }
                .accessibilityIdentifier("board_picker_bead_priority")

                Picker("Assignee", selection: $draft.assignee) {
                    ForEach(AgentDefinition.knownAgents) { agent in
                        Text(agent.displayName).tag(agent.id)
                    }
                }
                .accessibilityIdentifier("board_picker_bead_assignee")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Labels")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    GitHubLabelPicker(labelsText: $draft.labelsText)
                    TextField("Custom labels (comma-separated)", text: $draft.labelsText)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("board_labels_field")
                }
                .padding(.vertical, 4)

                if draft.kind != .epic {
                    Picker(
                        "Epic",
                        selection: Binding(
                            get: { draft.epicId ?? FilterOption.all },
                            set: { value in
                                draft.epicId = value == FilterOption.all ? nil : value
                            }
                        )
                    ) {
                        Text(FilterOption.all).tag(FilterOption.all)
                        ForEach(availableEpics, id: \.id) { epic in
                            Text("\(epic.id) - \(epic.title)")
                                .tag(epic.id)
                        }
                    }
                    .accessibilityIdentifier("board_picker_bead_epic")
                }

                if !availableMilestones.isEmpty {
                    Picker(
                        "Milestone",
                        selection: Binding(
                            get: { draft.milestoneNumber ?? 0 },
                            set: { draft.milestoneNumber = $0 == 0 ? nil : $0 }
                        )
                    ) {
                        Text("None").tag(0)
                        ForEach(availableMilestones) { milestone in
                            Text(milestone.title).tag(milestone.number)
                        }
                    }
                    .accessibilityIdentifier("board_picker_bead_milestone")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draft.description)
                        .accessibilityIdentifier("board_description_field")
                        .frame(minHeight: 140)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("board_button_cancel")
                Button("Save", action: onSave)
                    .accessibilityIdentifier("board_button_save")
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }
}
