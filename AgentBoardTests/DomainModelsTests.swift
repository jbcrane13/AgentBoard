import AgentBoardCore
import Foundation
import Testing

@Suite("DomainModels")
struct DomainModelsTests {
    // MARK: - WorkState

    @Test func workStateGitHubStateMapsDoneToClosed() {
        #expect(WorkState.done.githubState == "closed")
    }

    @Test func workStateGitHubStateMapsNonDoneToOpen() {
        #expect(WorkState.ready.githubState == "open")
        #expect(WorkState.inProgress.githubState == "open")
        #expect(WorkState.blocked.githubState == "open")
        #expect(WorkState.review.githubState == "open")
    }

    @Test func workStateLabelValueMatchesIssueLabelSchema() {
        #expect(WorkState.ready.labelValue == "status:ready")
        #expect(WorkState.inProgress.labelValue == "status:in-progress")
        #expect(WorkState.blocked.labelValue == "status:blocked")
        #expect(WorkState.review.labelValue == "status:review")
        #expect(WorkState.done.labelValue == "status:done")
    }

    @Test func workStateIsTerminalOnlyForDone() {
        #expect(WorkState.done.isTerminal)
        #expect(!WorkState.ready.isTerminal)
        #expect(!WorkState.inProgress.isTerminal)
        #expect(!WorkState.blocked.isTerminal)
        #expect(!WorkState.review.isTerminal)
    }

    @Test func workStateTitleMatchesUserCopy() {
        #expect(WorkState.ready.title == "Ready")
        #expect(WorkState.inProgress.title == "In Progress")
        #expect(WorkState.review.title == "Review")
    }

    // MARK: - WorkPriority

    @Test func workPriorityRankIsAscending() {
        #expect(WorkPriority.p0.rank == 0)
        #expect(WorkPriority.p1.rank == 1)
        #expect(WorkPriority.p2.rank == 2)
        #expect(WorkPriority.p3.rank == 3)
    }

    @Test func workPriorityRankPreservesSortOrder() {
        let priorities: [WorkPriority] = [.p3, .p0, .p2, .p1]
        let sorted = priorities.sorted { $0.rank < $1.rank }
        #expect(sorted == [.p0, .p1, .p2, .p3])
    }

    @Test func workPriorityTitleIsUppercased() {
        #expect(WorkPriority.p0.title == "P0")
        #expect(WorkPriority.p1.title == "P1")
        #expect(WorkPriority.p2.title == "P2")
        #expect(WorkPriority.p3.title == "P3")
    }

    @Test func workPriorityLabelValueMatchesIssueLabelSchema() {
        #expect(WorkPriority.p0.labelValue == "priority:p0")
        #expect(WorkPriority.p3.labelValue == "priority:p3")
    }

    // MARK: - ConfiguredRepository

    @Test func configuredRepositoryTrimsWhitespaceFromOwnerAndName() {
        let repo = ConfiguredRepository(owner: "  jbcrane13  ", name: "  AgentBoard\n")
        #expect(repo.owner == "jbcrane13")
        #expect(repo.name == "AgentBoard")
    }

    @Test func configuredRepositoryFullNameUsesSlashSeparator() {
        let repo = ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard")
        #expect(repo.fullName == "jbcrane13/AgentBoard")
    }

    @Test func configuredRepositoryShortNameReturnsName() {
        let repo = ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard")
        #expect(repo.shortName == "AgentBoard")
    }

    @Test func configuredRepositoryIDIsLowercaseFullName() {
        let repo = ConfiguredRepository(owner: "JbCrane13", name: "AgentBoard")
        #expect(repo.id == "jbcrane13/agentboard")
    }

    // MARK: - WorkReference / WorkItem

    @Test func workReferenceProducesIssueReferenceString() {
        let repo = ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard")
        let reference = WorkReference(repository: repo, issueNumber: 83)
        #expect(reference.issueReference == "jbcrane13/AgentBoard#83")
    }

    @Test func workItemIDEqualsIssueReference() {
        let item = makeWorkItem(issueNumber: 12)
        #expect(item.id == "jbcrane13/AgentBoard#12")
        #expect(item.id == item.issueReference)
    }

    @Test func workItemReferenceMatchesItsRepositoryAndNumber() {
        let item = makeWorkItem(issueNumber: 99)
        #expect(item.reference.repository.fullName == "jbcrane13/AgentBoard")
        #expect(item.reference.issueNumber == 99)
    }

    @Test func twoWorkItemsWithSameRepoAndNumberHaveSameID() {
        let itemA = makeWorkItem(issueNumber: 5)
        let itemB = makeWorkItem(issueNumber: 5, title: "Different title")
        #expect(itemA.id == itemB.id)
    }

    // MARK: - ChatConnectionState

    @Test func chatConnectionStateTitlesAreUserFacing() {
        #expect(ChatConnectionState.disconnected.title == "Offline")
        #expect(ChatConnectionState.connecting.title == "Connecting")
        #expect(ChatConnectionState.connected.title == "Live")
        #expect(ChatConnectionState.reconnecting.title == "Reconnecting")
        #expect(ChatConnectionState.failed.title == "Error")
    }

    // MARK: - AgentSessionStatus / AgentHealthStatus

    @Test func agentSessionStatusTitleIsCapitalized() {
        #expect(AgentSessionStatus.running.title == "Running")
        #expect(AgentSessionStatus.idle.title == "Idle")
        #expect(AgentSessionStatus.stopped.title == "Stopped")
        #expect(AgentSessionStatus.error.title == "Error")
    }

    @Test func agentHealthStatusTitleIsCapitalized() {
        #expect(AgentHealthStatus.online.title == "Online")
        #expect(AgentHealthStatus.idle.title == "Idle")
        #expect(AgentHealthStatus.warning.title == "Warning")
        #expect(AgentHealthStatus.offline.title == "Offline")
    }

    // MARK: - ConversationMessage decoding

    @Test func conversationMessageDecodesAttachmentsWhenPresent() throws {
        let conversationID = UUID().uuidString
        let messageID = UUID().uuidString
        let json = """
        {
          "id": "\(messageID)",
          "conversationID": "\(conversationID)",
          "role": "user",
          "content": "Hello",
          "createdAt": 731638800,
          "isStreaming": false,
          "attachments": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(ConversationMessage.self, from: Data(json.utf8))
        #expect(message.role == .user)
        #expect(message.attachments.isEmpty)
    }

    @Test func conversationMessageDecodesWithMissingAttachmentsDefaultsToEmpty() throws {
        let conversationID = UUID().uuidString
        let messageID = UUID().uuidString
        let json = """
        {
          "id": "\(messageID)",
          "conversationID": "\(conversationID)",
          "role": "assistant",
          "content": "Reply",
          "createdAt": 731638800,
          "isStreaming": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(ConversationMessage.self, from: Data(json.utf8))
        #expect(message.role == .assistant)
        #expect(message.isStreaming)
        #expect(message.attachments.isEmpty)
    }

    @Test func conversationMessageDecodesWithMissingToolActivitiesDefaultsToEmpty() throws {
        let conversationID = UUID().uuidString
        let messageID = UUID().uuidString
        let json = """
        {
          "id": "\(messageID)",
          "conversationID": "\(conversationID)",
          "role": "assistant",
          "content": "Reply",
          "createdAt": 731638800,
          "isStreaming": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(ConversationMessage.self, from: Data(json.utf8))
        #expect(message.toolActivities.isEmpty)
    }

    @Test func conversationMessageWithToolActivitiesRoundTripsThroughJSON() throws {
        let original = ConversationMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "Reply",
            toolActivities: [
                ToolActivity(id: "call_1", tool: "web_search", emoji: "🔍", label: "Searching…", isComplete: false),
                ToolActivity(id: "call_2", tool: "code_exec", emoji: nil, label: nil, isComplete: true)
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConversationMessage.self, from: data)
        #expect(decoded.toolActivities == original.toolActivities)
    }

    // MARK: - ChatConversation decoding

    @Test func chatConversationDecodesLegacyJSONWithoutHermesSessionIDToNil() throws {
        let conversationID = UUID().uuidString
        let json = """
        {
          "id": "\(conversationID)",
          "title": "Legacy Conversation",
          "updatedAt": 731638800
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let conversation = try decoder.decode(ChatConversation.self, from: Data(json.utf8))
        #expect(conversation.title == "Legacy Conversation")
        #expect(conversation.hermesSessionID == nil)
    }

    @Test func chatConversationRoundTripsHermesSessionIDThroughJSON() throws {
        let original = ChatConversation(
            title: "Conversation",
            hermesSessionID: "session-abc"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatConversation.self, from: data)
        #expect(decoded.hermesSessionID == "session-abc")
        #expect(decoded == original)
    }

    // MARK: - AgentBoardSettings decoding

    @Test func agentBoardSettingsDecodingFillsDefaultsForMissingKeys() throws {
        let json = "{}"
        let settings = try JSONDecoder().decode(AgentBoardSettings.self, from: Data(json.utf8))
        #expect(settings.hermesGatewayURL == "http://127.0.0.1:8641")
        #expect(settings.companionURL == "http://127.0.0.1:8742")
        #expect(settings.repositories.isEmpty)
        #expect(settings.autoRefreshInterval == 30)
        #expect(settings.designTheme == .blue)
    }

    @Test func agentBoardSettingsDecodingRespectsExplicitValues() throws {
        let json = """
        {
          "hermesGatewayURL": "http://example.com:1234",
          "autoRefreshInterval": 5,
          "designTheme": "grey"
        }
        """
        let settings = try JSONDecoder().decode(AgentBoardSettings.self, from: Data(json.utf8))
        #expect(settings.hermesGatewayURL == "http://example.com:1234")
        #expect(settings.autoRefreshInterval == 5)
        #expect(settings.designTheme == .grey)
    }

    @Test func agentBoardSettingsRoundTripsThroughJSON() throws {
        let original = AgentBoardSettings(
            hermesGatewayURL: "http://localhost:9000",
            hermesModelID: "hermes-test",
            companionURL: "http://localhost:9001",
            repositories: [ConfiguredRepository(owner: "acme", name: "demo")],
            autoRefreshInterval: 12,
            designTheme: .grey
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentBoardSettings.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Helpers

    private func makeWorkItem(
        issueNumber: Int,
        title: String = "Issue",
        priority: WorkPriority = .p2,
        status: WorkState = .ready
    ) -> WorkItem {
        let repo = ConfiguredRepository(owner: "jbcrane13", name: "AgentBoard")
        return WorkItem(
            repository: repo,
            issueNumber: issueNumber,
            title: title,
            bodySummary: "",
            isClosed: false,
            assignees: [],
            milestone: nil,
            labels: [],
            status: status,
            priority: priority,
            agentHint: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}
