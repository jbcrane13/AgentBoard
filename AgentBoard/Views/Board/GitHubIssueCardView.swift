import SwiftUI

/// Card view for displaying GitHub Issues in the Kanban board
struct GitHubIssueCardView: View {
    let issue: GitHubIssue
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Issue number and title
            HStack {
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Priority indicator from labels
                if issue.labels.contains(where: { $0.name.contains("priority:critical") }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else if issue.labels.contains(where: { $0.name.contains("priority:high") }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            
            Text(issue.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            // Labels
            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels.prefix(3), id: \.name) { label in
                        Text(label.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                    if issue.labels.count > 3 {
                        Text("+\(issue.labels.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Assignees
            if !issue.assignees.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.assignees.prefix(2), id: \.login) { assignee in
                        Text(assignee.login)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if issue.assignees.count > 2 {
                        Text("+\(issue.assignees.count - 2)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Actions
            HStack {
                Button("Details") {
                    showingDetail = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Spacer()
                
                if issue.state == "open" {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .sheet(isPresented: $showingDetail) {
            GitHubIssueDetailSheet(issue: issue)
        }
    }
}
