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
                .buttonStyle(AppButtonStyle(isAccent: isChatOnlyMode))
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
                .buttonStyle(AppButtonStyle(isAccent: false))
                .accessibilityIdentifier("chat_button_refresh")
            }
        }
    }

    @ViewBuilder
    private var sessionMenuItems: some View {
        ForEach(visibleConversations) { conversation in
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
        if !visibleConversations.isEmpty {
            Divider()
        }
        if !otherProfileConversations.isEmpty {
            Menu {
                ForEach(groupedOtherConversations) { group in
                    Section(group.name) {
                        ForEach(group.conversations) { conversation in
                            Button {
                                appModel.chatStore.selectConversation(conversation.id)
                            } label: {
                                Label(conversation.title, systemImage: "bubble.left")
                            }
                            .accessibilityIdentifier("chat_menuitem_session_\(conversation.id.uuidString)")
                        }
                    }
                }
            } label: {
                Label("Other Profiles", systemImage: "person.2")
            }
            .accessibilityIdentifier("chat_menu_other_profiles")
            Divider()
        }
        Button {
            appModel.chatStore.startNewConversation()
        } label: {
            Label("New Session", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("chat_menuitem_session_new")
    }

    /// Conversations bound to the active Hermes profile, plus any not yet bound to a profile.
    private var visibleConversations: [ChatConversation] {
        let activeProfileID = appModel.settingsStore.activeHermesProfile?.id
        return appModel.chatStore.conversations.filter { $0.profileID == activeProfileID || $0.profileID == nil }
    }

    /// Conversations bound to a Hermes profile other than the active one.
    private var otherProfileConversations: [ChatConversation] {
        let activeProfileID = appModel.settingsStore.activeHermesProfile?.id
        return appModel.chatStore.conversations.filter { $0.profileID != nil && $0.profileID != activeProfileID }
    }

    /// `otherProfileConversations` grouped by profile name, in first-seen order. Conversations
    /// whose `profileID` names no known profile are grouped under "Unassigned".
    private var groupedOtherConversations: [ProfileConversationGroup] {
        let profiles = appModel.settingsStore.hermesProfiles
        var order: [String] = []
        var byName: [String: [ChatConversation]] = [:]
        for conversation in otherProfileConversations {
            let name = profiles.first { $0.id == conversation.profileID }?.name ?? "Unassigned"
            if byName[name] == nil { order.append(name) }
            byName[name, default: []].append(conversation)
        }
        return order.map { ProfileConversationGroup(name: $0, conversations: byName[$0] ?? []) }
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(profileColor(for: profile))
                        .frame(width: 8, height: 8)
                    Label(
                        profile.name,
                        systemImage: appModel.settingsStore.selectedHermesProfileID == profile.id
                            ? "checkmark.circle.fill" : "network"
                    )
                }
            }
            .accessibilityIdentifier("chat_menuitem_profile_\(profile.id)")
        }
    }

    /// The color dot shown next to a profile; falls back to a neutral tone when the profile has
    /// no `colorHex` set.
    private func profileColor(for profile: HermesProfile) -> Color {
        guard let hex = profile.colorHex, let color = Color(hex: hex) else {
            return AppTheme.textTertiary
        }
        return color
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
            HStack(spacing: 4) {
                if let activeProfile = appModel.settingsStore.activeHermesProfile {
                    Circle()
                        .fill(profileColor(for: activeProfile))
                        .frame(width: 8, height: 8)
                }
                compactMenuButton(
                    icon: "server.rack",
                    text: appModel.settingsStore.activeHermesProfile?.name ?? portLabel
                )
            }
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
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.inset)
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
            HStack(spacing: 4) {
                if let activeProfile = appModel.settingsStore.activeHermesProfile {
                    Circle()
                        .fill(profileColor(for: activeProfile))
                        .frame(width: 8, height: 8)
                }
                Text(appModel.settingsStore.activeHermesProfile?.name ?? portLabel)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.accentCyan)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.accentCyan.opacity(0.08))
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
                .foregroundStyle(AppTheme.accentCyan)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .cardSurface(cornerRadius: 12)
    }

    private var connectionTint: Color {
        switch appModel.chatStore.connectionState {
        case .connected: AppTheme.accentCyan
        case .connecting, .reconnecting: AppTheme.accentOrange
        case .failed: .red
        case .disconnected: AppTheme.textSecondary
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

/// A named group of conversations bound to a single Hermes profile (or "Unassigned"), used by
/// the "Other Profiles" submenu.
private struct ProfileConversationGroup: Identifiable {
    let name: String
    let conversations: [ChatConversation]
    var id: String { name }
}
