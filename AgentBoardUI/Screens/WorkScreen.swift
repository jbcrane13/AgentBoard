import AgentBoardCore
import SwiftUI

private enum WorkLayoutMode: String, CaseIterable, Identifiable {
    case board
    case list

    var id: String {
        rawValue
    }
}

struct WorkScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var layoutMode: WorkLayoutMode = .board

    var body: some View {
        ZStack {
            BoardBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    BoardHeader(
                        eyebrow: "GitHub Work",
                        title: "Issues become the board, not beads",
                        subtitle: "The new work surface groups GitHub Issues into a modern board or list and lets status changes round-trip back to GitHub."
                    )

                    Spacer(minLength: 20)

                    VStack(alignment: .trailing, spacing: 10) {
                        Picker("Layout", selection: $layoutMode) {
                            ForEach(WorkLayoutMode.allCases) { mode in
                                Text(mode.rawValue.capitalized).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)

                        Button("Refresh") {
                            Task { await appModel.workStore.refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoardPalette.cobalt)
                    }
                }

                BoardSurface {
                    HStack(spacing: 14) {
                        TextField("Search issues, labels, or references", text: Bindable(appModel.workStore).searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.black.opacity(0.24))
                            )

                        Text("\(appModel.workStore.filteredItems.count) items")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BoardPalette.paper.opacity(0.78))
                    }
                }

                if appModel.workStore.filteredItems.isEmpty {
                    EmptyStateCard(
                        title: "No work items yet",
                        message: appModel.workStore.statusMessage
                            ??
                            "Connect a GitHub token and at least one repository in Settings to start filling the board.",
                        systemImage: "tray"
                    )
                } else if layoutMode == .board {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(appModel.workStore.groupedItems, id: \.state) { column in
                                BoardSurface {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            WorkStatusPill(state: column.state)
                                            Spacer()
                                            Text("\(column.items.count)")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                        }

                                        ForEach(column.items) { item in
                                            WorkCard(item: item)
                                        }
                                    }
                                    .frame(width: 320, alignment: .topLeading)
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(appModel.workStore.filteredItems) { item in
                                WorkCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct WorkCard: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    let item: WorkItem

    var body: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.issueReference)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BoardPalette.gold)

                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(WorkState.allCases) { state in
                            Button(state.title) {
                                Task {
                                    await appModel.workStore.updateStatus(for: item, to: state)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                Text(item.bodySummary.isEmpty ? "No body summary provided." : item.bodySummary)
                    .font(.subheadline)
                    .foregroundStyle(BoardPalette.paper.opacity(0.78))

                HStack(spacing: 8) {
                    WorkStatusPill(state: item.status)
                    PriorityPill(priority: item.priority)
                }

                HStack {
                    Text(item.assignees.isEmpty ? "Unassigned" : item.assignees.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(BoardPalette.paper.opacity(0.68))

                    Spacer()

                    Text(item.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(BoardPalette.paper.opacity(0.68))
                }
            }
        }
    }
}
