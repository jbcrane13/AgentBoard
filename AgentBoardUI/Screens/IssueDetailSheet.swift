import AgentBoardCore
import SwiftUI

struct IssueDetailSheet: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let item: WorkItem

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var editLabels = ""
    @State private var editAssignees = ""
    @State private var editState: WorkState = .open
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            editForm
                        } else {
                            readView
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(item.issueReference)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") { save() }
                            .buttonStyle(.borderedProminent)
                            .tint(BoardPalette.cobalt)
                            .disabled(isSaving || editTitle.trimmedOrNil == nil)
                    } else {
                        Button("Edit") { beginEditing() }
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }
                }
            }
        }
    }

    private var readView: some View {
        VStack(alignment: .leading, spacing: 16) {
            BoardSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        WorkStatusPill(state: item.status)
                        PriorityPill(priority: item.priority)
                    }

                    if !item.assignees.isEmpty {
                        Label(item.assignees.joined(separator: ", "), systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(BoardPalette.paper.opacity(0.82))
                    }

                    if let milestone = item.milestone {
                        Label(milestone.title, systemImage: "flag")
                            .font(.subheadline)
                            .foregroundStyle(BoardPalette.gold)
                    }
                }
            }

            if !item.bodySummary.isEmpty {
                BoardSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(item.bodySummary)
                            .font(.body)
                            .foregroundStyle(BoardPalette.paper.opacity(0.82))
                            .textSelection(.enabled)
                    }
                }
            }

            if !item.labels.isEmpty {
                BoardSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Labels")
                            .font(.headline)
                            .foregroundStyle(.white)
                        FlowLayout(spacing: 8) {
                            ForEach(item.labels, id: \.self) { label in
                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule().fill(BoardPalette.cobalt.opacity(0.28))
                                    )
                            }
                        }
                    }
                }
            }

            BoardSurface {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Timeline")
                        .font(.headline)
                        .foregroundStyle(.white)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BoardPalette.paper.opacity(0.6))
                            Text(item.createdAt, style: .relative)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Updated")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BoardPalette.paper.opacity(0.6))
                            Text(item.updatedAt, style: .relative)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            BoardSurface {
                VStack(alignment: .leading, spacing: 14) {
                    BoardSectionTitle("Edit Issue")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title").font(.headline).foregroundStyle(.white)
                        TextField("Issue title", text: $editTitle)
                            .boardFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.headline).foregroundStyle(.white)
                        TextEditor(text: $editBody)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Labels (comma-separated)").font(.headline).foregroundStyle(.white)
                        TextField("bug, enhancement, priority:p1", text: $editLabels)
                            .boardFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assignees (comma-separated)").font(.headline).foregroundStyle(.white)
                        TextField("alice, bob", text: $editAssignees)
                            .boardFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Status").font(.headline).foregroundStyle(.white)
                        Picker("Status", selection: $editState) {
                            ForEach(WorkState.allCases) { state in
                                Text(state.title).tag(state)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            if isSaving {
                ProgressView("Saving…")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func beginEditing() {
        editTitle = item.title
        editBody = item.bodySummary
        editLabels = item.labels.joined(separator: ", ")
        editAssignees = item.assignees.joined(separator: ", ")
        editState = item.status
        isEditing = true
    }

    private func save() {
        isSaving = true
        let labels = editLabels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let assignees = editAssignees.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            await appModel.workStore.updateIssue(
                item,
                title: editTitle.trimmedOrNil,
                body: editBody.trimmedOrNil,
                labels: labels,
                assignees: assignees,
                state: editState
            )
            isSaving = false
            isEditing = false
            dismiss()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension View {
    func boardFieldStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .foregroundStyle(.white)
    }
}

