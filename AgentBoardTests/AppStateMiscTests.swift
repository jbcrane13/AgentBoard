import Foundation
import Testing
@testable import AgentBoard

@Suite("AppState Misc")
@MainActor
struct AppStateMiscTests {

    @Test("sendChatMessage with empty string does not append any messages")
    func sendChatMessageEmptyStringDoesNothing() async {
        let state = AppState()
        await state.sendChatMessage("")
        #expect(state.chatMessages.isEmpty)
    }

    @Test("sendChatMessage with whitespace-only string does not append any messages")
    func sendChatMessageWhitespaceDoesNothing() async {
        let state = AppState()
        await state.sendChatMessage("   \n  ")
        #expect(state.chatMessages.isEmpty)
    }

    @Test("sendChatMessage appends a user message and an assistant placeholder")
    func sendChatMessageAppendsUserAndAssistantMessages() async {
        let state = AppState()
        await state.sendChatMessage("hello")
        #expect(state.chatMessages.count >= 2)
        #expect(state.chatMessages[0].role == .user)
        #expect(state.chatMessages[0].content == "hello")
        #expect(state.chatMessages[1].role == .assistant)
    }

    @Test("dismissConnectionErrorToast sets showConnectionErrorToast to false")
    func dismissConnectionErrorToastSetsToFalse() {
        let state = AppState()
        state.showConnectionErrorToast = true
        state.dismissConnectionErrorToast()
        #expect(state.showConnectionErrorToast == false)
    }

    @Test("clearUnreadChatCount resets unreadChatCount to zero")
    func clearUnreadChatCountResetsToZero() {
        let state = AppState()
        state.unreadChatCount = 5
        state.clearUnreadChatCount()
        #expect(state.unreadChatCount == 0)
    }

    @Test("gitSummary returns summary for known bead ID and nil for unknown")
    func gitSummaryForBeadID() {
        let state = AppState()
        let commit = GitCommitRecord(
            sha: "abc123def456",
            shortSHA: "abc123d",
            authoredAt: Date(),
            subject: "test",
            refs: "",
            branch: "main",
            beadIDs: ["AB-1"]
        )
        let summary = BeadGitSummary(beadID: "AB-1", latestCommit: commit, commitCount: 1)
        state.beadGitSummaries["AB-1"] = summary

        #expect(state.gitSummary(for: "AB-1") != nil)
        #expect(state.gitSummary(for: "MISSING") == nil)
    }
}
