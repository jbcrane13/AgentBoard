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
            NeuBackground()

            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("HERMES GATEWAY".uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)

                            VStack(spacing: 20) {
                                NeuTextField(placeholder: "Gateway URL", text: $settingsStore.hermesGatewayURL)
                                NeuTextField(placeholder: "Preferred model", text: $settingsStore.hermesModelID)
                                NeuSecureField(placeholder: "API key (optional)", text: $settingsStore.hermesAPIKey)
                            }
                            .padding(24)
                            .neuExtruded(cornerRadius: 24, elevation: 8)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("GITHUB ISSUES".uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)

                            VStack(alignment: .leading, spacing: 20) {
                                NeuSecureField(placeholder: "GitHub token", text: $settingsStore.githubToken)

                                if !settingsStore.repositories.isEmpty {
                                    VStack(spacing: 12) {
                                        ForEach(settingsStore.repositories) { repository in
                                            HStack {
                                                Text(repository.fullName)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(NeuPalette.textPrimary)
                                                Spacer()
                                                Button(role: .destructive) {
                                                    settingsStore.removeRepository(repository)
                                                } label: {
                                                    Image(systemName: "trash.fill")
                                                        .foregroundStyle(.red)
                                                        .padding(10)
                                                }
                                                .background(Circle().fill(NeuPalette.background))
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .neuRecessed(cornerRadius: 16, depth: 4)
                                        }
                                    }
                                }

                                HStack(spacing: 12) {
                                    NeuTextField(placeholder: "Owner", text: $repositoryOwner)
                                    NeuTextField(placeholder: "Repo", text: $repositoryName)
                                    Button {
                                        settingsStore.addRepository(owner: repositoryOwner, name: repositoryName)
                                        repositoryOwner = ""
                                        repositoryName = ""
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(NeuButtonTarget(isAccent: !(repositoryOwner.isEmpty || repositoryName
                                            .isEmpty)))
                                    .disabled(repositoryOwner.isEmpty || repositoryName.isEmpty)
                                }
                            }
                            .padding(24)
                            .neuExtruded(cornerRadius: 24, elevation: 8)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("COMPANION SERVICE".uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)
                                .padding(.horizontal, 8)

                            VStack(spacing: 20) {
                                NeuTextField(placeholder: "Companion URL", text: $settingsStore.companionURL)
                                NeuSecureField(placeholder: "Companion token", text: $settingsStore.companionToken)

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Auto refresh")
                                            .font(.subheadline)
                                            .foregroundStyle(NeuPalette.textPrimary)
                                        Spacer()
                                        Text("\(Int(settingsStore.autoRefreshInterval))s")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(NeuPalette.accentCyan)
                                    }
                                    Slider(value: $settingsStore.autoRefreshInterval, in: 15 ... 120, step: 15)
                                        .tint(NeuPalette.accentCyan)
                                }
                            }
                            .padding(24)
                            .neuExtruded(cornerRadius: 24, elevation: 8)
                        }

                        VStack(alignment: .center, spacing: 16) {
                            Button("Save and Refresh") {
                                Task { await appModel.saveSettingsAndReconnect() }
                            }
                            .buttonStyle(NeuButtonTarget(isAccent: true))

                            Button("Refresh Hermes") {
                                Task {
                                    await appModel.chatStore.refreshConnection()
                                    await appModel.chatStore.refreshModels()
                                }
                            }
                            .buttonStyle(NeuButtonTarget(isAccent: false))

                            if let message = appModel.settingsStore.errorMessage ?? appModel.settingsStore
                                .statusMessage ?? appModel.statusMessage {
                                Text(message)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(appModel.settingsStore.errorMessage == nil ? NeuPalette
                                        .textSecondary : .red)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SETTINGS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(NeuPalette.accentCyan)
                Text("Configuration")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            Spacer()
        }
    }
}

/// Reusable Neu Input TextField
struct NeuTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .padding(.horizontal, 16)
            }
            TextField("", text: $text)
                .foregroundStyle(NeuPalette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .neuRecessed(cornerRadius: 16, depth: 6)
    }
}

/// Reusable Neu SecureField
struct NeuSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .padding(.horizontal, 16)
            }
            SecureField("", text: $text)
                .foregroundStyle(NeuPalette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .neuRecessed(cornerRadius: 16, depth: 6)
    }
}
