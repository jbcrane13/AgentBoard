import AgentBoardCore
import SwiftUI

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var activeSessionTerminal: SessionLauncher.ActiveSession?
    @State private var isTerminalExpanded = false
    @State private var isChatInspectorPresented = true
    @State private var isPresentingQuickLaunch = false
    @State private var observedSessionIDs: Set<String> = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DesktopSidebar(
                selection: tabSelection,
                onSessionTap: { session in
                    activeSessionTerminal = session
                    isTerminalExpanded = false
                },
                onQuickLaunch: { isPresentingQuickLaunch = true }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            centerPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            isPresentingQuickLaunch = true
                        } label: {
                            Label("Quick Launch", systemImage: "plus")
                        }
                        .help("Launch a new agent session")
                        .accessibilityIdentifier("toolbar_button_quick_launch")

                        Button {
                            isChatInspectorPresented.toggle()
                        } label: {
                            Label(
                                isChatInspectorPresented ? "Hide Chat" : "Show Chat",
                                systemImage: "sidebar.trailing"
                            )
                        }
                        .disabled(isTerminalExpanded)
                        .help(isChatInspectorPresented ? "Hide chat inspector" : "Show chat inspector")
                        .accessibilityIdentifier("toolbar_button_toggle_chat_inspector")
                    }
                }
        }
        .inspector(isPresented: chatInspectorVisibility) {
            ChatScreen()
                .inspectorColumnWidth(min: 320, ideal: 360, max: 460)
        }
        .sheet(isPresented: $isPresentingQuickLaunch) {
            QuickLaunchSheet()
                .environment(appModel)
        }
        .onAppear {
            observedSessionIDs = Set(appModel.sessionLauncher.activeSessions.map(\.id))
        }
        .onChange(of: appModel.sessionLauncher.activeSessions.map(\.id)) { _, sessionIDs in
            presentNewestSessionTerminal(from: sessionIDs)
        }
    }

    private var tabSelection: Binding<AppDestination?> {
        Binding {
            appModel.selectedDestination
        } set: { newValue in
            appModel.selectedDestination = desktopDestination(for: newValue)
            activeSessionTerminal = nil
            isTerminalExpanded = false
        }
    }

    private var chatInspectorVisibility: Binding<Bool> {
        Binding {
            isChatInspectorPresented && !isTerminalExpanded
        } set: { newValue in
            isChatInspectorPresented = newValue
        }
    }

    private var navigationTitle: String {
        if activeSessionTerminal != nil {
            return "Session Terminal"
        }
        return desktopDestination(for: appModel.selectedDestination).title
    }

    @ViewBuilder
    private var centerPanel: some View {
        if let session = activeSessionTerminal {
            SessionTerminalView(
                session: session,
                isExpanded: $isTerminalExpanded
            ) {
                activeSessionTerminal = nil
                isTerminalExpanded = false
            }
        } else {
            switch desktopDestination(for: appModel.selectedDestination) {
            case .work:
                WorkScreen()
            case .agents:
                AgentsScreen()
            case .sessions:
                SessionsScreen()
            case .settings:
                SettingsScreen()
            case .chat:
                WorkScreen()
            }
        }
    }

    private func desktopDestination(for destination: AppDestination?) -> AppDestination {
        guard let destination, AppDestination.desktopTabs.contains(destination) else {
            return .work
        }
        return destination
    }

    private func presentNewestSessionTerminal(from sessionIDs: [String]) {
        let latestIDs = Set(sessionIDs)
        defer { observedSessionIDs = latestIDs }

        guard let newID = sessionIDs.last(where: { !observedSessionIDs.contains($0) }),
              let session = appModel.sessionLauncher.activeSessions.first(where: { $0.id == newID }) else {
            return
        }

        activeSessionTerminal = session
        isTerminalExpanded = false
    }
}
