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
        .init(id: "done", title: "Done", status: .done, color: .green),
    ]

    var body: some View {
        VStack(spacing: 12) {
            filterBar

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
                availableEpics: appState.epicBeads,
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
                availableEpics: appState.epicBeads,
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
            TaskDetailSheet(bead: context.bead) {
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
            .frame(width: 140)

            Picker("Assignee", selection: $selectedAssignee) {
                Text(FilterOption.all).tag(FilterOption.all)
                ForEach(assignees, id: \.self) { assignee in
                    Text(assignee).tag(assignee)
                }
            }
            .frame(width: 180)

            Picker("Epic", selection: $selectedEpicID) {
                Text(FilterOption.all).tag(FilterOption.all)
                ForEach(appState.epicBeads, id: \.id) { epic in
                    Text(epic.id).tag(epic.id)
                }
            }
            .frame(width: 170)

            Spacer()

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
            .help("Refresh beads")
            .disabled(isRefreshing)

            Button {
                presentCreateSheet()
            } label: {
                Label("Create Bead", systemImage: "plus")
            }
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
                            TaskCardView(bead: bead)
                                .onDrag {
                                    NSItemProvider(object: bead.id as NSString)
                                }
                                .onTapGesture {
                                    appState.selectedBeadID = bead.id
                                    detailContext = EditingContext(bead: bead)
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        editingContext = EditingContext(bead: bead)
                                    }

                                    Button("Delete") {
                                        Task {
                                            await appState.closeBead(bead)
                                        }
                                    }

                                    Button("Assign to Agent") {
                                        Task {
                                            await appState.assignBeadToAgent(bead)
                                        }
                                    }

                                    Button("View in Terminal") {
                                        Task {
                                            await appState.openBeadInTerminal(bead)
                                        }
                                    }
                                }
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

    private var filteredBeads: [Bead] {
        appState.beads.filter { bead in
            let kindMatches = selectedKind == .all || bead.kind == selectedKind.beadKind
            let assigneeMatches = selectedAssignee == FilterOption.all || bead.assignee == selectedAssignee
            let epicMatches = selectedEpicID == FilterOption.all || bead.epicId == selectedEpicID
            return kindMatches && assigneeMatches && epicMatches
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

                Picker("Kind", selection: $draft.kind) {
                    ForEach(BeadKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }

                Picker("Status", selection: $draft.status) {
                    ForEach(BeadStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }

                Picker("Priority", selection: $draft.priority) {
                    Text("P0 - Critical").tag(0)
                    Text("P1 - High").tag(1)
                    Text("P2 - Medium").tag(2)
                    Text("P3 - Low").tag(3)
                    Text("P4 - Backlog").tag(4)
                }

                Picker("Assignee", selection: $draft.assignee) {
                    ForEach(AgentDefinition.knownAgents) { agent in
                        Text(agent.displayName).tag(agent.id)
                    }
                }
                TextField("Labels (comma-separated)", text: $draft.labelsText)

                if draft.kind != .epic {
                    Picker("Epic", selection: Binding(
                        get: { draft.epicId ?? FilterOption.all },
                        set: { value in
                            draft.epicId = value == FilterOption.all ? nil : value
                        })
                    ) {
                        Text(FilterOption.all).tag(FilterOption.all)
                        ForEach(availableEpics, id: \.id) { epic in
                            Text("\(epic.id) - \(epic.title)")
                                .tag(epic.id)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draft.description)
                        .frame(minHeight: 140)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
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
