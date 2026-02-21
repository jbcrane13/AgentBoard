import Foundation
import Testing
@testable import AgentBoard

@Suite("AppState Project Management")
@MainActor
struct AppStateProjectTests {

    // MARK: - Helpers

    private func makeProject(path: String) -> Project {
        Project(
            id: UUID(),
            name: URL(fileURLWithPath: path).lastPathComponent,
            path: URL(fileURLWithPath: path),
            beadsPath: URL(fileURLWithPath: path + "/.beads"),
            icon: "📁",
            isActive: false,
            openCount: 0,
            inProgressCount: 0,
            totalCount: 0
        )
    }

    // MARK: - addProject

    @Test("addProject with duplicate path sets status message and leaves count unchanged")
    func addProjectDuplicatePathSetsStatusMessage() {
        let state = AppState()
        let path = "/tmp/test-project-duplicate"
        state.appConfig.projects = [ConfiguredProject(path: path, icon: "📁")]
        let countBefore = state.appConfig.projects.count

        state.addProject(at: URL(fileURLWithPath: path))

        #expect(state.statusMessage == "Project already exists.")
        #expect(state.appConfig.projects.count == countBefore)
    }

    @Test("addProject with new path appends an entry to appConfig.projects")
    func addProjectNewPathAppendsToConfig() {
        let state = AppState()
        state.appConfig.projects = []
        let newPath = "/tmp/test-project-new-\(UUID().uuidString)"
        let countBefore = state.appConfig.projects.count

        state.addProject(at: URL(fileURLWithPath: newPath))

        #expect(state.appConfig.projects.count == countBefore + 1)
    }

    // MARK: - removeProject

    @Test("removeProject removes the matching path from appConfig.projects")
    func removeProjectRemovesFromConfig() {
        let state = AppState()
        let pathA = "/tmp/test-project-a"
        let pathB = "/tmp/test-project-b"
        state.appConfig.projects = [
            ConfiguredProject(path: pathA, icon: "📁"),
            ConfiguredProject(path: pathB, icon: "📁"),
        ]

        let projectA = makeProject(path: pathA)
        state.removeProject(projectA)

        #expect(!state.appConfig.projects.contains(where: { $0.path == pathA }))
        #expect(state.appConfig.projects.contains(where: { $0.path == pathB }))
    }

    @Test("removeProject when project is selected falls back to the next project's path")
    func removeProjectWhenSelectedFallsBackToNext() {
        let state = AppState()
        let pathA = "/tmp/test-project-fallback-a"
        let pathB = "/tmp/test-project-fallback-b"
        state.appConfig.projects = [
            ConfiguredProject(path: pathA, icon: "📁"),
            ConfiguredProject(path: pathB, icon: "📁"),
        ]
        state.appConfig.selectedProjectPath = pathA

        let projectA = makeProject(path: pathA)
        state.removeProject(projectA)

        // After removing A, selected path must not still point to A.
        #expect(state.appConfig.selectedProjectPath != pathA)
    }

    // MARK: - selectProject

    @Test("selectProject sets selectedProjectID, clears activeSessionID, and navigates to board")
    func selectProjectSetsState() {
        let state = AppState()
        let pathA = "/tmp/test-select-a"
        let pathB = "/tmp/test-select-b"
        state.appConfig.projects = [
            ConfiguredProject(path: pathA, icon: "📁"),
            ConfiguredProject(path: pathB, icon: "📁"),
        ]

        let projectA = makeProject(path: pathA)
        let projectB = makeProject(path: pathB)
        state.projects = [projectA, projectB]

        state.activeSessionID = "ses-pre-existing"
        state.selectedTab = .history
        state.sidebarNavSelection = .history

        state.selectProject(projectB)

        #expect(state.selectedProjectID == projectB.id)
        #expect(state.activeSessionID == nil)
        #expect(state.sidebarNavSelection == .board)
        #expect(state.selectedTab == .board)
    }

    @Test("selectProject clears activeSessionID regardless of previous value")
    func selectProjectClearsActiveSession() {
        let state = AppState()
        let path = "/tmp/test-select-clear-session"
        state.appConfig.projects = [ConfiguredProject(path: path, icon: "📁")]

        let project = makeProject(path: path)
        state.projects = [project]
        state.activeSessionID = "ses-abc"

        state.selectProject(project)

        #expect(state.activeSessionID == nil)
    }

    // MARK: - rescanProjectsDirectory

    @Test("rescanProjectsDirectory with no new projects sets status message")
    func rescanProjectsDirectoryNoNewProjects() {
        let state = AppState()
        // Pre-populate with some projects to ensure no new ones are discovered
        state.appConfig.projects = [
            ConfiguredProject(path: "/tmp/existing-1", icon: "📁"),
            ConfiguredProject(path: "/tmp/existing-2", icon: "📁"),
        ]
        // Set projectsDirectory to a path that won't discover new projects
        state.appConfig.projectsDirectory = "/tmp/nonexistent-\(UUID().uuidString)"

        state.rescanProjectsDirectory()

        #expect(state.statusMessage == "No new projects found.")
    }
}
