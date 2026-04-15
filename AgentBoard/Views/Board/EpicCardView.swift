import SwiftUI

/// An expandable card view that displays an epic with its subtasks and progress.
///
/// Features:
/// - Expandable/collapsible subtask list
/// - Visual progress bar showing completion percentage
/// - Priority indicator with color coding
/// - Interactive subtask checkboxes
/// - Tag display
///
/// Usage:
/// ```swift
/// @State var epic = Epic.sample()
///
/// EpicCardView(epic: $epic)
/// ```
public struct EpicCardView: View {
    @Binding public var epic: Epic
    @State private var isExpanded: Bool = false
    @State private var hoveredSubtask: String? = nil
    
    /// Animation namespace for smooth expand/collapse
    @Namespace private var animation
    
    /// Callback when a subtask status changes
    public var onSubtaskStatusChange: ((String, TaskStatus) -> Void)?
    
    /// Initialize the epic card view
    /// - Parameters:
    ///   - epic: Binding to the epic model
    ///   - initiallyExpanded: Whether to start expanded (default: false)
    ///   - onSubtaskStatusChange: Optional callback for subtask status changes
    public init(
        epic: Binding<Epic>,
        initiallyExpanded: Bool = false,
        onSubtaskStatusChange: ((String, TaskStatus) -> Void)? = nil
    ) {
        self._epic = epic
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.onSubtaskStatusChange = onSubtaskStatusChange
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card header
            cardHeader
            
            // Expandable subtasks section
            if isExpanded {
                subtasksSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(platformCardBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(priorityColor.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    // MARK: - Card Header
    
    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row with priority badge
            HStack(alignment: .top) {
                // Priority indicator
                priorityBadge
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(epic.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    if let description = epic.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }
                
                Spacer()
                
                // Expand/collapse button
                expandButton
            }
            
            // Progress section
            progressSection
            
            // Tags
            if !epic.tags.isEmpty {
                tagsView
            }
            
            // Assignee and status row
            HStack {
                if let assignee = epic.assignee {
                    Label(assignee, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
        }
        .padding(16)
    }
    
    // MARK: - Priority Badge
    
    private var priorityBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: epic.priority == .critical ? "exclamationmark.triangle.fill" :
                  epic.priority == .high ? "arrow.up.circle.fill" :
                  epic.priority == .medium ? "minus.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundColor(priorityColor)
            
            Text(epic.priority.rawValue.capitalized)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(priorityColor)
        }
        .frame(width: 44)
    }
    
    private var priorityColor: Color {
        switch epic.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(epic.completedSubtaskCount)/\(epic.subtasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(epic.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(platformSeparatorColor)
                        .frame(height: 8)
                    
                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progressColor.opacity(0.8), progressColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * epic.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: epic.progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressColor: Color {
        if epic.isComplete {
            return .green
        } else if epic.progress > 0.5 {
            return .blue
        } else if epic.progress > 0 {
            return .orange
        }
        return .gray
    }
    
    // MARK: - Tags View
    
    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(epic.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                        )
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: epic.status.iconName)
                .font(.caption2)
            Text(epic.status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
        .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch epic.status {
        case .todo: return .gray
        case .inProgress: return .blue
        case .done: return .green
        case .blocked: return .red
        }
    }
    
    // MARK: - Expand Button
    
    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(epic.subtasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(platformSeparatorColor.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Subtasks Section
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            
            if epic.subtasks.isEmpty {
                emptySubtasksView
            } else {
                subtasksList
            }
        }
    }
    
    private var emptySubtasksView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No subtasks yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
    
    private var subtasksList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Subtasks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Filter buttons
                HStack(spacing: 8) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        let count = epic.subtasks.filter { $0.status == status }.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(statusColor(for: status).opacity(0.15))
                                )
                                .foregroundColor(statusColor(for: status))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Subtask rows
            ForEach(epic.subtasks) { subtask in
                subtaskRow(subtask)
                
                if subtask.id != epic.subtasks.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
    
    private func subtaskRow(_ subtask: Subtask) -> some View {
        HStack(spacing: 12) {
            // Status checkbox
            Button {
                toggleSubtaskStatus(subtask)
            } label: {
                Image(systemName: subtask.status.iconName)
                    .font(.body)
                    .foregroundColor(statusColor(for: subtask.status))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .onHover { isHovered in
                hoveredSubtask = isHovered ? subtask.id : nil
            }
            #endif
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subtask.title)
                    .font(.subheadline)
                    .foregroundColor(subtask.status == .done ? .secondary : .primary)
                    .strikethrough(subtask.status == .done)
                
                if let assignee = subtask.assignee {
                    Text(assignee)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status menu
            Menu {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button {
                        updateSubtaskStatus(subtask, newStatus: status)
                    } label: {
                        Label(status.rawValue, systemImage: status.iconName)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(hoveredSubtask == subtask.id ? platformSeparatorColor : Color.clear)
                    )
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Helpers
    
    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .todo: return .gray
        case .inProgress: return .blue
        case .done: return .green
        case .blocked: return .red
        }
    }

    private var platformCardBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    private var platformSeparatorColor: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
    
    private func toggleSubtaskStatus(_ subtask: Subtask) {
        let newStatus: TaskStatus = subtask.status == .done ? .todo : .done
        updateSubtaskStatus(subtask, newStatus: newStatus)
    }
    
    private func updateSubtaskStatus(_ subtask: Subtask, newStatus: TaskStatus) {
        epic.updateSubtask(id: subtask.id, status: newStatus)
        onSubtaskStatusChange?(subtask.id, newStatus)
    }
}

// MARK: - Preview

#if DEBUG
struct EpicCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EpicCardView(epic: .constant(Epic.sample()))
            
            EpicCardView(
                epic: .constant(Epic(
                    title: "Quick Fix",
                    description: "Small bug fix",
                    priority: .low,
                    status: .done,
                    subtasks: [
                        Subtask(title: "Fix the bug", status: .done)
                    ],
                    tags: ["bugfix"]
                ))
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
