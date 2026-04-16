import SwiftUI

/// A card view that displays a BeadIssue with PRD progress tracking.
///
/// Features:
/// - Visual progress bar showing task checklist completion percentage
/// - Acceptance criteria progress indicator
/// - Priority indicator with color coding
/// - Expandable task and criteria lists
/// - PRD generation button
///
/// Usage:
/// ```swift
/// @State var issue = BeadIssue.sample()
///
/// TaskCardView(issue: $issue)
/// ```
public struct TaskCardView: View {
    @Binding public var issue: BeadIssue
    @State private var isExpanded: Bool = false
    @State private var hoveredTask: String? = nil
    @State private var hoveredCriterion: String? = nil
    
    /// Animation namespace for smooth expand/collapse
    @Namespace private var animation
    
    /// Callback when a task status changes
    public var onTaskStatusChange: ((String, Bool) -> Void)?
    
    /// Callback when an acceptance criterion status changes
    public var onCriterionStatusChange: ((String, Bool) -> Void)?
    
    /// Initialize the task card view
    /// - Parameters:
    ///   - issue: Binding to the issue model
    ///   - initiallyExpanded: Whether to start expanded (default: false)
    ///   - onTaskStatusChange: Optional callback for task status changes
    ///   - onCriterionStatusChange: Optional callback for criterion status changes
    public init(
        issue: Binding<BeadIssue>,
        initiallyExpanded: Bool = false,
        onTaskStatusChange: ((String, Bool) -> Void)? = nil,
        onCriterionStatusChange: ((String, Bool) -> Void)? = nil
    ) {
        self._issue = issue
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.onTaskStatusChange = onTaskStatusChange
        self.onCriterionStatusChange = onCriterionStatusChange
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card header
            cardHeader
            
            // Expandable sections
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
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
                    Text(issue.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(issue.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                // Expand/collapse button
                expandButton
            }
            
            // PRD Progress section (main feature)
            prdProgressSection
            
            // Acceptance criteria progress
            if !issue.acceptanceCriteria.isEmpty {
                acceptanceCriteriaProgress
            }
        }
        .padding(16)
    }
    
    // MARK: - Priority Badge
    
    private var priorityBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: priorityIcon)
                .font(.title3)
                .foregroundColor(priorityColor)
            
            Text(issue.priority.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(priorityColor)
        }
        .frame(width: 44)
    }
    
    private var priorityIcon: String {
        switch issue.priority {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "arrow.up.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }
    
    private var priorityColor: Color {
        switch issue.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
    
    // MARK: - PRD Progress Section (Main Feature)
    
    private var prdProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("PRD Progress", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(issue.completedTaskCount)/\(issue.tasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(issue.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor))
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
                        .frame(width: geometry.size.width * issue.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: issue.progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressColor: Color {
        if issue.isComplete {
            return .green
        } else if issue.progress > 0.5 {
            return .blue
        } else if issue.progress > 0 {
            return .orange
        }
        return .gray
    }
    
    // MARK: - Acceptance Criteria Progress
    
    private var acceptanceCriteriaProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Acceptance Criteria", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let metCount = issue.acceptanceCriteria.filter { $0.isMet }.count
                Text("\(metCount)/\(issue.acceptanceCriteria.count) criteria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let criteriaProgress = issue.acceptanceCriteria.isEmpty ? 0 : 
                    Double(metCount) / Double(issue.acceptanceCriteria.count)
                Text("\(Int(criteriaProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(criteriaColor)
            }
            
            // Criteria progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 6)
                    
                    // Filled portion
                    let criteriaProgress = issue.acceptanceCriteria.isEmpty ? 0 : 
                        Double(issue.acceptanceCriteria.filter { $0.isMet }.count) / 
                        Double(issue.acceptanceCriteria.count)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(criteriaColor.opacity(0.8))
                        .frame(width: geometry.size.width * criteriaProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: criteriaProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.top, 4)
    }
    
    private var criteriaColor: Color {
        if issue.allCriteriaMet {
            return .green
        } else if issue.acceptanceCriteria.contains(where: { $0.isMet }) {
            return .mint
        }
        return .gray
    }
    
    // MARK: - Expand Button
    
    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                let totalItems = issue.tasks.count + issue.acceptanceCriteria.count
                Text("\(totalItems)")
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
                    .fill(Color(nsColor: .separatorColor).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            
            // Tasks checklist
            if !issue.tasks.isEmpty {
                tasksSection
            }
            
            // Acceptance criteria section
            if !issue.acceptanceCriteria.isEmpty {
                if !issue.tasks.isEmpty {
                    Divider()
                }
                acceptanceCriteriaSection
            }
            
            // Empty state
            if issue.tasks.isEmpty && issue.acceptanceCriteria.isEmpty {
                emptyStateView
            }
        }
    }
    
    // MARK: - Tasks Section
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label("Tasks Checklist", systemImage: "checklist")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status counts
                HStack(spacing: 8) {
                    let completedCount = issue.tasks.filter { $0.isCompleted }.count
                    let pendingCount = issue.tasks.count - completedCount
                    
                    if completedCount > 0 {
                        Text("\(completedCount)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                            .foregroundColor(.green)
                    }
                    
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.15))
                            )
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Task rows
            ForEach(issue.tasks) { task in
                taskRow(task)
                
                if task.id != issue.tasks.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
    
    private func taskRow(_ task: IssueTask) -> some View {
        HStack(spacing: 12) {
            // Status checkbox
            Button {
                toggleTaskStatus(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                hoveredTask = isHovered ? task.id : nil
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                
                if let assignee = task.assignee {
                    Label(assignee, systemImage: "person")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleTaskStatus(task)
        }
    }
    
    // MARK: - Acceptance Criteria Section
    
    private var acceptanceCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label("Acceptance Criteria", systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status counts
                HStack(spacing: 8) {
                    let metCount = issue.acceptanceCriteria.filter { $0.isMet }.count
                    let unmetCount = issue.acceptanceCriteria.count - metCount
                    
                    if metCount > 0 {
                        Text("\(metCount)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                            .foregroundColor(.green)
                    }
                    
                    if unmetCount > 0 {
                        Text("\(unmetCount)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.15))
                            )
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Criteria rows
            ForEach(issue.acceptanceCriteria) { criterion in
                criterionRow(criterion)
                
                if criterion.id != issue.acceptanceCriteria.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
    
    private func criterionRow(_ criterion: AcceptanceCriterion) -> some View {
        HStack(spacing: 12) {
            // Status checkbox
            Button {
                toggleCriterionStatus(criterion)
            } label: {
                Image(systemName: criterion.isMet ? "checkmark.seal.fill" : "seal")
                    .font(.body)
                    .foregroundColor(criterion.isMet ? .green : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                hoveredCriterion = isHovered ? criterion.id : nil
            }
            
            Text(criterion.description)
                .font(.subheadline)
                .foregroundColor(criterion.isMet ? .secondary : .primary)
                .strikethrough(criterion.isMet)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCriterionStatus(criterion)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No tasks or criteria defined")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private func toggleTaskStatus(_ task: IssueTask) {
        issue.toggleTask(id: task.id)
        onTaskStatusChange?(task.id, !task.isCompleted)
    }
    
    private func toggleCriterionStatus(_ criterion: AcceptanceCriterion) {
        issue.toggleCriterion(id: criterion.id)
        onCriterionStatusChange?(criterion.id, !criterion.isMet)
    }
}

// MARK: - Preview

#if DEBUG
struct TaskCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TaskCardView(issue: .constant(BeadIssue.sample()))
            
            TaskCardView(
                issue: .constant(BeadIssue(
                    beadId: "bead-002",
                    title: "Quick Bug Fix",
                    description: "Minor UI bug fix",
                    priority: .low
                ))
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
