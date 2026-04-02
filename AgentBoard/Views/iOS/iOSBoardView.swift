#if os(iOS)
    import SwiftUI

    struct iOSBoardView: View {
        @Environment(AppState.self) private var appState
        @State private var selectedColumn: BoardColumn = .open
        @State private var detailBead: Bead?
        @AppStorage("boardHideBacklog") private var hideBacklog = true

        enum BoardColumn: String, CaseIterable, Identifiable {
            case open = "Open"
            case inProgress = "Active"
            case blocked = "Blocked"
            case done = "Done"

            var id: String {
                rawValue
            }

            var status: BeadStatus {
                switch self {
                case .open: return .open
                case .inProgress: return .inProgress
                case .blocked: return .blocked
                case .done: return .done
                }
            }

            var color: Color {
                switch self {
                case .open: return .blue
                case .inProgress: return .orange
                case .blocked: return .red
                case .done: return .green
                }
            }
        }

        private static let activeStatusLabels: Set<String> = [
            "status:ready", "status:in-progress", "status:blocked", "status:review"
        ]

        private var columnBeads: [Bead] {
            appState.beads.filter { bead in
                guard bead.status == selectedColumn.status else { return false }
                if hideBacklog, bead.status != .done {
                    let lowered = Set(bead.labels.map { $0.lowercased() })
                    return !lowered.isDisjoint(with: Self.activeStatusLabels) || bead.labels.isEmpty
                }
                return true
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        }

        private func countForColumn(_ column: BoardColumn) -> Int {
            appState.beads.filter { bead in
                guard bead.status == column.status else { return false }
                if hideBacklog, bead.status != .done {
                    let lowered = Set(bead.labels.map { $0.lowercased() })
                    return !lowered.isDisjoint(with: Self.activeStatusLabels) || bead.labels.isEmpty
                }
                return true
            }.count
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // Column picker
                    columnPicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    Divider()

                    // Cards list
                    if appState.beadsFileMissing {
                        missingBeadsState
                    } else if columnBeads.isEmpty {
                        emptyColumnState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(columnBeads) { bead in
                                    TaskCardView(bead: bead)
                                        .onTapGesture {
                                            appState.selectedBeadID = bead.id
                                            detailBead = bead
                                        }
                                        .contextMenu {
                                            contextMenuItems(for: bead)
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .navigationTitle("Board")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                hideBacklog.toggle()
                            } label: {
                                Image(systemName: hideBacklog
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle")
                            }
                            .accessibilityIdentifier("ios_board_button_filter")

                            Button {
                                appState.requestCreateBeadSheet()
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityIdentifier("ios_board_button_add")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        projectPicker
                    }
                }
                .refreshable {
                    await appState.refreshBeads()
                }
                .sheet(item: $detailBead) { bead in
                    TaskDetailSheet(bead: bead) {
                        detailBead = nil
                    }
                }
            }
        }

        private var columnPicker: some View {
            HStack(spacing: 0) {
                ForEach(BoardColumn.allCases) { column in
                    let count = countForColumn(column)
                    let isSelected = selectedColumn == column

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColumn = column
                        }
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(column.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            isSelected ? column.color : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                }
                            }
                            .foregroundStyle(isSelected ? column.color : .secondary)

                            Rectangle()
                                .fill(isSelected ? column.color : .clear)
                                .frame(height: 2)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("ios_board_tab_\(column.rawValue.lowercased())")
                }
            }
        }

        private var emptyColumnState: some View {
            VStack(spacing: 12) {
                Image(systemName: selectedColumn == .done ? "checkmark.circle" : "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(selectedColumn == .done ? "All clear 🎉" : "No \(selectedColumn.rawValue.lowercased()) issues")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var missingBeadsState: some View {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No issues found for this project.")
                    .font(.system(size: 13, weight: .semibold))
                Button("Initialize") {
                    Task { await appState.initializeBeadsForSelectedProject() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ios_board_button_initialize")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        @ViewBuilder
        private func contextMenuItems(for bead: Bead) -> some View {
            if bead.status != .done {
                Button("Close Issue") {
                    Task { await appState.closeBead(bead) }
                }
            }
            Button("Delete", role: .destructive) {
                Task { await appState.deleteBead(bead) }
            }
        }

        private var projectPicker: some View {
            Menu {
                ForEach(appState.projects) { project in
                    Button(project.name) {
                        appState.selectProject(project)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.selectedProject?.name ?? "Projects")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier("ios_board_menu_project")
        }
    }
#endif
