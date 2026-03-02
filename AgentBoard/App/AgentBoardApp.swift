import SwiftUI

@main
struct AgentBoardApp: App {
    @State private var appState = AgentBoardApp.makeInitialState()

    private static func makeInitialState() -> AppState {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting-dashboard-fixtures") {
            let state = AppState(bootstrapOnInit: false, startBackgroundLoops: false)
            state.applyDashboardUITestFixtures(empty: arguments.contains("--uitesting-dashboard-empty"))
            return state
        }
        return AppState()
    }

    var body: some Scene {
        WindowGroup("AgentBoard", content: {
            ContentView()
                .environment(appState)
                .preferredColorScheme(nil)
        })
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Bead") {
                    appState.requestCreateBeadSheet()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Coding Session") {
                    appState.requestNewSessionSheet()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .sidebar) {
                Button(appState.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    appState.toggleSidebar()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }

            CommandGroup(after: .sidebar) {
                Button(appState.boardVisible ? "Hide Board" : "Show Board") {
                    appState.toggleBoard()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button(appState.isFocusMode ? "Exit Focus Mode" : "Focus Mode") {
                    appState.toggleFocusMode()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh Beads") {
                    Task { await appState.refreshBeads() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Navigate") {
                Button("Board") {
                    appState.switchToTab(.board)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Epics") {
                    appState.switchToTab(.epics)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Agents") {
                    appState.switchToTab(.agents)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("History") {
                    appState.switchToTab(.history)
                }
                .keyboardShortcut("4", modifiers: [.command])
            }

            CommandMenu("Canvas") {
                Button("Canvas Back") {
                    appState.goCanvasBack()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!appState.canGoCanvasBack)

                Button("Canvas Forward") {
                    appState.goCanvasForward()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!appState.canGoCanvasForward)
            }

            CommandMenu("Chat") {
                Button("Focus Chat Input") {
                    appState.requestChatInputFocus()
                }
                .keyboardShortcut("l", modifiers: [.command])
            }
        }
    }
}
