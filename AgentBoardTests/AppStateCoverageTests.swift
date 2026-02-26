import Foundation
import Testing
@testable import AgentBoard

@Suite("AppState Coverage")
@MainActor
struct AppStateCoverageTests {
    @Test("AppState defaults")
    func appStateDefaults() {
        let state = AppState()

        #expect(state.selectedTab == .board)
        #expect(state.rightPanelMode == .split)
        #expect(state.sidebarNavSelection == .board)
        #expect(state.canvasHistory.isEmpty)
        #expect(state.canvasHistoryIndex == -1)
        #expect(state.canvasZoom == 1.0)
        #expect(state.currentCanvasContent == nil)
        #expect(!state.canGoCanvasBack)
        #expect(!state.canGoCanvasForward)
    }

    @Test("switchToTab updates selected tab and sidebar mapping")
    func switchToTabBehavior() {
        let state = AppState()
        state.activeSessionID = "ses-1"

        state.switchToTab(.epics)
        #expect(state.selectedTab == .epics)
        #expect(state.sidebarNavSelection == .epics)
        #expect(state.activeSessionID == nil)

        state.switchToTab(.history)
        #expect(state.selectedTab == .history)
        #expect(state.sidebarNavSelection == .history)

        state.sidebarNavSelection = .board
        state.switchToTab(.agents)
        #expect(state.selectedTab == .agents)
        #expect(state.sidebarNavSelection == .board)
    }

    @Test("navigate updates sidebar selection and tab mapping")
    func navigateBehavior() {
        let state = AppState()
        state.selectedTab = .agents
        state.activeSessionID = "ses-1"

        state.navigate(to: .settings)
        #expect(state.sidebarNavSelection == .settings)
        #expect(state.selectedTab == .agents)
        #expect(state.activeSessionID == nil)

        state.navigate(to: .history)
        #expect(state.sidebarNavSelection == .history)
        #expect(state.selectedTab == .history)

        state.navigate(to: .board)
        #expect(state.sidebarNavSelection == .board)
        #expect(state.selectedTab == .board)
    }

    @Test("selection state from beads and openIssueFromChat")
    func selectionStateBehavior() {
        let state = AppState()
        let beadA = makeBead(id: "AB-1")
        let beadB = makeBead(id: "AB-2")
        state.beads = [beadA, beadB]

        state.selectedBeadID = "AB-2"
        #expect(state.selectedBead?.id == "AB-2")
        #expect(state.selectedBeadID == "AB-2")

        state.selectedBeadID = "MISSING"
        #expect(state.selectedBead == nil)
        #expect(state.selectedBeadID == "MISSING")

        state.openIssueFromChat(issueID: "AB-1")
        #expect(state.selectedBeadID == "AB-1")
        #expect(state.selectedTab == .board)
        #expect(state.sidebarNavSelection == .board)
    }

    @Test("chat input focus request resets unread count and panel mode")
    func chatInputFocusRequest() {
        let state = AppState()
        state.rightPanelMode = .canvas
        state.unreadChatCount = 4
        let initialRequestID = state.chatInputFocusRequestID

        state.requestChatInputFocus()

        #expect(state.rightPanelMode == .split)
        #expect(state.unreadChatCount == 0)
        #expect(state.chatInputFocusRequestID == initialRequestID + 1)
    }

    @Test("sheet request counters")
    func sheetRequestCounters() {
        let state = AppState()
        state.selectedTab = .history

        let initialCreateRequest = state.createBeadSheetRequestID
        let initialSessionRequest = state.newSessionSheetRequestID

        state.requestCreateBeadSheet()
        #expect(state.selectedTab == .board)
        #expect(state.createBeadSheetRequestID == initialCreateRequest + 1)

        state.requestNewSessionSheet()
        #expect(state.newSessionSheetRequestID == initialSessionRequest + 1)
    }

    @Test("canvas history navigation and zoom controls")
    func canvasHistoryAndZoom() throws {
        let state = AppState()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let c1 = CanvasContent.markdown(id: id1, title: "One", content: "1")
        let c2 = CanvasContent.markdown(id: id2, title: "Two", content: "2")
        let c3 = CanvasContent.markdown(id: id3, title: "Three", content: "3")

        state.pushCanvasContent(c1)
        #expect(state.canvasHistory.count == 1)
        #expect(state.canvasHistoryIndex == 0)
        #expect(state.currentCanvasContent?.id == id1)
        #expect(!state.canGoCanvasBack)
        #expect(!state.canGoCanvasForward)

        state.pushCanvasContent(c2)
        #expect(state.canvasHistory.count == 2)
        #expect(state.canvasHistoryIndex == 1)
        #expect(state.currentCanvasContent?.id == id2)
        #expect(state.canGoCanvasBack)

        state.goCanvasBack()
        #expect(state.currentCanvasContent?.id == id1)
        #expect(!state.canGoCanvasBack)
        #expect(state.canGoCanvasForward)

        state.pushCanvasContent(c3)
        #expect(state.canvasHistory.count == 2)
        #expect(state.canvasHistoryIndex == 1)
        #expect(state.currentCanvasContent?.id == id3)
        #expect(!state.canGoCanvasForward)

        state.adjustCanvasZoom(by: 10)
        #expect(state.canvasZoom == 2.0)
        state.adjustCanvasZoom(by: -10)
        #expect(state.canvasZoom == 0.6)
        state.resetCanvasZoom()
        #expect(state.canvasZoom == 1.0)

        state.clearCanvasHistory()
        #expect(state.canvasHistory.isEmpty)
        #expect(state.canvasHistoryIndex == -1)
        #expect(state.currentCanvasContent == nil)
    }

    @Test("openMessageInCanvas creates canvas content and enables canvas mode")
    func openMessageInCanvas() throws {
        let state = AppState()
        let codeMessage = ChatMessage(
            role: .assistant,
            content: "Here is code:\n```swift\nprint(\"hello\")\n```"
        )

        state.openMessageInCanvas(codeMessage)
        #expect(state.rightPanelMode == .canvas)
        let first = try #require(state.currentCanvasContent)

        switch first {
        case .markdown(_, let title, let content):
            #expect(title == "Code from Chat")
            #expect(content.contains("```swift"))
            #expect(content.contains("print(\"hello\")"))
        default:
            Issue.record("Expected markdown canvas content")
        }

        let plainMessage = ChatMessage(role: .assistant, content: "Plain response")
        state.openMessageInCanvas(plainMessage)
        let second = try #require(state.currentCanvasContent)

        switch second {
        case .markdown(_, let title, let content):
            #expect(title == "Message from Chat")
            #expect(content == "Plain response")
        default:
            Issue.record("Expected markdown canvas content")
        }
    }

    @Test("session selection and alert clearing")
    func sessionSelectionAndAlerts() {
        let state = AppState()
        state.sessionAlertSessionIDs = ["ses-1", "ses-2"]
        state.unreadSessionAlertsCount = 2
        let session = makeSession(id: "ses-1")

        state.openSessionInTerminal(session)
        #expect(state.activeSessionID == "ses-1")
        #expect(!state.sessionAlertSessionIDs.contains("ses-1"))
        #expect(state.unreadSessionAlertsCount == 1)

        state.backToBoardFromTerminal()
        #expect(state.activeSessionID == nil)
        #expect(state.selectedTab == .board)
        #expect(state.sidebarNavSelection == .board)

        state.clearSessionAlert(for: "does-not-exist")
        #expect(state.unreadSessionAlertsCount == 1)
    }

    @Test("epicBeads returns only epic-kind beads sorted by updatedAt descending")
    func epicBeadsFilteredAndSorted() {
        let state = AppState()
        let older = makeBead(id: "AB-epic1", kind: .epic, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = makeBead(id: "AB-epic2", kind: .epic, updatedAt: Date(timeIntervalSince1970: 1_700_001_000))
        let task = makeBead(id: "AB-task1", kind: .task, updatedAt: Date(timeIntervalSince1970: 1_700_002_000))
        state.beads = [older, task, newer]

        let epics = state.epicBeads
        #expect(epics.count == 2)
        #expect(epics[0].id == "AB-epic2") // newer first
        #expect(epics[1].id == "AB-epic1")
    }

    @Test("epicBeads is empty when no epic-kind beads exist")
    func epicBeadsEmptyWhenNoEpics() {
        let state = AppState()
        state.beads = [makeBead(id: "AB-1", kind: .task)]
        #expect(state.epicBeads.isEmpty)
    }

    @Test("activeSession returns session matching activeSessionID")
    func activeSessionReturnsMatchingSession() {
        let state = AppState()
        let session = makeSession(id: "ses-42")
        state.sessions = [session, makeSession(id: "ses-99")]
        state.activeSessionID = "ses-42"
        #expect(state.activeSession?.id == "ses-42")
    }

    @Test("activeSession returns nil when activeSessionID is nil")
    func activeSessionNilWhenIDNil() {
        let state = AppState()
        state.sessions = [makeSession(id: "ses-1")]
        state.activeSessionID = nil
        #expect(state.activeSession == nil)
    }

    @Test("activeSession returns nil when no session matches activeSessionID")
    func activeSessionNilWhenNoMatch() {
        let state = AppState()
        state.sessions = [makeSession(id: "ses-1")]
        state.activeSessionID = "ses-missing"
        #expect(state.activeSession == nil)
    }

    private func makeBead(id: String) -> Bead {
        makeBead(id: id, kind: .task, updatedAt: Date(timeIntervalSince1970: 1_700_000_100))
    }

    private func makeBead(id: String, kind: BeadKind, updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_100)) -> Bead {
        Bead(
            id: id,
            title: "Title \(id)",
            body: nil,
            status: .open,
            kind: kind,
            priority: 2,
            epicId: nil,
            labels: [],
            assignee: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: updatedAt,
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil
        )
    }

    private func makeSession(id: String) -> CodingSession {
        CodingSession(
            id: id,
            name: "Session \(id)",
            agentType: .codex,
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            beadId: nil,
            status: .running,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            elapsed: 10,
            model: "gpt-5.3-codex",
            processID: nil,
            cpuPercent: 1.0
        )
    }
}
