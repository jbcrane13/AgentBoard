import SwiftUI

/// A view that displays completed coding sessions with review request capability.
///
/// Features:
/// - List of completed sessions with agent and status info
/// - "Request Review" button for each completed session
/// - Integration with CrossReviewService for cross-agent reviews
/// - Visual indicators for review status
///
/// Usage:
/// ```swift
/// SessionListView(sessions: completedSessions)
/// ```
public struct SessionListView: View {
    public let sessions: [SessionLaunchResult]
    @State private var crossReviewService = CrossReviewService()
    @State private var reviewRequestedIds: Set<String> = []
    @State private var showingReviewAlert = false
    @State private var selectedSessionId: String?
    @State private var alertMessage = ""

    /// Initialize the session list view
    /// - Parameter sessions: Array of completed sessions to display
    public init(sessions: [SessionLaunchResult]) {
        self.sessions = sessions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()

            if sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }
        }
        .frame(minWidth: 320, idealWidth: 400)
        .alert("Review Request", isPresented: $showingReviewAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Completed Sessions")
                    .font(.headline)
            }

            Spacer()

            Text("\(sessions.count) sessions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No completed sessions")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Launch a session to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Session List

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: SessionLaunchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Agent indicator
                agentBadge(session.agent)

                Spacer()

                // Review status or request button
                if reviewRequestedIds.contains(session.id) {
                    reviewRequestedBadge
                } else {
                    requestReviewButton(for: session)
                }
            }

            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.epicId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(session.workingDirectory, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let branch = session.branchName {
                    Label(branch, systemImage: "arrow.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text("Launched \(session.launchedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - Agent Badge

    private func agentBadge(_ agent: CodingAgent) -> some View {
        HStack(spacing: 4) {
            Image(systemName: agent.iconName)
                .font(.caption)
            Text(agent.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(agent.brandColor.opacity(0.15))
        )
        .foregroundColor(agent.brandColor)
    }

    // MARK: - Review Requested Badge

    private var reviewRequestedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text("Review Requested")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.15))
        )
        .foregroundColor(.green)
    }

    // MARK: - Request Review Button

    private func requestReviewButton(for session: SessionLaunchResult) -> some View {
        Button {
            requestReview(for: session)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                Text("Request Review")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.purple)
    }

    // MARK: - Actions

    private func requestReview(for session: SessionLaunchResult) {
        // Determine reviewer based on the session's agent
        let reviewerAgent: String
        let authorAgent: String

        switch session.agent {
        case .claudeCode:
            reviewerAgent = "Codex"
            authorAgent = "Claude Code"
        case .codex:
            reviewerAgent = "Claude Code"
            authorAgent = "Codex"
        }

        // Start a review session
        let result = crossReviewService.startReview(
            reviewerAgent: reviewerAgent,
            authorAgent: authorAgent,
            codeSnippet: "Session: \(session.sessionId)\nDirectory: \(session.workingDirectory)\nCommand: \(session.command)",
            filePath: session.workingDirectory
        )

        switch result {
        case .success(let reviewSession):
            reviewRequestedIds.insert(session.id)
            selectedSessionId = session.id
            alertMessage = "Review requested successfully!\n\nReviewer: \(reviewSession.reviewerAgent)\nAuthor: \(reviewSession.authorAgent)\nReview ID: \(reviewSession.id)"
            showingReviewAlert = true

        case .failure(let error):
            alertMessage = "Failed to request review: \(error.localizedDescription)"
            showingReviewAlert = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SessionListView_Previews: PreviewProvider {
    static var previews: some View {
        SessionListView(sessions: [
            SessionLaunchResult(
                sessionId: "session-1",
                agent: .claudeCode,
                epicId: "Implement User Auth",
                workingDirectory: "~/workspace/auth",
                branchName: "feature/auth",
                command: "cd ~/workspace/auth && claude --issue \"123\" \"Auth\""
            ),
            SessionLaunchResult(
                sessionId: "session-2",
                agent: .codex,
                epicId: "Add Payment Gateway",
                workingDirectory: "~/workspace/payments",
                branchName: nil,
                command: "cd ~/workspace/payments && codex --issue \"456\" \"Payments\""
            )
        ])
    }
}
#endif
