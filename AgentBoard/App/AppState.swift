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
    var sessions: [CodingSession] = CodingSession.samples
    var chatMessages: [ChatMessage] = ChatMessage.samples

    var selectedTab: CenterTab = .board
    var rightPanelMode: RightPanelMode = .split
    var sidebarNavSelection: SidebarNavItem? = .board

    var appConfig: AppConfig = .empty
    var beadsFileMissing = false
    var isLoadingBeads = false
    var statusMessage: String?
    var errorMessage: String?
    var selectedBeadID: String?

    private let configStore = AppConfigStore()
    private let parser = JSONLParser()
    private let watcher = BeadsWatcher()
    private var watchedFilePath: String?

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

    init() {
        bootstrap()
    }

    func selectProject(_ project: Project) {
        selectedProjectID = project.id
        sidebarNavSelection = .board
        selectedTab = .board
        persistSelectedProject()
        updateActiveProjectFlags()
        reloadSelectedProjectAndWatch()
    }

    func navigate(to item: SidebarNavItem) {
        sidebarNavSelection = item
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
