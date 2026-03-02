import Foundation
import SwiftUI

enum CenterTab: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
    case agents = "Agents"
    case agentTasks = "Agent Tasks"
    case notes = "Notes"
    case history = "History"
}

enum SidebarNavItem: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
    case agentTasks = "Agent Tasks"
    case history = "History"
    case settings = "Settings"
}

enum RightPanelMode: String, CaseIterable, Sendable {
    case chat = "Chat"
    case canvas = "Canvas"
    case split = "Split"
}

@Observable
@MainActor
final class AppState {
    var projects: [Project] = []
    var selectedProjectID: UUID?
    var beads: [Bead] = []
    var sessions: [CodingSession] = []
    var chatMessages: [ChatMessage] = []
    var activeSessionID: String?

    var selectedTab: CenterTab = .board
    var rightPanelMode: RightPanelMode = .split
    var sidebarNavSelection: SidebarNavItem? = .board

    var appConfig: AppConfig = .empty
    var beadsFileMissing = false
    var isLoadingBeads = false
    var statusMessage: String?
    var errorMessage: String?
    private var errorDismissTask: Task<Void, Never>?
    private var errorProjectID: UUID?
    private var streamingSafetyTimeoutTask: Task<Void, Never>?
    var selectedBeadID: String?
    var chatConnectionState: OpenClawConnectionState = .disconnected
    var isChatStreaming = false
    var currentSessionKey: String = "main"
    var gatewaySessions: [GatewaySession] = []
    var chatThinkingLevel: String?
    var chatRunId: String?
    var agentName: String = "Assistant"
    var agentAvatar: String?
    var beadGitSummaries: [String: BeadGitSummary] = [:]
    var recentGitCommits: [GitCommitRecord] = []
    var currentGitBranch: String?
    var historyEvents: [HistoryEvent] = []
    var canvasHistory: [CanvasContent] = []
    var canvasHistoryIndex: Int = -1
    var canvasZoom: Double = 1.0
    var isCanvasLoading = false
    var unreadChatCount = 0
    var unreadSessionAlertsCount = 0
    var sessionAlertSessionIDs: Set<String> = []
    var newSessionSheetRequestID: Int = 0
    var createBeadSheetRequestID: Int = 0
    var chatInputFocusRequestID: Int = 0
    var connectionErrorDetail: ConnectionError?
    var showConnectionErrorToast = false
    var sidebarVisible: Bool = !UserDefaults.standard.bool(forKey: "AB_sidebarCollapsed")
    var boardVisible: Bool = !UserDefaults.standard.bool(forKey: "AB_boardCollapsed")

    let coordinationService = CoordinationService()
    let notesService = WorkspaceNotesService()

    private let configStore: AppConfigStore
    private let parser = JSONLParser()
    private let watcher = BeadsWatcher()
    private let openClawService: any OpenClawServicing
    private let sessionMonitor = SessionMonitor()
    private let gitService = GitService()
    private var watchedFilePath: String?
    private var chatReconnectTask: Task<Void, Never>?
    private var gatewaySessionRefreshTask: Task<Void, Never>?
    private var sessionMonitorTask: Task<Void, Never>?
    private var sessionStatusByID: [String: SessionStatus] = [:]
    private var sessionMonitorTick = 0
    private let gatewaySessionRefreshErrorPrefix = "Gateway session refresh failed:"
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    var selectedProject: Project? {
        guard let selectedProjectID else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    var epicBeads: [Bead] {
        beads.filter { $0.kind == .epic }
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
    }

    var selectedBead: Bead? {
        guard let selectedBeadID else { return nil }
        return beads.first(where: { $0.id == selectedBeadID })
    }

    var currentCanvasContent: CanvasContent? {
        guard canvasHistoryIndex >= 0, canvasHistoryIndex < canvasHistory.count else { return nil }
        return canvasHistory[canvasHistoryIndex]
    }

    var canGoCanvasBack: Bool {
        canvasHistoryIndex > 0
    }

    var canGoCanvasForward: Bool {
        canvasHistoryIndex >= 0 && canvasHistoryIndex < (canvasHistory.count - 1)
    }

    var activeSession: CodingSession? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    init(
        openClawService: any OpenClawServicing = OpenClawService(),
        configStore: AppConfigStore = AppConfigStore(),
        bootstrapOnInit: Bool = true,
        startBackgroundLoops: Bool = true
    ) {
        self.configStore = configStore
        self.openClawService = openClawService

        if bootstrapOnInit {
            bootstrap()
        }
        if startBackgroundLoops {
            startChatConnectionLoop()
            startSessionMonitorLoop()
            startGatewaySessionRefreshLoop()
            startBeadsPollingLoop()
            coordinationService.startPolling()
            notesService.goToToday()
        }

        // UI tests should always start from a fully visible dashboard layout.
        if isUITesting {
            sidebarVisible = true
            boardVisible = true
        }
    }

    func selectProject(_ project: Project) {
        selectedProjectID = project.id
        sidebarNavSelection = .board
        selectedTab = .board
        activeSessionID = nil
        clearErrorIfProjectChanged()
        persistSelectedProject()
        updateActiveProjectFlags()
        reloadSelectedProjectAndWatch()
    }

    private func clearErrorIfProjectChanged() {
        if let currentProjectID = selectedProjectID,
           let errorProject = errorProjectID,
           currentProjectID != errorProject {
            errorMessage = nil
        }
    }

    func setError(_ message: String?) {
        if let message {
            errorMessage = message
            startErrorDismissTimer()
        } else {
            errorMessage = nil
            cancelErrorDismissTimer()
        }
    }

    private func startErrorDismissTimer() {
        cancelErrorDismissTimer()
        errorProjectID = selectedProjectID
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.errorMessage = nil
                self.errorProjectID = nil
            }
        }
    }

    private func cancelErrorDismissTimer() {
        errorDismissTask?.cancel()
        errorDismissTask = nil
    }

    /// Starts a safety timeout to clear streaming indicator if final event never arrives
    private func startStreamingSafetyTimeout(timeoutSeconds: Int = 120) {
        streamingSafetyTimeoutTask?.cancel()
        streamingSafetyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                // Only clear if we're still in the same run
                self.isChatStreaming = false
            }
        }
    }

    private func cancelStreamingSafetyTimeout() {
        streamingSafetyTimeoutTask?.cancel()
        streamingSafetyTimeoutTask = nil
    }

    func updateShowToolOutput(_ value: Bool) {
        appConfig.showToolOutputInChat = value
        persistConfig()
    }

    func navigate(to item: SidebarNavItem) {
        sidebarNavSelection = item
        activeSessionID = nil
        switch item {
        case .board:
            selectedTab = .board
        case .epics:
            selectedTab = .epics
        case .agentTasks:
            selectedTab = .agentTasks
        case .history:
            selectedTab = .history
        case .settings:
            break
        }
    }

    func switchToTab(_ tab: CenterTab) {
        activeSessionID = nil
        selectedTab = tab
        switch tab {
        case .board:
            sidebarNavSelection = .board
        case .epics:
            sidebarNavSelection = .epics
        case .agentTasks:
            sidebarNavSelection = .agentTasks
        case .history:
            sidebarNavSelection = .history
        case .agents:
            break
        case .notes:
            break
        }
    }

    func requestCreateBeadSheet() {
        switchToTab(.board)
        createBeadSheetRequestID += 1
    }

    func requestNewSessionSheet() {
        newSessionSheetRequestID += 1
    }

    func requestChatInputFocus() {
        if rightPanelMode == .canvas {
            rightPanelMode = .split
        }
        chatInputFocusRequestID += 1
        clearUnreadChatCount()
    }

    func clearUnreadChatCount() {
        unreadChatCount = 0
    }

    func dismissConnectionErrorToast() {
        showConnectionErrorToast = false
    }

    private func dismissConnectionErrorToastAfterDelay() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            self?.showConnectionErrorToast = false
        }
    }

    func clearSessionAlert(for sessionID: String) {
        guard sessionAlertSessionIDs.remove(sessionID) != nil else { return }
        unreadSessionAlertsCount = sessionAlertSessionIDs.count
    }

    var isFocusMode: Bool {
        !sidebarVisible && !boardVisible
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
        persistLayoutState()
    }

    func toggleBoard() {
        boardVisible.toggle()
        persistLayoutState()
    }

    func toggleFocusMode() {
        if isFocusMode {
            sidebarVisible = true
            boardVisible = true
        } else {
            sidebarVisible = false
            boardVisible = false
        }
        persistLayoutState()
    }

    func persistLayoutState() {
        guard !isUITesting else { return }
        UserDefaults.standard.set(!sidebarVisible, forKey: "AB_sidebarCollapsed")
        UserDefaults.standard.set(!boardVisible, forKey: "AB_boardCollapsed")
    }

    func gitSummary(for beadID: String) -> BeadGitSummary? {
        beadGitSummaries[beadID]
    }

    func addProject(at folderURL: URL, icon: String = "📁") {
        let normalizedPath = folderURL.path
        guard !normalizedPath.isEmpty else { return }

        if appConfig.projects.contains(where: { $0.path == normalizedPath }) {
            statusMessage = "Project already exists."
            return
        }

        appConfig.projects.append(ConfiguredProject(path: normalizedPath, icon: icon))
        appConfig.selectedProjectPath = normalizedPath
        persistConfig()
        rebuildProjects()

        if let project = projects.first(where: { $0.path.path == normalizedPath }) {
            selectProject(project)
        }
    }

    func updateProjectsDirectory(_ path: String?) {
        appConfig.projectsDirectory = path
        persistConfig()

        // Re-discover projects from new directory, keeping manually-added ones
        let manualPaths = Set(appConfig.projects.map(\.path))
        let discovered = configStore.discoverProjects(in: appConfig.resolvedProjectsDirectory)
        let newProjects = discovered.filter { !manualPaths.contains($0.path) }
        appConfig.projects.append(contentsOf: newProjects)
        persistConfig()
        rebuildProjects()

        if let first = projects.first {
            selectProject(first)
        }
        statusMessage = "Projects directory updated."
    }

    func rescanProjectsDirectory() {
        let discovered = configStore.discoverProjects(in: appConfig.resolvedProjectsDirectory)
        let existingPaths = Set(appConfig.projects.map(\.path))
        let newProjects = discovered.filter { !existingPaths.contains($0.path) }
        if !newProjects.isEmpty {
            appConfig.projects.append(contentsOf: newProjects)
            persistConfig()
            rebuildProjects()
            statusMessage = "Found \(newProjects.count) new project(s)."
        } else {
            statusMessage = "No new projects found."
        }
    }

    func removeProject(_ project: Project) {
        appConfig.projects.removeAll { $0.path == project.path.path }

        if appConfig.selectedProjectPath == project.path.path {
            appConfig.selectedProjectPath = appConfig.projects.first?.path
        }

        persistConfig()
        rebuildProjects()

        if let selectedPath = appConfig.selectedProjectPath,
           let selected = projects.first(where: { $0.path.path == selectedPath }) {
            selectedProjectID = selected.id
        } else {
            selectedProjectID = projects.first?.id
        }

        updateActiveProjectFlags()
        reloadSelectedProjectAndWatch()
    }

    func retryConnection() {
        startChatConnectionLoop()
    }

    func updateOpenClaw(gatewayURL: String, token: String, source: String = "auto") {
        appConfig.openClawGatewayURL = gatewayURL.isEmpty ? nil : gatewayURL
        appConfig.openClawToken = token.isEmpty ? nil : token
        appConfig.gatewayConfigSource = source
        persistConfig()
        statusMessage = "Saved OpenClaw settings."
        startChatConnectionLoop()
    }

    func sendChatMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        clearUnreadChatCount()

        let contextID = selectedBeadID
        let userMessage = ChatMessage(role: .user, content: trimmed, beadContext: contextID)
        chatMessages.append(userMessage)

        let assistantID = UUID()
        chatMessages.append(
            ChatMessage(id: assistantID, role: .assistant, content: "", beadContext: contextID)
        )

        isChatStreaming = true
        errorMessage = nil

        do {
            let thinking = effectiveThinkingLevelForOutgoingMessage()
            try await openClawService.sendChat(
                sessionKey: currentSessionKey,
                message: trimmed,
                thinking: thinking
            )
            await refreshGatewaySessions()
            // Response will stream via gateway events handled in the event listener.
        } catch {
            replaceAssistantMessage(
                messageID: assistantID,
                content: "Failed to send message: \(error.localizedDescription)"
            )
            setError(error.localizedDescription)
            isChatStreaming = false
            startChatConnectionLoop()
        }
    }

    func abortChat() async {
        do {
            try await openClawService.abortChat(
                sessionKey: currentSessionKey,
                runId: chatRunId
            )
        } catch {
            setError(error.localizedDescription)
        }
    }

    func switchSession(to sessionKey: String) async {
        guard sessionKey != currentSessionKey else { return }
        let previousSessionKey = currentSessionKey
        let previousRunId = chatRunId
        let hadStreamingRun = isChatStreaming
        if hadStreamingRun {
            do {
                try await openClawService.abortChat(
                    sessionKey: previousSessionKey,
                    runId: previousRunId
                )
            } catch {
                // Best-effort abort. We still switch to keep UI responsive.
            }
        }
        currentSessionKey = sessionKey
        chatMessages = []
        chatRunId = nil
        isChatStreaming = false

        await loadChatHistory()
        await loadAgentIdentity()
    }

    func setThinkingLevel(_ level: String?) async {
        let normalized = normalizedThinkingLevel(level)
        do {
            try await openClawService.patchSession(
                key: currentSessionKey,
                thinkingLevel: normalized
            )
            chatThinkingLevel = normalized
            if let normalized {
                statusMessage = "Thinking set to \(normalized)."
            } else {
                statusMessage = "Thinking set to default."
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    func loadChatHistory() async {
        do {
            let history = try await openClawService.chatHistory(
                sessionKey: currentSessionKey,
                limit: 200
            )

            chatMessages = history.messages.compactMap { msg in
                // Only surface user and assistant turns — filter out tool calls,
                // tool results, system prompts, and any other internal role types
                let role: MessageRole
                switch msg.role {
                case "user": role = .user
                case "assistant": role = .assistant
                default: return nil
                }

                let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter out NO_REPLY markers and empty assistant messages
                if role == .assistant {
                    if text.isEmpty || text == "NO_REPLY" { return nil }
                }

                return ChatMessage(
                    role: role,
                    content: msg.text,
                    timestamp: msg.timestamp ?? .now
                )
            }
            chatThinkingLevel = normalizedThinkingLevel(history.thinkingLevel)
        } catch {
            // Don't show error for initial load — gateway may not be connected yet
            if chatConnectionState == .connected {
                setError(error.localizedDescription)
            }
        }
    }

    func loadAgentIdentity() async {
        do {
            let identity = try await openClawService.agentIdentity(
                sessionKey: currentSessionKey
            )
            agentName = identity.name
            agentAvatar = identity.avatar
        } catch {
            agentName = "Assistant"
            agentAvatar = nil
        }
    }

    func openIssueFromChat(issueID: String) {
        selectedBeadID = issueID
        selectedTab = .board
        sidebarNavSelection = .board
    }

    func openMessageInCanvas(_ message: ChatMessage) {
        let content: CanvasContent
        if let codeBlock = extractFirstCodeBlock(from: message.content) {
            let markdown = "```\(codeBlock.language)\n\(codeBlock.code)\n```"
            content = .markdown(
                id: UUID(),
                title: "Code from Chat",
                content: markdown
            )
        } else {
            content = .markdown(
                id: UUID(),
                title: "Message from Chat",
                content: message.content
            )
        }

        pushCanvasContent(content)
        rightPanelMode = .canvas
    }

    func pushCanvasContent(_ content: CanvasContent) {
        if canGoCanvasForward {
            canvasHistory = Array(canvasHistory.prefix(canvasHistoryIndex + 1))
        }
        canvasHistory.append(content)
        canvasHistoryIndex = canvasHistory.count - 1
    }

    func goCanvasBack() {
        guard canGoCanvasBack else { return }
        canvasHistoryIndex -= 1
    }

    func goCanvasForward() {
        guard canGoCanvasForward else { return }
        canvasHistoryIndex += 1
    }

    func clearCanvasHistory() {
        canvasHistory = []
        canvasHistoryIndex = -1
    }

    func adjustCanvasZoom(by delta: Double) {
        canvasZoom = min(max(canvasZoom + delta, 0.6), 2.0)
    }

    func resetCanvasZoom() {
        canvasZoom = 1.0
    }

    func openCanvasFile(_ url: URL) async {
        do {
            let content = try makeCanvasContent(from: url)
            pushCanvasContent(content)
            rightPanelMode = .canvas
            statusMessage = "Opened \(url.lastPathComponent) in canvas."
        } catch {
            setError(error.localizedDescription)
        }
    }

    func openCommitDiffInCanvas(beadID: String) async {
        guard let summary = beadGitSummaries[beadID] else { return }
        guard let project = selectedProject else { return }

        do {
            let diff = try await gitService.fetchCommitDiff(
                projectPath: project.path,
                commitSHA: summary.latestCommit.sha
            )
            let markdown = """
            ## Commit \(summary.latestCommit.shortSHA)
            \(summary.latestCommit.subject)

            ```diff
            \(diff)
            ```
            """
            pushCanvasContent(
                .markdown(
                    id: UUID(),
                    title: "Commit \(summary.latestCommit.shortSHA)",
                    content: markdown
                )
            )
            rightPanelMode = .canvas
            statusMessage = "Opened \(summary.latestCommit.shortSHA) diff in canvas."
        } catch {
            setError(error.localizedDescription)
        }
    }

    func openSessionInTerminal(_ session: CodingSession) {
        activeSessionID = session.id
        clearSessionAlert(for: session.id)
    }

    func backToBoardFromTerminal() {
        activeSessionID = nil
        selectedTab = .board
        sidebarNavSelection = .board
    }

    func captureTerminalOutput(for sessionID: String, lines: Int = 500) async -> String {
        do {
            return try await sessionMonitor.capturePane(session: sessionID, lines: lines)
        } catch {
            return "Unable to capture terminal output for \(sessionID).\n\n\(error.localizedDescription)"
        }
    }

    func nudgeSession(sessionID: String) async {
        do {
            try await sessionMonitor.sendNudge(session: sessionID)
            statusMessage = "Sent nudge to \(sessionID)."
        } catch {
            setError(error.localizedDescription)
        }
    }

    func createGatewaySession(
        project: Project,
        agentType: AgentType,
        beadID: String?,
        prompt: String?
    ) async -> Bool {
        do {
            let session = try await openClawService.createSession(
                label: nil,
                projectPath: project.path.path,
                agentType: agentType.rawValue,
                beadId: beadID,
                prompt: prompt
            )
            await switchSession(to: session.key)
            await refreshGatewaySessions()
            statusMessage = "Created session \(session.key)."
            return true
        } catch {
            setError(error.localizedDescription)
            return false
        }
    }

    /// Check if running in UI test mode with mocked terminal launcher
    private var isMockTerminalLauncherEnabled: Bool {
        UserDefaults.standard.bool(forKey: "AB_mockTerminalLauncher")
            || ProcessInfo.processInfo.arguments.contains("--mock-terminal-launcher")
    }

    @discardableResult
    func launchSession(
        project: Project,
        agentType: AgentType,
        beadID: String?,
        prompt: String?
    ) async -> Bool {
        do {
            let sessionID = try await sessionMonitor.launchSession(
                projectPath: project.path,
                agentType: agentType,
                beadID: beadID,
                prompt: prompt
            )
            statusMessage = "Launched session \(sessionID)."
            await refreshSessionsFromMonitor()
            activeSessionID = sessionID

            // Open the session in a terminal window (skip during UI tests)
            if !isMockTerminalLauncherEnabled {
                let tmuxSocketPath = "/tmp/openclaw-tmux-sockets/openclaw.sock"
                let attachCommand = "tmux -S \(tmuxSocketPath) attach -t \(sessionID)"

                do {
                    try await TerminalLauncher.openInTerminal(
                        command: attachCommand,
                        workingDirectory: project.path.path
                    )
                } catch {
                    // Terminal launch failed, but session was created - just log the error
                    print("Failed to open terminal window: \(error.localizedDescription)")
                }
            }

            return true
        } catch {
            setError(error.localizedDescription)
            return false
        }
    }

    func initializeBeadsForSelectedProject() async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            _ = try await runBD(arguments: ["bd", "init"], in: project)
            statusMessage = "Initialized beads for \(project.name)."
            reloadSelectedProjectAndWatch()
        } catch {
            setError(error.localizedDescription)
        }
    }

    func createBead(from draft: BeadDraft) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        guard project.isBeadsInitialized else {
            setError("Beads not initialized. Initialize beads first.")
            return
        }

        // Use bd CLI to create beads — works with both dolt and flat-file backends
        // Note: bd create doesn't support --status; we set it via bd update after creation
        let desiredStatus = draft.status.beadsValue
        var arguments = [
            "bd", "create",
            draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "--type", draft.kind.beadsValue,
            "--priority", "\(draft.priority)"
        ]

        let desc = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !desc.isEmpty {
            arguments.append(contentsOf: ["--description", desc])
        }

        let assignee = draft.assignee.trimmingCharacters(in: .whitespacesAndNewlines)
        if !assignee.isEmpty {
            arguments.append(contentsOf: ["--assignee", assignee])
        }

        if !draft.labels.isEmpty {
            for label in draft.labels {
                arguments.append(contentsOf: ["--set-labels", label])
            }
        }

        if let epicId = draft.epicId, !epicId.isEmpty, draft.kind != .epic {
            arguments.append(contentsOf: ["--parent", epicId])
        }

        do {
            let result = try await runBD(arguments: arguments, in: project)
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            // Extract bead ID from output (typically first word)
            let newID = output.components(separatedBy: .whitespaces).first ?? "bead"
            // bd create doesn't support --status, so set it via update if non-default
            if desiredStatus != "backlog" && desiredStatus != "open" {
                _ = try? await runBD(arguments: ["bd", "update", newID, "--status", desiredStatus], in: project)
            }
            statusMessage = "Created \(newID)."
            // Regenerate issues.jsonl from bd list for consistency
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError("Failed to create bead: \(error.localizedDescription)")
        }
    }

    func refreshBeads() async {
        guard let project = selectedProject else { return }
        await refreshBeadsFromCLI(for: project)
    }

    private func refreshBeadsFromCLI(for project: Project) async {
        do {
            try await fetchAndWriteIssuesJSONL(for: project)
            loadBeads(for: project)
        } catch {
            setError("Failed to refresh beads: \(error.localizedDescription)")
        }
    }

    /// Runs `bd list --all --json`, converts the JSON array to JSONL, and writes to issues.jsonl.
    private func fetchAndWriteIssuesJSONL(for project: Project) async throws {
        let result = try await runBD(arguments: ["bd", "list", "--all", "--json"], in: project)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = stdout.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let jsonl = array.compactMap { obj -> String? in
                guard let line = try? JSONSerialization.data(withJSONObject: obj),
                      let str = String(data: line, encoding: .utf8) else { return nil }
                return str
            }.joined(separator: "\n")
            try jsonl.write(to: project.issuesFileURL, atomically: true, encoding: .utf8)
        } else {
            try stdout.write(to: project.issuesFileURL, atomically: true, encoding: .utf8)
        }
    }

    func updateBead(_ bead: Bead, with draft: BeadDraft) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            var arguments = [
                "bd", "update", bead.id,
                "--title", draft.title,
                "--type", draft.kind.beadsValue,
                "--status", draft.status.beadsValue,
                "--priority", "\(draft.priority)",
                "--description", draft.description
            ]

            if !draft.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--assignee", draft.assignee])
            }

            if !draft.labels.isEmpty {
                for label in draft.labels {
                    arguments.append(contentsOf: ["--set-labels", label])
                }
            }

            if let epicId = draft.epicId, !epicId.isEmpty, draft.kind != .epic {
                arguments.append(contentsOf: ["--parent", epicId])
            } else {
                arguments.append(contentsOf: ["--parent", ""])
            }

            _ = try await runBD(arguments: arguments, in: project)
            statusMessage = "Updated \(bead.id)."
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func moveBead(_ bead: Bead, to status: BeadStatus) async {
        guard let project = selectedProject else { return }
        guard bead.status != status else { return }
        errorMessage = nil

        do {
            _ = try await runBD(
                arguments: ["bd", "update", bead.id, "--status", status.beadsValue],
                in: project
            )
            statusMessage = "Moved \(bead.id) to \(status.rawValue)."
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func closeBead(_ bead: Bead) async {
        await closeBeadWithReason(bead, reason: "Closed from AgentBoard board action")
    }

    func closeBeadWithReason(_ bead: Bead, reason: String) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            let reasonText = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalReason = reasonText.isEmpty ? "Closed from AgentBoard" : reasonText
            _ = try await runBD(
                arguments: ["bd", "close", bead.id, "--reason", finalReason],
                in: project
            )
            statusMessage = "Closed \(bead.id)."
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func deleteBead(_ bead: Bead) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            _ = try await runBD(
                arguments: ["bd", "delete", bead.id, "--force"],
                in: project
            )
            statusMessage = "Deleted \(bead.id)."
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError("Failed to delete bead: \(error.localizedDescription)")
        }
    }

    func assignBeadToAgent(_ bead: Bead, assignee: String = "agent") async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            // Update assignee in beads
            _ = try await runBD(
                arguments: ["bd", "update", bead.id, "--assignee", assignee, "--status", "in-progress"],
                in: project
            )

            // Launch a tmux Claude Code session to work on the bead
            let prompt = "Work on bead \(bead.id): \(bead.title)"
                + (bead.body.map { ". Description: \($0)" } ?? "")
                + ". When done, run: bd close \(bead.id)"
            let sessionID = try await sessionMonitor.launchSession(
                projectPath: project.path,
                agentType: .claudeCode,
                beadID: bead.id,
                prompt: prompt
            )

            statusMessage = "Assigned \(bead.id) to agent — session \(sessionID) launched."
            activeSessionID = sessionID
            await refreshSessionsFromMonitor()
            await refreshBeadsFromCLI(for: project)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func createEpic(title: String, description: String, childIssueIDs: [String]) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            var createArgs = [
                "bd", "create",
                "--title", title,
                "--type", "epic",
                "--priority", "2",
                "--silent"
            ]
            if !description.isEmpty {
                createArgs.append(contentsOf: ["--description", description])
            }

            let result = try await runBD(arguments: createArgs, in: project)
            guard let epicID = parseCreatedIssueID(from: result) else {
                throw NSError(domain: "AgentBoard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to determine created epic ID."])
            }

            for childIssueID in childIssueIDs {
                _ = try await runBD(
                    arguments: ["bd", "update", childIssueID, "--parent", epicID],
                    in: project
                )
            }

            statusMessage = "Created epic \(epicID)."
            reloadSelectedProjectAndWatch()
        } catch {
            setError(error.localizedDescription)
        }
    }

    func openBeadInTerminal(_ bead: Bead) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        let command = "bd show \(bead.id)"

        do {
            try await TerminalLauncher.openInTerminal(
                command: command,
                workingDirectory: project.path.path
            )
        } catch {
            setError(error.localizedDescription)
        }
    }

    private func bootstrap() {
        do {
            appConfig = try configStore.loadOrCreate()
        } catch {
            appConfig = .empty
            setError(error.localizedDescription)
        }

        rebuildProjects()

        if let selectedPath = appConfig.selectedProjectPath,
           let selected = projects.first(where: { $0.path.path == selectedPath }) {
            selectedProjectID = selected.id
        } else {
            selectedProjectID = projects.first?.id
        }

        updateActiveProjectFlags()
        reloadSelectedProjectAndWatch()
        startAutoRefresh(intervalSeconds: 210)
    }

    private func startSessionMonitorLoop() {
        sessionMonitorTask?.cancel()
        sessionMonitorTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.refreshSessionsFromMonitor()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func refreshSessionsFromMonitor() async {
        do {
            let updatedSessions = try await sessionMonitor.listSessions()
            let previousStatusByID = sessionStatusByID
            sessionStatusByID = Dictionary(uniqueKeysWithValues: updatedSessions.map { ($0.id, $0.status) })

            for session in updatedSessions {
                guard let previous = previousStatusByID[session.id], previous != session.status else { continue }
                if session.status == .stopped || session.status == .error {
                    sessionAlertSessionIDs.insert(session.id)
                }
            }

            let validSessionIDs = Set(updatedSessions.map(\.id))
            sessionAlertSessionIDs = Set(
                sessionAlertSessionIDs.filter { validSessionIDs.contains($0) }
            )

            unreadSessionAlertsCount = sessionAlertSessionIDs.count
            sessions = updatedSessions
            if let activeSessionID,
               !sessions.contains(where: { $0.id == activeSessionID }) {
                self.activeSessionID = nil
            }

            sessionMonitorTick += 1
            if sessionMonitorTick.isMultiple(of: 10), let selectedProject {
                Task { @MainActor in
                    await refreshGitContext(for: selectedProject)
                }
            }

            rebuildHistoryEvents()
        } catch {
            sessions = []
            if !SessionMonitor.isMissingTmuxServer(error: error) {
                setError(error.localizedDescription)
            }
            activeSessionID = nil
            sessionStatusByID = [:]
            sessionAlertSessionIDs = []
            unreadSessionAlertsCount = 0
            sessionMonitorTick = 0
            rebuildHistoryEvents()
        }
    }

    private func startChatConnectionLoop() {
        chatReconnectTask?.cancel()
        chatReconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var attempt = 0
            while !Task.isCancelled {
                do {
                    if attempt > 0 {
                        self.refreshAutoDiscoveredGatewayConfigOnReconnect()
                    }
                    try await self.openClawService.configure(
                        gatewayURLString: self.appConfig.openClawGatewayURL,
                        token: self.appConfig.openClawToken
                    )

                    self.chatConnectionState = attempt == 0 ? .connecting : .reconnecting

                    try await self.openClawService.connect()
                    self.chatConnectionState = .connected
                    self.connectionErrorDetail = nil
                    self.showConnectionErrorToast = false
                    attempt = 0

                    // Reset to main session on fresh connect
                    self.currentSessionKey = "main"
                    self.chatMessages = []

                    // Load history and identity on connect
                    await self.loadChatHistory()
                    await self.loadAgentIdentity()
                    await self.refreshGatewaySessions()

                    // Run event listener inline — blocks until the event
                    // stream finishes (i.e. the WebSocket disconnects).
                    // GatewayClient.disconnect/handleDisconnect finish the
                    // continuation, so this returns promptly on any drop.
                    await self.consumeGatewayEvents()

                    // After event stream ends (disconnect), mark as disconnected
                    self.chatConnectionState = .disconnected

                } catch {
                    attempt += 1
                    let classified = ConnectionError.classify(
                        error,
                        gatewayURL: self.appConfig.openClawGatewayURL ?? "http://127.0.0.1:18789"
                    )
                    self.connectionErrorDetail = classified

                    // Show toast on first failure or when error type changes
                    if attempt == 1 {
                        self.showConnectionErrorToast = true
                        self.dismissConnectionErrorToastAfterDelay()
                    }

                    // Stop retrying for auth/pairing errors — user must fix config
                    if classified.isNonRetryable {
                        self.chatConnectionState = .disconnected
                        break
                    }

                    self.chatConnectionState = .reconnecting
                    let backoffSeconds = min(pow(2.0, Double(max(attempt - 1, 0))), 30)
                    try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                }
            }

            self.chatConnectionState = .disconnected
        }
    }

    /// Consumes gateway events until the stream finishes (WebSocket disconnect)
    /// or the task is cancelled. Runs on MainActor so UI state updates are immediate.
    private func consumeGatewayEvents() async {
        let events = await openClawService.events

        for await event in events {
            guard !Task.isCancelled else { break }
            handleGatewayEventOnMain(event)
        }

        // Stream ended — connection dropped
        if !Task.isCancelled {
            isChatStreaming = false
            chatConnectionState = .reconnecting
        }
    }

    private func handleGatewayEventOnMain(_ event: GatewayEvent) {
        guard event.isChatEvent else { return }
        guard Self.matchesCurrentSessionKey(
            incoming: event.chatSessionKey,
            current: currentSessionKey
        ) else { return }

        let state = event.chatState ?? ""

        switch state {
        case "delta", "streaming":
            // Delta contains the full accumulated text so far
            if let text = event.chatMessageText {
                // Suppress tool/subagent output unless explicitly enabled
                let showToolOutput = appConfig.showToolOutputInChat ?? false
                if isToolOutput(text) && !showToolOutput {
                    // Skip tool output - don't add to chat
                    // But still track that we're in a run
                    chatRunId = event.chatRunId
                    isChatStreaming = true
                    // Start a safety timeout to clear streaming if final never arrives
                    startStreamingSafetyTimeout()
                    return
                }

                chatRunId = event.chatRunId
                isChatStreaming = true
                startStreamingSafetyTimeout()

                // Find the streaming assistant message to update.
                // During active streaming, the last assistant message is either
                // an empty placeholder (from sendChatMessage) or one we created
                // for an unsolicited reply. Match by checking if it's the last
                // message and is an assistant message.
                let lastIsAssistant = chatMessages.last?.role == .assistant
                if lastIsAssistant, let index = chatMessages.indices.last {
                    let msg = chatMessages[index]
                    chatMessages[index] = ChatMessage(
                        id: msg.id,
                        role: .assistant,
                        content: text,
                        timestamp: msg.timestamp,
                        beadContext: msg.beadContext,
                        sentToCanvas: msg.sentToCanvas
                    )
                } else {
                    // No active assistant message — unsolicited reply
                    // (heartbeat, cron, external message)
                    chatMessages.append(
                        ChatMessage(role: .assistant, content: text)
                    )
                }
            }

        case "final", "done":
            isChatStreaming = false
            chatRunId = nil
            cancelStreamingSafetyTimeout()

            // Finalize — reload full history to be safe
            Task {
                await loadChatHistory()
            }

        case "error":
            isChatStreaming = false
            chatRunId = nil
            cancelStreamingSafetyTimeout()
            let errorMsg = event.chatErrorMessage ?? "Chat error"

            // Update the last assistant message with the error
            if let index = chatMessages.lastIndex(where: { $0.role == .assistant }) {
                let msg = chatMessages[index]
                let content = msg.content.isEmpty
                    ? "Error: \(errorMsg)"
                    : msg.content
                chatMessages[index] = ChatMessage(
                    id: msg.id,
                    role: .assistant,
                    content: content,
                    timestamp: msg.timestamp,
                    beadContext: msg.beadContext,
                    sentToCanvas: msg.sentToCanvas
                )
            }
            setError(errorMsg)

        case "aborted":
            isChatStreaming = false
            chatRunId = nil
            cancelStreamingSafetyTimeout()
            statusMessage = "Response aborted."

        default:
            break
        }
    }

    private func startGatewaySessionRefreshLoop() {
        gatewaySessionRefreshTask?.cancel()
        gatewaySessionRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                guard let self, !Task.isCancelled else { break }
                await self.refreshGatewaySessions()
            }
        }
    }

    func refreshGatewaySessions() async {
        do {
            gatewaySessions = try await openClawService.listSessions(
                activeMinutes: 120,
                limit: 50
            )
            if errorMessage?.hasPrefix(gatewaySessionRefreshErrorPrefix) == true {
                setError(nil)
            }
        } catch {
            setError("\(gatewaySessionRefreshErrorPrefix) \(error.localizedDescription)")
        }
    }

    /// Seeds deterministic dashboard fixtures for UI tests.
    func applyDashboardUITestFixtures(empty: Bool = false) {
        let alpha = Project(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            name: "Dashboard Alpha",
            path: URL(fileURLWithPath: "/tmp/dashboard-alpha"),
            beadsPath: URL(fileURLWithPath: "/tmp/dashboard-alpha/.beads"),
            icon: "📊",
            isActive: true,
            openCount: 11,
            inProgressCount: 7,
            totalCount: 30
        )
        let beta = Project(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            name: "Dashboard Beta",
            path: URL(fileURLWithPath: "/tmp/dashboard-beta"),
            beadsPath: URL(fileURLWithPath: "/tmp/dashboard-beta/.beads"),
            icon: "📈",
            isActive: false,
            openCount: 2,
            inProgressCount: 1,
            totalCount: 4
        )

        projects = [alpha, beta]
        selectedProjectID = alpha.id
        selectedTab = .board
        sidebarNavSelection = .board
        rightPanelMode = .canvas
        chatConnectionState = .connected
        unreadChatCount = 41
        statusMessage = nil
        errorMessage = nil
        activeSessionID = nil
        selectedBeadID = nil

        beads = [
            Bead(
                id: "AB-100",
                title: "Alpha open issue",
                body: nil,
                status: .open,
                kind: .task,
                priority: 2,
                epicId: nil,
                labels: [],
                assignee: "codex",
                createdAt: .now.addingTimeInterval(-40_000),
                updatedAt: .now.addingTimeInterval(-2_000),
                dependencies: [],
                gitBranch: nil,
                lastCommit: nil
            ),
            Bead(
                id: "AB-101",
                title: "Alpha in-progress issue",
                body: nil,
                status: .inProgress,
                kind: .feature,
                priority: 1,
                epicId: nil,
                labels: [],
                assignee: "claude-code",
                createdAt: .now.addingTimeInterval(-30_000),
                updatedAt: .now.addingTimeInterval(-1_800),
                dependencies: [],
                gitBranch: nil,
                lastCommit: nil
            )
        ]

        if empty {
            sessions = []
            coordinationService.agentStatuses = []
            coordinationService.handoffs = []
        } else {
            sessions = [
                CodingSession(
                    id: "ab-alpha-run",
                    name: "ab-alpha-run",
                    agentType: .codex,
                    projectPath: alpha.path,
                    beadId: "AB-100",
                    status: .running,
                    startedAt: .now.addingTimeInterval(-1_200),
                    elapsed: 1_200,
                    model: "gpt-5.3-codex",
                    processID: 1001,
                    cpuPercent: 3.4
                ),
                CodingSession(
                    id: "ab-alpha-idle",
                    name: "ab-alpha-idle",
                    agentType: .claudeCode,
                    projectPath: alpha.path,
                    beadId: "AB-101",
                    status: .idle,
                    startedAt: .now.addingTimeInterval(-2_400),
                    elapsed: 2_400,
                    model: "claude-sonnet-4-5",
                    processID: 1002,
                    cpuPercent: 0.0
                ),
                CodingSession(
                    id: "ab-beta-stopped",
                    name: "ab-beta-stopped",
                    agentType: .openCode,
                    projectPath: beta.path,
                    beadId: nil,
                    status: .stopped,
                    startedAt: .now.addingTimeInterval(-90_000),
                    elapsed: 3_000,
                    model: "open-code",
                    processID: 1003,
                    cpuPercent: 0.0
                )
            ]

            coordinationService.agentStatuses = [
                AgentStatusEntry(
                    id: "agent-claude",
                    agent: "claude-code",
                    status: "working",
                    currentTask: "Fix dashboard tests",
                    updated: "2026-02-27"
                ),
                AgentStatusEntry(
                    id: "agent-codex",
                    agent: "codex",
                    status: "idle",
                    currentTask: "",
                    updated: "2026-02-27"
                )
            ]
            coordinationService.handoffs = [
                HandoffEntry(
                    id: "handoff-1",
                    fromAgent: "claude-code",
                    toAgent: "codex",
                    task: "Review parser output",
                    context: "Expand this row to verify handoff context visibility.",
                    status: "pending",
                    beadId: "AB-100",
                    date: "2026-02-27"
                )
            ]
        }

        historyEvents = [
            HistoryEvent(
                occurredAt: .now.addingTimeInterval(-3_600),
                type: .beadCreated,
                title: "Alpha Bead Created",
                details: "Created AB-100",
                projectName: alpha.name,
                beadID: "AB-100"
            ),
            HistoryEvent(
                occurredAt: .now.addingTimeInterval(-172_800),
                type: .commit,
                title: "Beta Commit Event",
                details: "Fixes AB-200",
                projectName: beta.name,
                beadID: "AB-200",
                commitSHA: "deadbeef"
            ),
            HistoryEvent(
                occurredAt: .now.addingTimeInterval(-864_000),
                type: .sessionStarted,
                title: "Alpha Session Event",
                details: "Session started",
                projectName: alpha.name
            ),
            HistoryEvent(
                occurredAt: .now.addingTimeInterval(-3_600_000),
                type: .sessionCompleted,
                title: "Beta Old Session Event",
                details: "Outside 30 day filter",
                projectName: beta.name
            )
        ]
    }

    private static func matchesCurrentSessionKey(incoming: String?, current: String) -> Bool {
        guard let incoming else { return false }
        let incomingNormalized = incoming.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentNormalized = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if incomingNormalized == currentNormalized {
            return true
        }
        if (incomingNormalized == "agent:main:main" && currentNormalized == "main") ||
            (incomingNormalized == "main" && currentNormalized == "agent:main:main") {
            return true
        }
        return false
    }

    private func normalizedThinkingLevel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "off", "minimal", "low", "medium", "high":
            return normalized
        default:
            return nil
        }
    }

    private func effectiveThinkingLevelForOutgoingMessage() -> String {
        normalizedThinkingLevel(chatThinkingLevel) ?? "off"
    }

    private func refreshAutoDiscoveredGatewayConfigOnReconnect() {
        guard !appConfig.isGatewayManual else { return }
        guard let discovered = configStore.discoverOpenClawConfig() else { return }
        if let url = discovered.gatewayURL, !url.isEmpty {
            appConfig.openClawGatewayURL = url
        }
        if let token = discovered.token, !token.isEmpty {
            appConfig.openClawToken = token
        }
    }

    private func rebuildProjects() {
        let existingIDsByPath = Dictionary(uniqueKeysWithValues: projects.map { ($0.path.path, $0.id) })
        projects = appConfig.projects.map { configuredProject in
            let url = URL(fileURLWithPath: configuredProject.path, isDirectory: true)
            let id = existingIDsByPath[configuredProject.path] ?? UUID()
            return Project(
                id: id,
                name: url.lastPathComponent,
                path: url,
                beadsPath: url.appendingPathComponent(".beads", isDirectory: true),
                icon: configuredProject.icon,
                isActive: false,
                openCount: 0,
                inProgressCount: 0,
                totalCount: 0
            )
        }

        refreshProjectCounts()
    }

    private func reloadSelectedProjectAndWatch() {
        guard let selectedProject else {
            beads = []
            beadsFileMissing = false
            beadGitSummaries = [:]
            recentGitCommits = []
            currentGitBranch = nil
            historyEvents = []
            watcher.stop()
            watchedFilePath = nil
            return
        }

        let project = selectedProject
        loadBeads(for: project)
        watch(project: project)
        Task { @MainActor in
            await refreshBeadsFromCLI(for: project)
            await refreshGitContext(for: project)
        }
    }

        private var autoRefreshTask: Task<Void, Never>?

    func startAutoRefresh(intervalSeconds: Int = 60) {
        stopAutoRefresh()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard let self, !Task.isCancelled else { break }
                await self.refreshBeads()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private var isInitialLoad = true

    private func loadBeads(for project: Project) {
        guard !isLoadingBeads else { return }
        isLoadingBeads = true
        defer { isLoadingBeads = false }

        let issuesURL = project.issuesFileURL

        // For dolt backend projects, always refresh from CLI on initial load or if file is missing
        // This ensures we never show stale data from a previous session
        let shouldRefreshFromCLI = project.isBeadsInitialized && (isInitialLoad || !FileManager.default.fileExists(atPath: issuesURL.path))

        if shouldRefreshFromCLI {
            isInitialLoad = false
            Task {
                do {
                    try await fetchAndWriteIssuesJSONL(for: project)
                    await MainActor.run { self.loadBeads(for: project) }
                } catch {
                    await MainActor.run {
                        beads = []
                        beadsFileMissing = true
                        setError("Failed to load beads via CLI: \(error.localizedDescription)")
                        refreshProjectCounts()
                        rebuildHistoryEvents()
                    }
                }
            }
            return
        }

        guard FileManager.default.fileExists(atPath: issuesURL.path) else {
            beads = []
            beadsFileMissing = true
            refreshProjectCounts()
            rebuildHistoryEvents()
            return
        }

        do {
            beads = try parser.parseBeads(from: issuesURL)
            beadsFileMissing = false
            selectedBeadID = selectedBeadID.flatMap { existingID in
                beads.contains(where: { $0.id == existingID }) ? existingID : nil
            }
            refreshProjectCounts()
            rebuildHistoryEvents()
        } catch {
            beads = []
            beadsFileMissing = true
            setError(error.localizedDescription)
            rebuildHistoryEvents()
        }
    }

    private func startBeadsPollingLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let project = selectedProject else { continue }
                loadBeads(for: project)
            }
        }
    }

    private func watch(project: Project) {
        let issuesURL = project.issuesFileURL
        // For dolt-backend projects, watch config.yaml instead since issues.jsonl
        // may not exist yet (it gets created on first load via bd list --json)
        let watchURL: URL
        if FileManager.default.fileExists(atPath: issuesURL.path) {
            watchURL = issuesURL
        } else if project.isBeadsInitialized {
            watchURL = project.beadsPath.appendingPathComponent("config.yaml")
        } else {
            watcher.stop()
            watchedFilePath = nil
            return
        }

        guard watchedFilePath != watchURL.path else { return }
        watchedFilePath = watchURL.path
        watcher.watch(
            fileURL: watchURL,
            onChange: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    guard let current = self.selectedProject else { return }
                    self.loadBeads(for: current)
                }
            },
            onError: { [weak self] message in
                Task { @MainActor in
                    self?.setError(message)
                }
            }
        )
    }

    private func refreshProjectCounts() {
        let selectedID = selectedProjectID
        projects = projects.map { project in
            var updatedProject = project
            let issuesURL = project.issuesFileURL

            if let parsed = try? parser.parseBeads(from: issuesURL) {
                updatedProject.totalCount = parsed.count
                updatedProject.openCount = parsed.filter { $0.status == .open }.count
                updatedProject.inProgressCount = parsed.filter { $0.status == .inProgress }.count
            } else {
                updatedProject.totalCount = 0
                updatedProject.openCount = 0
                updatedProject.inProgressCount = 0
            }

            updatedProject.isActive = project.id == selectedID
            return updatedProject
        }
    }

    private func updateActiveProjectFlags() {
        let selectedID = selectedProjectID
        projects = projects.map { project in
            var updatedProject = project
            updatedProject.isActive = project.id == selectedID
            return updatedProject
        }
    }

    private func persistSelectedProject() {
        guard let selectedProject else { return }
        appConfig.selectedProjectPath = selectedProject.path.path
        persistConfig()
    }

    private func persistConfig() {
        do {
            try configStore.save(appConfig)
        } catch {
            setError(error.localizedDescription)
        }
    }

    private func refreshGitContext(for project: Project) async {
        do {
            async let commitsTask = gitService.fetchCommits(projectPath: project.path, limit: 300)
            async let branchTask = gitService.fetchCurrentBranch(projectPath: project.path)
            let commits = try await commitsTask
            let branch = try? await branchTask

            guard selectedProject?.id == project.id else { return }
            recentGitCommits = commits
            currentGitBranch = branch?.isEmpty == true ? nil : branch
            beadGitSummaries = buildBeadGitSummaries(
                commits: commits,
                defaultBranch: currentGitBranch
            )
            rebuildHistoryEvents()
        } catch {
            guard selectedProject?.id == project.id else { return }
            recentGitCommits = []
            currentGitBranch = nil
            beadGitSummaries = [:]
            rebuildHistoryEvents()
        }
    }

    private func buildBeadGitSummaries(
        commits: [GitCommitRecord],
        defaultBranch: String?
    ) -> [String: BeadGitSummary] {
        var grouped: [String: (latest: GitCommitRecord, count: Int)] = [:]

        for commit in commits where !commit.beadIDs.isEmpty {
            for beadID in commit.beadIDs {
                if let existing = grouped[beadID] {
                    let latest = existing.latest.authoredAt >= commit.authoredAt
                        ? existing.latest
                        : commit
                    grouped[beadID] = (latest: latest, count: existing.count + 1)
                } else {
                    grouped[beadID] = (latest: commit, count: 1)
                }
            }
        }

        return grouped.reduce(into: [String: BeadGitSummary]()) { partialResult, element in
            let beadID = element.key
            var latest = element.value.latest
            if latest.branch == nil, let defaultBranch {
                latest = GitCommitRecord(
                    sha: latest.sha,
                    shortSHA: latest.shortSHA,
                    authoredAt: latest.authoredAt,
                    subject: latest.subject,
                    refs: latest.refs,
                    branch: defaultBranch,
                    beadIDs: latest.beadIDs
                )
            }
            partialResult[beadID] = BeadGitSummary(
                beadID: beadID,
                latestCommit: latest,
                commitCount: element.value.count
            )
        }
    }

    private func rebuildHistoryEvents() {
        let projectName = selectedProject?.name
        var events: [HistoryEvent] = []

        for bead in beads {
            events.append(
                HistoryEvent(
                    occurredAt: bead.createdAt,
                    type: .beadCreated,
                    title: "\(bead.id) created",
                    details: bead.title,
                    projectName: projectName,
                    beadID: bead.id
                )
            )

            events.append(
                HistoryEvent(
                    occurredAt: bead.updatedAt,
                    type: .beadStatus,
                    title: "\(bead.id) status: \(bead.status.rawValue)",
                    details: bead.title,
                    projectName: projectName,
                    beadID: bead.id
                )
            )
        }

        for session in sessions {
            events.append(
                HistoryEvent(
                    occurredAt: session.startedAt,
                    type: .sessionStarted,
                    title: "Session started: \(session.name)",
                    details: session.agentType.rawValue,
                    projectName: session.projectPath?.lastPathComponent,
                    beadID: session.beadId
                )
            )

            if session.status == .stopped || session.status == .error {
                events.append(
                    HistoryEvent(
                        occurredAt: session.startedAt.addingTimeInterval(max(session.elapsed, 0)),
                        type: .sessionCompleted,
                        title: "Session \(session.status.rawValue): \(session.name)",
                        details: session.model,
                        projectName: session.projectPath?.lastPathComponent,
                        beadID: session.beadId
                    )
                )
            }
        }

        for commit in recentGitCommits {
            events.append(
                HistoryEvent(
                    occurredAt: commit.authoredAt,
                    type: .commit,
                    title: "\(commit.shortSHA) \(commit.subject)",
                    details: commit.branch,
                    projectName: projectName,
                    beadID: commit.beadIDs.first,
                    commitSHA: commit.sha
                )
            )
        }

        historyEvents = events.sorted { lhs, rhs in lhs.occurredAt > rhs.occurredAt }
    }

    private func runBD(arguments: [String], in project: Project) async throws -> ShellCommandResult {
        try await ShellCommand.runAsync(arguments: arguments, workingDirectory: project.path)
    }

    private func parseCanvasDirective(from content: String) -> (CanvasContent, String)? {
        let pattern = #"<!--\s*canvas:([a-zA-Z]+)\s*-->([\s\S]*?)<!--\s*/canvas\s*-->"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: nsRange),
              let typeRange = Range(match.range(at: 1), in: content),
              let bodyRange = Range(match.range(at: 2), in: content) else {
            return nil
        }

        let type = content[typeRange].lowercased()
        let body = String(content[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }

        let cleanedMessage: String
        if let fullRange = Range(match.range(at: 0), in: content) {
            cleanedMessage = content.replacingCharacters(in: fullRange, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanedMessage = content
        }

        let canvasContent: CanvasContent
        switch type {
        case "markdown":
            canvasContent = .markdown(id: UUID(), title: "Canvas Markdown", content: body)

        case "html":
            canvasContent = .html(id: UUID(), title: "Canvas HTML", content: body)

        case "mermaid", "diagram":
            canvasContent = .diagram(id: UUID(), title: "Canvas Diagram", mermaid: body)

        case "image":
            if let url = URL(string: body), url.scheme != nil {
                canvasContent = .image(id: UUID(), title: "Canvas Image", url: url)
            } else {
                canvasContent = .markdown(id: UUID(), title: "Canvas Markdown", content: body)
            }

        case "diff":
            canvasContent = parseDiffCanvasContent(from: body)

        default:
            canvasContent = .markdown(id: UUID(), title: "Canvas Markdown", content: body)
        }

        return (canvasContent, cleanedMessage)
    }

    private func parseDiffCanvasContent(from body: String) -> CanvasContent {
        var lines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        var filename = "Changes.diff"
        if let firstLine = lines.first, firstLine.lowercased().hasPrefix("file:") {
            filename = firstLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            lines.removeFirst()
        }

        let normalizedBody = lines.joined(separator: "\n")
        let divider = "\n---\n"
        let before: String
        let after: String
        if let dividerRange = normalizedBody.range(of: divider) {
            before = String(normalizedBody[..<dividerRange.lowerBound])
            after = String(normalizedBody[dividerRange.upperBound...])
        } else {
            before = ""
            after = normalizedBody
        }

        return .diff(
            id: UUID(),
            title: "Canvas Diff",
            before: before,
            after: after,
            filename: filename
        )
    }

    private func makeCanvasContent(from fileURL: URL) throws -> CanvasContent {
        let filename = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()

        if ["png", "jpg", "jpeg", "gif", "heic", "webp", "bmp", "tiff", "svg"].contains(ext) {
            return .image(id: UUID(), title: filename, url: fileURL)
        }

        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        if ["html", "htm"].contains(ext) {
            return .html(id: UUID(), title: filename, content: fileContents)
        }
        if ["mmd", "mermaid"].contains(ext) {
            return .diagram(id: UUID(), title: filename, mermaid: fileContents)
        }
        if ["diff", "patch"].contains(ext) {
            return .diff(id: UUID(), title: filename, before: "", after: fileContents, filename: filename)
        }
        return .markdown(id: UUID(), title: filename, content: fileContents)
    }

    private func extractFirstCodeBlock(from content: String) -> (language: String, code: String)? {
        guard let fenceStart = content.range(of: "```") else { return nil }
        let afterFence = content[fenceStart.upperBound...]
        guard let fenceEnd = afterFence.range(of: "```") else { return nil }

        let raw = String(afterFence[..<fenceEnd.lowerBound])
        let lines = raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let language = lines.first.map(String.init) ?? ""
        let code = lines.dropFirst().joined(separator: "\n")
        return (language.trimmingCharacters(in: .whitespacesAndNewlines), code)
    }

    private func replaceAssistantMessage(messageID: UUID, content: String, sentToCanvas: Bool = false) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
        let message = chatMessages[index]
        let updated = ChatMessage(
            id: message.id,
            role: message.role,
            content: content,
            timestamp: message.timestamp,
            beadContext: message.beadContext,
            sentToCanvas: sentToCanvas
        )
        chatMessages[index] = updated
    }

    private func parseCreatedIssueID(from result: ShellCommandResult) -> String? {
        let stdoutLines = result.stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let candidate = stdoutLines.last {
            return candidate.split(separator: " ").last.map(String.init)
        }

        return nil
    }

    private func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    /// Detects if content is tool/subagent output that should be suppressed
    private func isToolOutput(_ text: String) -> Bool {
        let toolPatterns = [
            // Agent completion patterns
            "## Task Complete:",
            "## Summary",
            "Stats: runtime",
            "subagent task",
            "A subagent task",
            "There are still",
            "active subagent runs",
            "Files Modified/Created:",
            "### Files Modified",
            "### Files Created",
            "### Changes Made:",
            "Bead Status:",
            "✓ Created issue:",
            "✓ Updated issue:",
            "✓ Closed",
            // Debug/logging patterns - embedded run logs
            "embedded run",
            "\"meta\":",
            "\"runtime\":",
            "\"runtimeVersion\":",
            "\"logLevelId\":",
            "\"logLevelName\":",
            "\"subsystem\":",
            "\"parentNames\":",
            "\"fullFilePath\":",
            "\"fileName\":",
            "\"method\":",
            "\"date\":",
            "os/kern",
            "ViewBridge",
            "NSViewBridgeError",
            "invalid display identifier",
            "CALocalDisplayUpdateBlock"
        ]

        return toolPatterns.contains { pattern in
            text.contains(pattern)
        }
    }
}
