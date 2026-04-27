import AgentBoardCore
import SwiftUI

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var activeTab: DesktopTab? = .work
    @State private var activeSessionTerminal: SessionLauncher.ActiveSession?
    @State private var isPresentingQuickLaunch = false

    var body: some View {
        HStack(spacing: 0) {
            DesktopSidebar(
                activeTab: activeTab,
                onTabSelect: { tab in activeTab = tab },
                onSessionTap: { session in activeSessionTerminal = session },
                onQuickLaunch: { isPresentingQuickLaunch = true }
            )
            .frame(width: 230)

            centerPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NeuPalette.background)

            ChatScreen()
                .frame(width: 360)
                .background(NeuPalette.surface)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(NeuPalette.borderSoft)
                        .frame(width: 1)
                }
        }
        .background(NeuBackground())
        .sheet(isPresented: $isPresentingQuickLaunch) {
            QuickLaunchSheet()
                .environment(appModel)
        }
    }

    // MARK: - Center Panel

    @ViewBuilder
    private var centerPanel: some View {
        if let session = activeSessionTerminal {
            SessionTerminalView(session: session) {
                activeSessionTerminal = nil
            }
        } else {
            switch activeTab ?? .work {
            case .work:
                WorkScreen()
            case .agents:
                AgentsScreen()
            case .sessions:
                SessionsScreen()
            case .settings:
                SettingsScreen()
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionDotColor)
                .frame(width: 7, height: 7)
            Text(connectionStatusText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(connectionDotColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NeuPalette.inset)
        .clipShape(Capsule())
    }

    private var connectionDotColor: Color {
        switch appModel.chatStore.connectionState {
        case .connected: NeuPalette.statusSuccess
        case .connecting, .reconnecting: NeuPalette.accentOrange
        case .failed: .red
        case .disconnected: NeuPalette.textSecondary
        }
    }

    private var activeRepositoryTitle: String {
        appModel.settingsStore.repositories.first?.fullName ?? "no repository"
    }

    private var connectionStatusText: String {
        switch appModel.chatStore.connectionState {
        case .connected: "LIVE"
        case .connecting: "CONNECTING"
        case .reconnecting: "RECONNECTING"
        case .failed: "ERROR"
        case .disconnected: "OFFLINE"
        }
    }
}
