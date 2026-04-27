import AgentBoardCore
import SwiftUI

enum DesktopTab: String, CaseIterable, Identifiable {
    case work
    case agents
    case sessions
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .work: "Work"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .work: "square.grid.3x3"
        case .agents: "person.3.sequence.fill"
        case .sessions: "bolt.horizontal.circle.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var activeTab: DesktopTab? = .work
    @State private var activeSessionTerminal: SessionLauncher.ActiveSession?
    @State private var isPresentingQuickLaunch = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
                .frame(height: 40)

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
        }
        .background(NeuBackground())
        .sheet(isPresented: $isPresentingQuickLaunch) {
            QuickLaunchSheet()
                .environment(appModel)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                #if os(macOS)
                    HStack(spacing: 6) {
                        Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.35))
                        Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                        Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                    }
                    .frame(width: 48)
                #endif

                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 11, weight: .bold))
                    Text("AB")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(NeuPalette.background)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [NeuPalette.accentCyanBright, NeuPalette.accentCyan.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            .frame(width: 230, alignment: .leading)
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                Text("AgentBoard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeuPalette.textSecondary)
                Text("-")
                    .font(.caption.monospaced())
                    .foregroundStyle(NeuPalette.textDisabled)
                Text(activeRepositoryTitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(NeuPalette.textTertiary)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                connectionStatusChip
                Button {
                    Task<Void, Never> { await appModel.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(NeuPalette.textTertiary)
                .accessibilityIdentifier("desktop_button_refresh")
            }
            .frame(width: 360, alignment: .trailing)
            .padding(.horizontal, 14)
        }
        .background(
            LinearGradient(
                colors: [NeuPalette.surface, NeuPalette.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeuPalette.borderSoft)
                .frame(height: 1)
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
