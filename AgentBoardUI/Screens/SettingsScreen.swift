import AgentBoardCore
import SwiftUI

struct SettingsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var repositoryOwner = ""
    @State private var repositoryName = ""

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        @Bindable var settingsStore = appModel.settingsStore

        ZStack {
            BoardBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !isCompact {
                        BoardHeader(
                            eyebrow: "Settings",
                            title: "Current Apple stack, minimal legacy baggage",
                            subtitle: "Hermes, GitHub, and the companion service are all configured independently so the app stays modular and modern."
                        )
                    }
                    BoardSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            BoardSectionTitle("Hermes Gateway", subtitle: "Chat lives here and nowhere else.")
                            TextField("Gateway URL", text: $settingsStore.hermesGatewayURL)
                                .boardFieldStyle()
                                .accessibilityIdentifier("settings_textfield_hermes_gateway_url")
                            TextField("Preferred model", text: $settingsStore.hermesModelID)
                                .boardFieldStyle()
                                .accessibilityIdentifier("settings_textfield_hermes_model_id")
                            SecureField("API key (optional)", text: $settingsStore.hermesAPIKey)
                                .boardFieldStyle()
                                .accessibilityIdentifier("settings_securefield_hermes_api_key")
                        }
                    }
                    githubSection
                    companionSection
                    statusSection
                }
                .padding(isCompact ? 16 : 24)
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("screen_settings")
    }

    private var githubSection: some View {
        @Bindable var settingsStore = appModel.settingsStore
        return BoardSurface {
            VStack(alignment: .leading, spacing: 14) {
                BoardSectionTitle("GitHub Issues", subtitle: "Tickets are the canonical work source.")
                SecureField("GitHub token", text: $settingsStore.githubToken)
                    .boardFieldStyle()
                    .accessibilityIdentifier("settings_securefield_github_token")
                if isCompact {
                    VStack(spacing: 8) {
                        TextField("Owner", text: $repositoryOwner)
                            .boardFieldStyle()
                            .accessibilityIdentifier("settings_textfield_repo_owner")
                        TextField("Repo", text: $repositoryName)
                            .boardFieldStyle()
                            .accessibilityIdentifier("settings_textfield_repo_name")
                        Button("Add Repository") {
                            settingsStore.addRepository(owner: repositoryOwner, name: repositoryName)
                            repositoryOwner = ""
                            repositoryName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoardPalette.cobalt)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("settings_button_add_repository")
                    }
                } else {
                    HStack(spacing: 10) {
                        TextField("Owner", text: $repositoryOwner)
                            .boardFieldStyle()
                            .accessibilityIdentifier("settings_textfield_repo_owner")
                        TextField("Repo", text: $repositoryName)
                            .boardFieldStyle()
                            .accessibilityIdentifier("settings_textfield_repo_name")
                        Button("Add") {
                            settingsStore.addRepository(owner: repositoryOwner, name: repositoryName)
                            repositoryOwner = ""
                            repositoryName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoardPalette.cobalt)
                        .accessibilityIdentifier("settings_button_add_repository")
                    }
                }
                if settingsStore.repositories.isEmpty {
                    Text("No repositories connected yet.")
                        .font(.subheadline)
                        .foregroundStyle(BoardPalette.paper.opacity(0.72))
                } else {
                    ForEach(settingsStore.repositories) { repository in
                        HStack {
                            Text(repository.fullName).foregroundStyle(.white)
                            Spacer()
                            Button("Remove") { settingsStore.removeRepository(repository) }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("settings_button_remove_repository_\(repository.id)")
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(0.2))
                        )
                    }
                }
            }
        }
    }

    private var companionSection: some View {
        @Bindable var settingsStore = appModel.settingsStore
        return BoardSurface {
            VStack(alignment: .leading, spacing: 14) {
                BoardSectionTitle(
                    "Companion Service",
                    subtitle: "Tasks, sessions, and live events come from this process."
                )
                TextField("Companion URL", text: $settingsStore.companionURL)
                    .boardFieldStyle()
                    .accessibilityIdentifier("settings_textfield_companion_url")
                SecureField("Companion token", text: $settingsStore.companionToken)
                    .boardFieldStyle()
                    .accessibilityIdentifier("settings_securefield_companion_token")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto refresh interval")
                        .font(.headline)
                        .foregroundStyle(.white)
                    HStack {
                        Slider(value: $settingsStore.autoRefreshInterval, in: 15 ... 120, step: 15)
                            .tint(BoardPalette.gold)
                            .accessibilityIdentifier("settings_slider_auto_refresh_interval")
                        Text("\(Int(settingsStore.autoRefreshInterval))s")
                            .foregroundStyle(BoardPalette.paper.opacity(0.78))
                            .frame(width: 52)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        BoardSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    appModel.settingsStore.errorMessage
                        ?? appModel.settingsStore.statusMessage
                        ?? appModel.statusMessage
                        ?? "The new architecture is ready for both platforms."
                )
                .font(.subheadline)
                .foregroundStyle(
                    appModel.settingsStore.errorMessage == nil
                        ? BoardPalette.paper.opacity(0.78) : BoardPalette.coral
                )
                HStack(spacing: 10) {
                    Button("Save and Refresh") {
                        Task { await appModel.saveSettingsAndReconnect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BoardPalette.coral)
                    .accessibilityIdentifier("settings_button_save_and_refresh")
                    Button("Refresh Hermes") {
                        Task {
                            await appModel.chatStore.refreshConnection()
                            await appModel.chatStore.refreshModels()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityIdentifier("settings_button_refresh_hermes")
                }
            }
        }
    }
}

private extension View {
    func boardFieldStyle() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}
