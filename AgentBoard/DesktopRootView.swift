import AgentBoardCore
import SwiftUI

struct DesktopRootView: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var activeTab: DesktopTab? = .work
    @State private var activeSessionTerminal: SessionLauncher.ActiveSession?
    @State private var isTerminalExpanded = false
    @State private var isChatOnlyMode = false
    @State private var savedWindowWidth: CGFloat?
    @State private var isPresentingQuickLaunch = false

    private static let chatOnlyWindowWidth: CGFloat = 380

    private var sidePanelsHidden: Bool {
        isTerminalExpanded || isChatOnlyMode
    }

    var body: some View {
        HStack(spacing: 0) {
            if !sidePanelsHidden {
                DesktopSidebar(
                    activeTab: activeTab,
                    onTabSelect: { tab in
                        activeTab = tab
                        activeSessionTerminal = nil
                        isTerminalExpanded = false
                    },
                    onSessionTap: { session in activeSessionTerminal = session },
                    onQuickLaunch: { isPresentingQuickLaunch = true }
                )
                .frame(width: 230)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if !isChatOnlyMode {
                centerPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NeuPalette.background)
            }

            if !isTerminalExpanded {
                ChatScreen(
                    onToggleChatOnly: { toggleChatOnlyMode() },
                    isChatOnlyMode: isChatOnlyMode
                )
                .frame(maxWidth: isChatOnlyMode ? .infinity : 360)
                .frame(width: isChatOnlyMode ? nil : 360)
                .background(NeuPalette.surface)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(NeuPalette.borderSoft)
                        .frame(width: 1)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isTerminalExpanded)
        .animation(.easeInOut(duration: 0.22), value: isChatOnlyMode)
        .background(NeuBackground())
        .sheet(isPresented: $isPresentingQuickLaunch) {
            QuickLaunchSheet()
                .environment(appModel)
        }
    }

    // MARK: - Chat-only Mode

    private func toggleChatOnlyMode() {
        #if os(macOS)
            if isChatOnlyMode {
                isChatOnlyMode = false
                if let restoreWidth = savedWindowWidth {
                    setWindowWidth(restoreWidth, animate: true)
                }
                savedWindowWidth = nil
            } else {
                if let window = primaryWindow() {
                    savedWindowWidth = window.frame.width
                }
                isChatOnlyMode = true
                setWindowWidth(Self.chatOnlyWindowWidth, animate: true)
            }
        #else
            isChatOnlyMode.toggle()
        #endif
    }

    #if os(macOS)
        private func primaryWindow() -> NSWindow? {
            NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible })
        }

        private func setWindowWidth(_ width: CGFloat, animate: Bool) {
            guard let window = primaryWindow() else { return }
            // Allow the window to shrink below any prior contentMinSize.
            window.contentMinSize = NSSize(width: min(width, window.contentMinSize.width), height: 0)
            var frame = window.frame
            let delta = frame.size.width - width
            frame.size.width = width
            // Keep the right edge of the window pinned so the chat column doesn't shift.
            frame.origin.x += delta
            window.setFrame(frame, display: true, animate: animate)
        }
    #endif

    // MARK: - Center Panel

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
