import Foundation

/// Result of PRD generation
public enum PRDGenerationResult: Sendable {
    case success(markdown: String)
    case failure(PRDGeneratorError)
}

/// Errors that can occur during PRD generation
public enum PRDGeneratorError: Error, LocalizedError {
    case emptyTitle
    case emptyDescription
    case invalidIssue
    
    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Issue title cannot be empty"
        case .emptyDescription:
            return "Issue description cannot be empty"
        case .invalidIssue:
            return "Invalid issue data"
        }
    }
}

/// Service for generating PRD (Product Requirements Document) markdown from Bead issues
public final class PRDGenerator: Sendable {
    
    /// Initialize the PRD generator
    public init() {}
    
    /// Generate PRD markdown from a Bead issue
    /// - Parameter issue: The issue to convert to PRD markdown
    /// - Returns: PRDGenerationResult with markdown string on success
    public func generatePRD(from issue: BeadIssue) -> PRDGenerationResult {
        guard !issue.title.isEmpty else {
            return .failure(.emptyTitle)
        }
        guard !issue.description.isEmpty else {
            return .failure(.emptyDescription)
        }
        
        let markdown = buildMarkdown(from: issue)
        return .success(markdown: markdown)
    }
    
    /// Generate PRD markdown from multiple issues
    /// - Parameter issues: Array of issues to convert
    /// - Returns: PRDGenerationResult with combined markdown on success
    public func generatePRD(from issues: [BeadIssue]) -> PRDGenerationResult {
        guard !issues.isEmpty else {
            return .failure(.invalidIssue)
        }
        
        var markdownParts: [String] = []
        markdownParts.append("# Product Requirements Document")
        markdownParts.append("")
        markdownParts.append("*Generated on \(formattedDate())*")
        markdownParts.append("")
        markdownParts.append("---")
        markdownParts.append("")
        
        for (index, issue) in issues.enumerated() {
            guard !issue.title.isEmpty, !issue.description.isEmpty else {
                return .failure(issue.title.isEmpty ? .emptyTitle : .emptyDescription)
            }
            
            if index > 0 {
                markdownParts.append("")
                markdownParts.append("---")
                markdownParts.append("")
            }
            
            markdownParts.append(buildMarkdown(from: issue, includeHeader: true))
        }
        
        let combinedMarkdown = markdownParts.joined(separator: "\n")
        return .success(markdown: combinedMarkdown)
    }
    
    // MARK: - Private Methods
    
    private func buildMarkdown(from issue: BeadIssue, includeHeader: Bool = false) -> String {
        var lines: [String] = []
        
        // Title
        if includeHeader {
            lines.append("## \(issue.title)")
        } else {
            lines.append("# \(issue.title)")
        }
        lines.append("")
        
        // Priority badge
        lines.append("**Priority:** \(issue.priority.emoji) \(issue.priority.rawValue.capitalized)")
        lines.append("")
        
        // Progress indicator
        let progressPercent = Int(issue.progress * 100)
        let progressBar = generateProgressBar(issue.progress)
        lines.append("**Progress:** \(progressBar) \(progressPercent)% (\(issue.completedTaskCount)/\(issue.tasks.count) tasks)")
        lines.append("")
        
        // Description section
        lines.append("## Description")
        lines.append("")
        lines.append(issue.description)
        lines.append("")
        
        // Context section (if provided)
        if let context = issue.context, !context.isEmpty {
            lines.append("## Context")
            lines.append("")
            lines.append(context)
            lines.append("")
        }
        
        // Tasks checklist section
        if !issue.tasks.isEmpty {
            lines.append("## Tasks")
            lines.append("")
            
            for task in issue.tasks {
                let checkbox = task.isCompleted ? "[x]" : "[ ]"
                var taskLine = "- \(checkbox) \(task.title)"
                if let assignee = task.assignee {
                    taskLine += " *(assigned: \(assignee))*"
                }
                lines.append(taskLine)
            }
            lines.append("")
        }
        
        // Acceptance criteria section
        if !issue.acceptanceCriteria.isEmpty {
            lines.append("## Acceptance Criteria")
            lines.append("")
            
            for criterion in issue.acceptanceCriteria {
                let checkbox = criterion.isMet ? "[x]" : "[ ]"
                lines.append("- \(checkbox) \(criterion.description)")
            }
            lines.append("")
        }
        
        // Metadata footer
        lines.append("---")
        lines.append("")
        lines.append("*Issue ID: \(issue.id)*")
        lines.append("*Bead ID: \(issue.beadId)*")
        lines.append("*Created: \(formatDate(issue.createdAt))*")
        lines.append("*Last Updated: \(formatDate(issue.updatedAt))*")
        
        return lines.joined(separator: "\n")
    }
    
    private func generateProgressBar(_ progress: Double, width: Int = 10) -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled
        return "[\(String(repeating: "█", count: filled))\(String(repeating: "░", count: empty))]"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDate() -> String {
        formatDate(Date())
    }
}
