import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedChatBackend: ChatBackend = .platformDefault
    @State private var hermesGatewayURL = ""
    @State private var hermesAPIKey = ""
    @State private var openClawGatewayURL = ""
    @State private var openClawToken = ""
    @State private var isManualOpenClawConfig = false
    @State private var showingProjectImporter = false
    @State private var showingDirectoryPicker = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var isTesting = false
    @State private var showRemoteGuide = false
    @State private var showToolOutput = false
    @State private var showGitHubRepoPicker = false
    @State private var githubToken = ""
    @State private var githubOwner = ""
    @State private var githubRepo = ""
    @StateObject private var discovery = GatewayDiscovery()

    private enum ConnectionTestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle("Projects Directory")
                projectsDirectoryCard

                sectionTitle("Projects")
                projectsCard

                sectionTitle("Chat Gateway")
                gatewayHeroCard

                if selectedChatBackend == .hermes {
                    hermesGatewayCard
                } else {
                    openClawGatewayCard
                }

                if selectedChatBackend == .openClaw,
                   !discovery.discoveredGateways.isEmpty || discovery.isSearching {
                    discoveredGatewaysSection
                }

                gatewayGuideCard

                if let status = appState.statusMessage {
                    statusBanner(status, color: AppTheme.hermesAccent)
                }

                if let error = appState.errorMessage {
                    statusBanner(error, color: .red)
                }

                sectionTitle("Chat")
                chatPreferencesCard

                sectionTitle("GitHub Issues")
                gitHubCard
            }
            .padding(20)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .onAppear {
            refreshFormFromConfig()
        }
        .onChange(of: appState.selectedProjectID) { _, _ in
            refreshGitHubFields()
        }
        .onChange(of: selectedChatBackend) { _, newValue in
            if newValue == .openClaw, !isManualOpenClawConfig {
                refreshFromOpenClawConfig()
            }
            connectionTestResult = nil
            if newValue == .openClaw {
                showRemoteGuide = false
            }
        }
        .fileImporter(
            isPresented: $showingProjectImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                appState.addProject(at: url)
            }
        }
        .sheet(isPresented: $showGitHubRepoPicker) {
            GitHubRepoPickerView(token: githubToken.isEmpty ? (appState.appConfig.githubToken ?? "") : githubToken)
                .environment(appState)
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                appState.updateProjectsDirectory(url.path)
            }
        }
    }

    private var projectsDirectoryCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("AgentBoard auto-discovers repos with a `.beads/` folder inside this directory.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(appState.appConfig.resolvedProjectsDirectory.path)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

                    Button("Change…") {
                        showingDirectoryPicker = true
                    }
                    .buttonStyle(.bordered)

                    Button {
                        appState.rescanProjectsDirectory()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var projectsCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                if appState.projects.isEmpty {
                    Text("No projects found yet. Add a project folder or change the directory above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }

                ForEach(appState.projects) { project in
                    HStack(spacing: 12) {
                        Text(project.icon)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text(project.path.path)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button("Remove") {
                            appState.removeProject(project)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    showingProjectImporter = true
                } label: {
                    Label("Add Project Folder…", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.hermesAccent)
            }
        }
    }

    private var gatewayHeroCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedChatBackend == .hermes ? "Hermes Relay" : "OpenClaw Session Bridge")
                            .font(.system(size: 22, weight: .bold, design: .serif))

                        Text(selectedChatBackend == .hermes
                            ? "A calmer, gateway-first chat flow powered by the v2 Hermes SSE transport."
                            :
                            "The original WebSocket + session-routed chat path, kept for legacy workflows and session-aware controls.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    backendIcon
                }

                Picker("Chat Backend", selection: $selectedChatBackend) {
                    ForEach(ChatBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    infoPill(
                        title: "Status",
                        value: appState.chatConnectionState.label,
                        tint: appState.chatConnectionState.color
                    )
                    infoPill(
                        title: "Gateway",
                        value: selectedChatBackend.displayName,
                        tint: backendTint(selectedChatBackend)
                    )
                    infoPill(
                        title: selectedChatBackend == .hermes ? "Model" : "Mode",
                        value: selectedChatBackend == .hermes ? "hermes-agent" : "session-aware",
                        tint: backendTint(selectedChatBackend)
                    )
                }

                HStack(spacing: 10) {
                    Button("Save") {
                        saveChatSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(backendTint(selectedChatBackend))

                    Button {
                        testConnection()
                    } label: {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 90)
                        } else {
                            Label("Test Connection", systemImage: "bolt.horizontal")
                        }
                    }
                    .buttonStyle(.bordered)

                    if selectedChatBackend == .openClaw {
                        Button {
                            discovery.startBrowsing()
                        } label: {
                            Label("Scan Network", systemImage: "wifi")
                        }
                        .buttonStyle(.bordered)
                        .disabled(discovery.isSearching)
                    } else {
                        Button("Fresh Conversation") {
                            appState.clearHermesConversation()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!appState.usesHermesChat)
                    }
                }

                if let result = connectionTestResult {
                    switch result {
                    case let .success(message):
                        statusBanner(message, color: .green)
                    case let .failure(message):
                        statusBanner(message, color: .red)
                    }
                }

                if selectedChatBackend == appState.activeChatBackend,
                   let connError = appState.connectionErrorDetail,
                   appState.chatConnectionState != .connected {
                    if case .pairingRequired = connError {
                        PairingGuideView()
                    } else {
                        connectionErrorBanner(connError)
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    AppTheme.chatHeaderBackground,
                    backendTint(selectedChatBackend).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private var hermesGatewayCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                gatewayCardHeader(
                    title: "Hermes Gateway",
                    subtitle: "Hermes uses an OpenAI-compatible HTTP API. Chat streams from `/v1/chat/completions` and feels much lighter on iPhone."
                )

                labeledTextField(
                    title: "Gateway URL",
                    prompt: "http://100.x.y.z:8642",
                    text: $hermesGatewayURL,
                    accessibilityIdentifier: "settings_textfield_hermes_gateway_url"
                )

                if !hermesGatewayURL.isEmpty, !isValidGatewayURL(hermesGatewayURL) {
                    statusBanner("Use a valid http:// or https:// URL.", color: .orange)
                }

                labeledSecureField(
                    title: "API Key (Optional)",
                    prompt: "Bearer token",
                    text: $hermesAPIKey,
                    accessibilityIdentifier: "settings_textfield_hermes_api_key"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Why this mode feels better")
                        .font(.system(size: 12, weight: .semibold))
                    Text(
                        "Hermes keeps the UI in charge of the conversation state, so iPhone and macOS can share a cleaner " +
                            "streaming experience without the old session plumbing leaking into every screen."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(AppTheme.hermesAccentMuted, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var openClawGatewayCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                gatewayCardHeader(
                    title: "OpenClaw Gateway",
                    subtitle: "Legacy session-aware gateway with pairing, thinking levels, and remote session switching."
                )

                Picker("Configuration", selection: $isManualOpenClawConfig) {
                    Text("Auto-discover").tag(false)
                    Text("Manual").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isManualOpenClawConfig) { _, newValue in
                    if !newValue {
                        refreshFromOpenClawConfig()
                    }
                    connectionTestResult = nil
                }

                if isManualOpenClawConfig {
                    labeledTextField(
                        title: "Gateway URL",
                        prompt: "http://192.168.1.100:18789",
                        text: $openClawGatewayURL,
                        accessibilityIdentifier: "settings_textfield_gateway_url"
                    )

                    if !openClawGatewayURL.isEmpty, !isValidGatewayURL(openClawGatewayURL) {
                        statusBanner("URL should include a host and port.", color: .orange)
                    }

                    labeledSecureField(
                        title: "Auth Token",
                        prompt: "Gateway token",
                        text: $openClawToken,
                        accessibilityIdentifier: "settings_textfield_openclaw_token"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("URL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(openClawGatewayURL.isEmpty ? "Not discovered" : openClawGatewayURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(openClawGatewayURL.isEmpty ? .red : .primary)
                        }

                        HStack(spacing: 6) {
                            Text("Token")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(openClawToken.isEmpty ? "Not found" : maskedToken(openClawToken))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(openClawToken.isEmpty ? .red : .primary)
                        }

                        Button {
                            refreshFromOpenClawConfig()
                        } label: {
                            Label("Refresh From Config", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var discoveredGatewaysSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Discovered on Network")
                        .font(.system(size: 12, weight: .semibold))
                    if discovery.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ForEach(discovery.discoveredGateways) { gateway in
                    Button {
                        openClawGatewayURL = gateway.url
                        isManualOpenClawConfig = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "network")
                                .foregroundStyle(AppTheme.openClawAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gateway.name)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(gateway.url)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Use")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.openClawAccent)
                        }
                        .padding(10)
                        .background(AppTheme.openClawAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gatewayGuideCard: some View {
        settingsCard {
            DisclosureGroup(isExpanded: $showRemoteGuide) {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedChatBackend == .hermes {
                        guideItem(
                            icon: "network",
                            title: "LAN or Tailscale",
                            text: "Point iPhone or macOS at the machine running Hermes. A Tailscale URL like " +
                                "`http://100.x.y.z:8642` is usually the smoothest setup."
                        )
                        guideItem(
                            icon: "text.bubble",
                            title: "Chat-First Transport",
                            text: "Hermes mode only owns chat right now. tmux session monitoring and local launch flows still live on the macOS side."
                        )
                        guideItem(
                            icon: "key.fill",
                            title: "API Key",
                            text: "If your Hermes gateway requires bearer auth, paste that token here. Otherwise leave it blank."
                        )
                    } else {
                        guideItem(
                            icon: "network",
                            title: "LAN Connection",
                            text: "Use the gateway machine's LAN IP, or scan the network to discover local OpenClaw instances."
                        )
                        guideItem(
                            icon: "lock.shield",
                            title: "Tailscale or VPN",
                            text: "Remote access works well over Tailscale using the gateway host's private network IP."
                        )
                        guideItem(
                            icon: "person.badge.key",
                            title: "Device Pairing",
                            text: "OpenClaw requires device approval. If the first connection is rejected, use the pairing guide shown above."
                        )
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(
                    selectedChatBackend == .hermes ? "Hermes Gateway Guide" : "OpenClaw Gateway Guide",
                    systemImage: "questionmark.circle"
                )
                .font(.system(size: 13, weight: .medium))
            }
        }
    }

    private var chatPreferencesCard: some View {
        settingsCard {
            Toggle("Show detailed tool output in chat", isOn: $showToolOutput)
                .onChange(of: showToolOutput) { _, newValue in
                    appState.updateShowToolOutput(newValue)
                }
                .tint(AppTheme.hermesAccent)
        }
    }

    private var gitHubCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connect a GitHub repository to load issues live instead of reading `.beads/issues.jsonl`.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                labeledSecureField(
                    title: "GitHub Token",
                    prompt: "ghp_…",
                    text: $githubToken,
                    accessibilityIdentifier: "settings_textfield_github_token"
                )

                if appState.selectedProject != nil {
                    Divider()

                    Text("Project: \(appState.selectedProject?.name ?? "")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        labeledTextField(
                            title: "Owner",
                            prompt: "github-user-or-org",
                            text: $githubOwner,
                            accessibilityIdentifier: "settings_textfield_github_owner"
                        )
                        labeledTextField(
                            title: "Repository",
                            prompt: "repo-name",
                            text: $githubRepo,
                            accessibilityIdentifier: "settings_textfield_github_repo"
                        )
                    }

                    HStack(spacing: 10) {
                        if let syncDate = appState.lastGitHubSyncDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last synced: \(syncDate.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("\(appState.githubIssueCount) issues")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Not yet synced")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Sync Now") {
                            Task { await appState.refreshBeads() }
                        }
                        .disabled(appState.isLoadingBeads)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("settings_button_github_sync")
                    }
                }

                HStack(spacing: 10) {
                    Button("Save GitHub Settings") {
                        saveGitHubSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.hermesAccent)
                    .accessibilityIdentifier("settings_button_github_save")

                    if !githubToken.isEmpty {
                        Button {
                            showGitHubRepoPicker = true
                        } label: {
                            Label("Browse Repos…", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("settings_button_github_browse")
                    }
                }
            }
        }
    }

    private var backendIcon: some View {
        ZStack {
            Circle()
                .fill(backendTint(selectedChatBackend).opacity(0.12))
                .frame(width: 56, height: 56)
            Image(systemName: selectedChatBackend == .hermes
                ? "bolt.horizontal.circle.fill"
                : "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 26))
                .foregroundStyle(backendTint(selectedChatBackend))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .serif))
            .foregroundStyle(.primary)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(AppTheme.chatHeaderBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
    }

    private func gatewayCardHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeledTextField(
        title: String,
        prompt: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledSecureField(
        title: String,
        prompt: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            SecureField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.24), lineWidth: 1)
        )
    }

    private func connectionErrorBanner(_ connError: ConnectionError) -> some View {
        statusBanner(connError.userMessage, color: connError.indicatorColor)
    }

    private func guideItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(backendTint(selectedChatBackend))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func refreshFormFromConfig() {
        selectedChatBackend = appState.appConfig.resolvedChatBackend
        hermesGatewayURL = appState.appConfig.hermesGatewayURL ?? ""
        hermesAPIKey = appState.appConfig.hermesAPIKey ?? ""
        openClawGatewayURL = appState.appConfig.openClawGatewayURL ?? ""
        openClawToken = appState.appConfig.openClawToken ?? ""
        isManualOpenClawConfig = appState.appConfig.isGatewayManual
        showToolOutput = appState.appConfig.showToolOutputInChat ?? false
        githubToken = appState.appConfig.githubToken ?? ""
        refreshGitHubFields()

        if selectedChatBackend == .openClaw, !isManualOpenClawConfig {
            refreshFromOpenClawConfig()
        }
    }

    private func maskedToken(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "\u{2022}", count: token.count) }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)\u{2022}\u{2022}\u{2022}\(suffix)"
    }

    private func isValidGatewayURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }

    private func refreshFromOpenClawConfig() {
        let store = AppConfigStore()
        if let discovered = store.discoverOpenClawConfig() {
            openClawGatewayURL = discovered.gatewayURL ?? ""
            openClawToken = discovered.token ?? ""
        }
    }

    private func saveChatSettings() {
        switch selectedChatBackend {
        case .hermes:
            appState.updateHermesGateway(
                gatewayURL: hermesGatewayURL,
                apiKey: hermesAPIKey
            )
        case .openClaw:
            appState.updateOpenClaw(
                gatewayURL: openClawGatewayURL,
                token: openClawToken,
                source: isManualOpenClawConfig ? "manual" : "auto"
            )
        }

        appState.updateChatBackend(selectedChatBackend)
        connectionTestResult = nil
    }

    private func saveGitHubSettings() {
        appState.updateGitHubConfig(
            owner: githubOwner.isEmpty ? nil : githubOwner,
            repo: githubRepo.isEmpty ? nil : githubRepo,
            token: githubToken.isEmpty ? nil : githubToken
        )
    }

    private func refreshGitHubFields() {
        if let project = appState.selectedProject,
           let configured = appState.appConfig.projects.first(where: { $0.path == project.path.path }) {
            githubOwner = configured.githubOwner ?? ""
            githubRepo = configured.githubRepo ?? ""
        } else {
            githubOwner = ""
            githubRepo = ""
        }
    }

    private func testConnection() {
        isTesting = true
        connectionTestResult = nil

        Task {
            do {
                switch selectedChatBackend {
                case .hermes:
                    let service = HermesChatService()
                    try await service.configure(
                        gatewayURLString: hermesGatewayURL,
                        apiKey: hermesAPIKey
                    )
                    let healthy = try await service.healthCheck()
                    await MainActor.run {
                        connectionTestResult = healthy
                            ? .success("Hermes gateway is reachable.")
                            : .failure("Hermes gateway returned a non-healthy response.")
                        isTesting = false
                    }
                case .openClaw:
                    let client = GatewayClient()
                    guard let url = URL(string: openClawGatewayURL
                        .isEmpty ? "http://127.0.0.1:18789" : openClawGatewayURL) else {
                        await MainActor.run {
                            connectionTestResult = .failure("Invalid URL")
                            isTesting = false
                        }
                        return
                    }
                    try await client.connect(url: url, token: openClawToken.nilIfEmpty)
                    await client.disconnect()
                    await MainActor.run {
                        connectionTestResult = .success("OpenClaw gateway is reachable.")
                        isTesting = false
                    }
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func backendTint(_ backend: ChatBackend) -> Color {
        switch backend {
        case .hermes:
            return AppTheme.hermesAccent
        case .openClaw:
            return AppTheme.openClawAccent
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// swiftlint:enable file_length
