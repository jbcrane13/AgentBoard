import AgentBoardCore
import SwiftUI

struct ChatHeader: View {
    @Environment(AgentBoardAppModel.self) private var appModel

    let isCompact: Bool
    var onToggleChatOnly: (() -> Void)?
    var isChatOnlyMode: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onToggleChatOnly, !isCompact {
                Button {
                    onToggleChatOnly()
                } label: {
                    Image(systemName: isChatOnlyMode ? "rectangle.split.3x1" : "rectangle.righthalf.inset.filled")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(NeuButtonTarget(isAccent: isChatOnlyMode))
                .accessibilityLabel(isChatOnlyMode
                    ? "Restore the sidebar and board"
                    : "Hide the sidebar and board, shrink the window to chat-only")
                .accessibilityIdentifier("chat_button_toggle_chat_only")
            }

            Spacer()

            HStack(spacing: 8) {
                if isCompact {
                    sessionMenu
                    profileMenu
                } else {
                    desktopSessionMenu
                    desktopProfileMenu
                }

                Circle()
                    .fill(connectionTint)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Connection status")
                    .accessibilityValue(appModel.chatStore.connectionState.title)

                Button {
                    Task {
                        await appModel.chatStore.refreshConnection()
                        await appModel.chatStore.refreshModels()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .accessibilityLabel("Refresh Hermes connection and models")
                .accessibilityHint("Reconnects to Hermes and reloads the available models.")
                .buttonStyle(NeuButtonTarget(isAccent: false))
                .accessibilityIdentifier("chat_button_refresh")
            }
        }
    }

    @ViewBuilder
    private var sessionMenuItems: some View {
        ForEach(appModel.chatStore.conversations) { conversation in
            Button {
                appModel.chatStore.selectConversation(conversation.id)
            } label: {
                Label(
                    conversation.title,
                    systemImage: conversation.id == appModel.chatStore.selectedConversationID
                        ? "checkmark.circle.fill" : "bubble.left"
                )
            }
            .accessibilityIdentifier("chat_menuitem_session_\(conversation.id.uuidString)")
        }
        if !appModel.chatStore.conversations.isEmpty {
            Divider()
        }
        Button {
            appModel.chatStore.startNewConversation()
        } label: {
            Label("New Session", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("chat_menuitem_session_new")
    }

    @ViewBuilder
    private var profileMenuItems: some View {
        ForEach(appModel.settingsStore.availableHermesProfiles) { profile in
            Button {
                Task {
                    if profile.id != "current" {
                        appModel.settingsStore.selectHermesProfile(id: profile.id)
                    }
                    await appModel.chatStore.refreshConnection()
                    await appModel.chatStore.refreshModels()
                }
            } label: {
                Label(
                    profile.name,
                    systemImage: appModel.settingsStore.selectedHermesProfileID == profile.id
                        ? "checkmark.circle.fill" : "network"
                )
            }
            .accessibilityIdentifier("chat_menuitem_profile_\(profile.id)")
        }
    }

    private var sessionMenu: some View {
        Menu {
            sessionMenuItems
        } label: {
            compactMenuButton(
                icon: "bubble.left.and.bubble.right.fill",
                text: appModel.chatStore.selectedConversation?.title ?? "Session"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_menu_session")
    }

    private var profileMenu: some View {
        Menu {
            profileMenuItems
        } label: {
            compactMenuButton(
                icon: "server.rack",
                text: appModel.settingsStore.activeHermesProfile?.name ?? portLabel
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_menu_profile")
    }

    private var desktopSessionMenu: some View {
        Menu {
            sessionMenuItems
        } label: {
            Text(appModel.chatStore.selectedConversation?.title.prefix(10) ?? "session")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NeuPalette.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(NeuPalette.inset)
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Switch session")
        .accessibilityIdentifier("chat_menu_session_desktop")
    }

    private var desktopProfileMenu: some View {
        Menu {
            profileMenuItems
        } label: {
            Text(appModel.settingsStore.activeHermesProfile?.name ?? portLabel)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NeuPalette.accentCyanBright)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(NeuPalette.accentCyan.opacity(0.08))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Switch Hermes profile")
        .accessibilityIdentifier("chat_menu_profile_desktop")
    }

    private func compactMenuButton(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(NeuPalette.accentCyan)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(NeuPalette.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(NeuPalette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuExtruded(cornerRadius: 12, elevation: 2)
    }

    private var connectionTint: Color {
        switch appModel.chatStore.connectionState {
        case .connected: NeuPalette.accentCyan
        case .connecting, .reconnecting: NeuPalette.accentOrange
        case .failed: .red
        case .disconnected: NeuPalette.textSecondary
        }
    }

    private var portLabel: String {
        if let url = URL(string: appModel.settingsStore.hermesGatewayURL),
           let port = url.port {
            return "Port \(port)"
        }
        return "Current"
    }
}
