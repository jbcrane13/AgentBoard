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

        Form {
            Section {
                TextField("Gateway URL", text: $settingsStore.hermesGatewayURL)
                    .accessibilityIdentifier("settings_textfield_hermes_gateway_url")
                TextField("Preferred model", text: $settingsStore.hermesModelID)
                    .accessibilityIdentifier("settings_textfield_hermes_model_id")
                SecureField("API key (optional)", text: $settingsStore.hermesAPIKey)
                    .accessibilityIdentifier("settings_securefield_hermes_api_key")
            } header: {
                Text("Hermes Gateway")
            } footer: {
                Text("Chat lives here and nowhere else.")
            }

            Section {
                SecureField("GitHub token", text: $settingsStore.githubToken)

                if !settingsStore.repositories.isEmpty {
                    ForEach(settingsStore.repositories) { repository in
                        HStack {
                            Text(repository.fullName)
                            Spacer()
                            Button(role: .destructive) {
                                settingsStore.removeRepository(repository)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("settings_button_remove_repository_\(repository.id)")
                        }
                    }
                }

                HStack {
                    TextField("Owner", text: $repositoryOwner)
                    Divider()
                    TextField("Repo", text: $repositoryName)
                    Button("Add") {
                        settingsStore.addRepository(owner: repositoryOwner, name: repositoryName)
                        repositoryOwner = ""
                        repositoryName = ""
                    }
                    .disabled(repositoryOwner.isEmpty || repositoryName.isEmpty)
                }
            } header: {
                Text("GitHub Issues")
            } footer: {
                Text("Tickets are the canonical work source.")
            }

            Section {
                TextField("Companion URL", text: $settingsStore.companionURL)
                    .accessibilityIdentifier("settings_textfield_companion_url")
                SecureField("Companion token", text: $settingsStore.companionToken)
                    .accessibilityIdentifier("settings_securefield_companion_token")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Auto refresh")
                        Spacer()
                        Text("\(Int(settingsStore.autoRefreshInterval))s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settingsStore.autoRefreshInterval, in: 15 ... 120, step: 15)
                        .accessibilityIdentifier("settings_slider_auto_refresh_interval")
                }
                .padding(.vertical, 4)
            } header: {
                Text("Companion Service")
            } footer: {
                Text("Tasks, sessions, and live events come from this process.")
            }

            Section {
                Button("Save and Refresh") {
                    Task { await appModel.saveSettingsAndReconnect() }
                }

                Button("Refresh Hermes") {
                    Task {
                        await appModel.chatStore.refreshConnection()
                        await appModel.chatStore.refreshModels()
                    }
                }
                .tint(.secondary)

                if let message = appModel.settingsStore.errorMessage ?? appModel.settingsStore.statusMessage ?? appModel
                    .statusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(appModel.settingsStore.errorMessage == nil ? Color.secondary : Color.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .accessibilityIdentifier("screen_settings")
    }
}
