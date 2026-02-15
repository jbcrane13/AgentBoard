import Foundation
import SwiftUI

enum CenterTab: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
    case agents = "Agents"
    case history = "History"
}

enum SidebarNavItem: String, CaseIterable, Sendable {
    case board = "Board"
    case epics = "Epics"
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
    var selectedBeadID: String?
    var chatConnectionState: OpenClawConnectionState = .disconnected
    var isChatStreaming = false
    var remoteChatSessions: [OpenClawRemoteSession] = []

    private let configStore = AppConfigStore()
    private let parser = JSONLParser()
    private let watcher = BeadsWatcher()
    private let openClawService = OpenClawService()
    private let sessionMonitor = SessionMonitor()
    private var watchedFilePath: String?
    private var chatReconnectTask: Task<Void, Never>?
    private var sessionMonitorTask: Task<Void, Never>?

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

    var selectedBeadContextID: String? {
        selectedBeadID ?? selectedBead?.id
    }

    var activeSession: CodingSession? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    init() {
        bootstrap()
        startChatConnectionLoop()
        startSessionMonitorLoop()
    }

    func selectProject(_ project: Project) {
        selectedProjectID = project.id
        sidebarNavSelection = .board
        selectedTab = .board
        activeSessionID = nil
        persistSelectedProject()
        updateActiveProjectFlags()
        reloadSelectedProjectAndWatch()
    }

    func navigate(to item: SidebarNavItem) {
        sidebarNavSelection = item
        activeSessionID = nil
        switch item {
        case .board:
            selectedTab = .board
        case .epics:
            selectedTab = .epics
        case .history:
            selectedTab = .history
        case .settings:
            break
        }
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

    func updateOpenClaw(gatewayURL: String, token: String) {
        appConfig.openClawGatewayURL = gatewayURL.isEmpty ? nil : gatewayURL
        appConfig.openClawToken = token.isEmpty ? nil : token
        persistConfig()
        statusMessage = "Saved OpenClaw settings."
        startChatConnectionLoop()
    }

    func sendChatMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let contextID = selectedBeadContextID
        let userMessage = ChatMessage(role: .user, content: trimmed, beadContext: contextID)
        chatMessages.append(userMessage)

        let assistantID = UUID()
        chatMessages.append(
            ChatMessage(id: assistantID, role: .assistant, content: "", beadContext: contextID)
        )

        isChatStreaming = true
        errorMessage = nil

        let snapshot = chatMessages
        do {
            let streamedText = try await openClawService.streamChat(
                messages: snapshot,
                beadContext: contextID
            ) { [weak self] chunk in
                Task { @MainActor in
                    self?.appendAssistantChunk(chunk, messageID: assistantID)
                }
            }

            if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replaceAssistantMessage(
                    messageID: assistantID,
                    content: "No response content received from OpenClaw."
                )
            } else {
                replaceAssistantMessage(messageID: assistantID, content: streamedText)
            }
        } catch {
            replaceAssistantMessage(
                messageID: assistantID,
                content: "Failed to send message: \(error.localizedDescription)"
            )
            errorMessage = error.localizedDescription
            startChatConnectionLoop()
        }

        isChatStreaming = false
        await refreshRemoteSessions()
    }

    func openIssueFromChat(issueID: String) {
        selectedBeadID = issueID
        selectedTab = .board
        sidebarNavSelection = .board
    }

    func openSessionInTerminal(_ session: CodingSession) {
        activeSessionID = session.id
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
            errorMessage = error.localizedDescription
        }
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
            return true
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func createBead(from draft: BeadDraft) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            var arguments = [
                "bd", "create",
                "--title", draft.title,
                "--type", draft.kind.beadsValue,
                "--priority", "2",
                "--silent",
            ]

            if !draft.description.isEmpty {
                arguments.append(contentsOf: ["--description", draft.description])
            }

            if !draft.labels.isEmpty {
                arguments.append(contentsOf: ["--labels", draft.labels.joined(separator: ",")])
            }

            if !draft.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--assignee", draft.assignee])
            }

            if let epicId = draft.epicId,
               !epicId.isEmpty,
               draft.kind != .epic {
                arguments.append(contentsOf: ["--parent", epicId])
            }

            let result = try await runBD(arguments: arguments, in: project)
            let createdID = parseCreatedIssueID(from: result)

            if draft.status != .open, let createdID {
                _ = try await runBD(
                    arguments: ["bd", "update", createdID, "--status", draft.status.beadsValue],
                    in: project
                )
            }

            statusMessage = "Created issue\(createdID.map { " \($0)" } ?? "")."
            reloadSelectedProjectAndWatch()
        } catch {
            errorMessage = error.localizedDescription
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
                "--description", draft.description,
            ]

            if !draft.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--assignee", draft.assignee])
            }

            if !draft.labels.isEmpty {
                for label in draft.labels {
                    arguments.append(contentsOf: ["--set-labels", label])
                }
            }

            if draft.kind == .epic {
                arguments.append(contentsOf: ["--parent", ""])
            } else if let epicId = draft.epicId, !epicId.isEmpty {
                arguments.append(contentsOf: ["--parent", epicId])
            } else {
                arguments.append(contentsOf: ["--parent", ""])
            }

            _ = try await runBD(arguments: arguments, in: project)
            statusMessage = "Updated \(bead.id)."
            reloadSelectedProjectAndWatch()
        } catch {
            errorMessage = error.localizedDescription
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
            reloadSelectedProjectAndWatch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeBead(_ bead: Bead) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            _ = try await runBD(
                arguments: ["bd", "close", bead.id, "--reason", "Closed from AgentBoard board action"],
                in: project
            )
            statusMessage = "Closed \(bead.id)."
            reloadSelectedProjectAndWatch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignBeadToAgent(_ bead: Bead, assignee: String = "agent") async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        do {
            _ = try await runBD(
                arguments: ["bd", "update", bead.id, "--assignee", assignee],
                in: project
            )
            statusMessage = "Assigned \(bead.id) to \(assignee)."
            reloadSelectedProjectAndWatch()
        } catch {
            errorMessage = error.localizedDescription
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
                "--silent",
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
            errorMessage = error.localizedDescription
        }
    }

    func openBeadInTerminal(_ bead: Bead) async {
        guard let project = selectedProject else { return }
        errorMessage = nil

        let escapedPath = shellSingleQuoted(project.path.path)
        let command = "cd \(escapedPath); bd show \(bead.id)"
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        do {
            _ = try await ShellCommand.runAsync(arguments: ["osascript", "-e", script])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bootstrap() {
        do {
            appConfig = try configStore.loadOrCreate()
        } catch {
            appConfig = .empty
            errorMessage = error.localizedDescription
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
            sessions = try await sessionMonitor.listSessions()
            if let activeSessionID,
               !sessions.contains(where: { $0.id == activeSessionID }) {
                self.activeSessionID = nil
            }
        } catch {
            sessions = []
            if !SessionMonitor.isMissingTmuxServer(error: error) {
                errorMessage = error.localizedDescription
            }
            activeSessionID = nil
        }
    }

    private func startChatConnectionLoop() {
        chatReconnectTask?.cancel()
        chatReconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var attempt = 0
            while !Task.isCancelled {
                do {
                    try await self.openClawService.configure(
                        gatewayURLString: self.appConfig.openClawGatewayURL,
                        token: self.appConfig.openClawToken
                    )

                    self.chatConnectionState = attempt == 0 ? .connecting : .reconnecting

                    try await self.openClawService.connectWebSocket()
                    self.chatConnectionState = .connected
                    await self.refreshRemoteSessions()

                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                        try await self.openClawService.pingWebSocket()
                    }
                    return
                } catch {
                    attempt += 1
                    self.chatConnectionState = .reconnecting

                    let backoffSeconds = min(pow(2.0, Double(max(attempt - 1, 0))), 30)
                    try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                }
            }

            self.chatConnectionState = .disconnected
        }
    }

    private func refreshRemoteSessions() async {
        do {
            remoteChatSessions = try await openClawService.fetchSessions()
        } catch {
            remoteChatSessions = []
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
            watcher.stop()
            watchedFilePath = nil
            return
        }

        loadBeads(for: selectedProject)
        watch(project: selectedProject)
    }

    private func loadBeads(for project: Project) {
        isLoadingBeads = true
        defer { isLoadingBeads = false }

        let issuesURL = project.issuesFileURL
        guard FileManager.default.fileExists(atPath: issuesURL.path) else {
            beads = []
            beadsFileMissing = true
            refreshProjectCounts()
            return
        }

        do {
            beads = try parser.parseBeads(from: issuesURL)
            beadsFileMissing = false
            selectedBeadID = selectedBeadID.flatMap { existingID in
                beads.contains(where: { $0.id == existingID }) ? existingID : nil
            }
            refreshProjectCounts()
        } catch {
            beads = []
            beadsFileMissing = true
            errorMessage = error.localizedDescription
        }
    }

    private func watch(project: Project) {
        let issuesURL = project.issuesFileURL
        guard FileManager.default.fileExists(atPath: issuesURL.path) else {
            watcher.stop()
            watchedFilePath = nil
            return
        }

        guard watchedFilePath != issuesURL.path else { return }
        watchedFilePath = issuesURL.path
        watcher.watch(fileURL: issuesURL) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard let current = self.selectedProject, current.issuesFileURL.path == issuesURL.path else {
                    return
                }
                self.loadBeads(for: current)
            }
        }
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
            errorMessage = error.localizedDescription
        }
    }

    private func runBD(arguments: [String], in project: Project) async throws -> ShellCommandResult {
        try await ShellCommand.runAsync(arguments: arguments, workingDirectory: project.path)
    }

    private func appendAssistantChunk(_ chunk: String, messageID: UUID) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
        let message = chatMessages[index]
        let updated = ChatMessage(
            id: message.id,
            role: message.role,
            content: message.content + chunk,
            timestamp: message.timestamp,
            beadContext: message.beadContext
        )
        chatMessages[index] = updated
    }

    private func replaceAssistantMessage(messageID: UUID, content: String) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
        let message = chatMessages[index]
        let updated = ChatMessage(
            id: message.id,
            role: message.role,
            content: content,
            timestamp: message.timestamp,
            beadContext: message.beadContext
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
}
