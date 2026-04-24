import AgentBoardCore
import SwiftUI

struct SettingsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var repositoryOwner = ""
    @State private var repositoryName = ""

    var body: some View {
        @Bindable var settingsStore = appModel.settingsStore

        ZStack {
            BoardBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BoardHeader(
                        eyebrow: "Settings",
                        title: "Current Apple stack, minimal legacy baggage",
                        subtitle: "Hermes, GitHub, and the companion service are all configured independently so the app stays modular and modern."
                    )

                    BoardSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            BoardSectionTitle("Hermes Gateway", subtitle: "Chat lives here and nowhere else.")

                            TextField("Gateway URL", text: $settingsStore.hermesGatewayURL)
                                .boardFieldStyle()

                            TextField("Preferred model", text: $settingsStore.hermesModelID)
                                .boardFieldStyle()

                            SecureField("API key (optional)", text: $settingsStore.hermesAPIKey)
                                .boardFieldStyle()
                        }
                    }

                    BoardSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            BoardSectionTitle("GitHub Issues", subtitle: "Tickets are the canonical work source.")

                            SecureField("GitHub token", text: $settingsStore.githubToken)
                                .boardFieldStyle()

                            HStack(spacing: 10) {
                                TextField("Owner", text: $repositoryOwner)
                                    .boardFieldStyle()

                                TextField("Repo", text: $repositoryName)
                                    .boardFieldStyle()

                                Button("Add") {
                                    settingsStore.addRepository(owner: repositoryOwner, name: repositoryName)
                                    repositoryOwner = ""
                                    repositoryName = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BoardPalette.cobalt)
                            }

                            if settingsStore.repositories.isEmpty {
                                Text("No repositories connected yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(BoardPalette.paper.opacity(0.72))
                            } else {
                                ForEach(settingsStore.repositories) { repository in
                                    HStack {
                                        Text(repository.fullName)
                                            .foregroundStyle(.white)

                                        Spacer()

                                        Button("Remove") {
                                            settingsStore.removeRepository(repository)
                                        }
                                        .buttonStyle(.bordered)
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

                    BoardSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            BoardSectionTitle(
                                "Companion Service",
                                subtitle: "Tasks, sessions, and live events come from this process."
                            )

                            TextField("Companion URL", text: $settingsStore.companionURL)
                                .boardFieldStyle()

                            SecureField("Companion token", text: $settingsStore.companionToken)
                                .boardFieldStyle()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Auto refresh interval")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                HStack {
                                    Slider(value: $settingsStore.autoRefreshInterval, in: 15 ... 120, step: 15)
                                        .tint(BoardPalette.gold)
                                    Text("\(Int(settingsStore.autoRefreshInterval))s")
                                        .foregroundStyle(BoardPalette.paper.opacity(0.78))
                                        .frame(width: 52)
                                }
                            }
                        }
                    }

                    BoardSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(
                                appModel.settingsStore.errorMessage
                                    ?? appModel.settingsStore.statusMessage
                                    ?? appModel.statusMessage
                                    ?? "The new architecture is ready for both platforms."
                            )
                            .font(.subheadline)
                            .foregroundStyle(appModel.settingsStore.errorMessage == nil ? BoardPalette.paper
                                .opacity(0.78) : BoardPalette.coral)

                            HStack(spacing: 10) {
                                Button("Save and Refresh") {
                                    Task {
                                        await appModel.saveSettingsAndReconnect()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BoardPalette.coral)

                                Button("Refresh Hermes") {
                                    Task {
                                        await appModel.chatStore.refreshConnection()
                                        await appModel.chatStore.refreshModels()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)
                            }
                        }
                    }
                }
                .padding(24)
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
