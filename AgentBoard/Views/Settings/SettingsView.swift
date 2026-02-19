import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var gatewayURL = ""
    @State private var token = ""
    @State private var isManualConfig = false
    @State private var showingProjectImporter = false
    @State private var showingDirectoryPicker = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var isTesting = false

    private enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Projects Directory")

                VStack(alignment: .leading, spacing: 8) {
                    Text("AgentBoard auto-discovers projects with a .beads/ folder in this directory.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(appState.appConfig.resolvedProjectsDirectory.path)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

                        Button("Change…") {
                            showingDirectoryPicker = true
                        }

                        Button {
                            appState.rescanProjectsDirectory()
                        } label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                sectionTitle("Projects")

                VStack(alignment: .leading, spacing: 10) {
                    if appState.projects.isEmpty {
                        Text("No projects found. Add a project folder or change the projects directory above.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }

                    ForEach(appState.projects) { project in
                        HStack(spacing: 10) {
                            Text(project.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.system(size: 13, weight: .semibold))
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
                        .padding(10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        showingProjectImporter = true
                    } label: {
                        Label("Add Project Folder…", systemImage: "plus")
                    }
                }

                sectionTitle("Gateway Connection")

                VStack(alignment: .leading, spacing: 12) {
                    // Auto vs Manual picker
                    Picker("Configuration", selection: $isManualConfig) {
                        Text("Auto-discover from OpenClaw").tag(false)
                        Text("Manual").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isManualConfig) { _, newValue in
                        if !newValue {
                            // Switching to auto — refresh from openclaw.json
                            refreshFromOpenClawConfig()
                        }
                        connectionTestResult = nil
                    }

                    if isManualConfig {
                        Text("Enter your OpenClaw gateway URL and auth token.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        TextField("Gateway URL (e.g. http://192.168.1.100:18789)", text: $gatewayURL)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Auth Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("URL:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(gatewayURL.isEmpty ? "Not discovered" : gatewayURL)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(gatewayURL.isEmpty ? .red : .primary)
                                }
                                HStack(spacing: 4) {
                                    Text("Token:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(token.isEmpty ? "Not found" : maskedToken(token))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(token.isEmpty ? .red : .primary)
                                }
                            }

                            Spacer()

                            Button {
                                refreshFromOpenClawConfig()
                                connectionTestResult = nil
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Save") {
                            saveGatewaySettings()
                        }

                        Button {
                            testConnection()
                        } label: {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                                Text("Testing…")
                            } else {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(isTesting || gatewayURL.isEmpty)
                    }

                    // Connection test result
                    if let result = connectionTestResult {
                        switch result {
                        case .success:
                            Label("Connected successfully!", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }

                    // Live connection error
                    if let connError = appState.connectionErrorDetail,
                       appState.chatConnectionState != .connected {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(connError.indicatorColor)
                                Text(connError.briefLabel)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(connError.indicatorColor)
                            }
                            Text(connError.userMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(connError.indicatorColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(connError.indicatorColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                if let status = appState.statusMessage {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            gatewayURL = appState.appConfig.openClawGatewayURL ?? ""
            token = appState.appConfig.openClawToken ?? ""
            isManualConfig = appState.appConfig.isGatewayManual
        }
        .fileImporter(
            isPresented: $showingProjectImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.addProject(at: url)
            }
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.updateProjectsDirectory(url.path)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private func maskedToken(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)•••\(suffix)"
    }

    private func refreshFromOpenClawConfig() {
        let store = AppConfigStore()
        if let discovered = store.discoverOpenClawConfig() {
            gatewayURL = discovered.gatewayURL ?? ""
            token = discovered.token ?? ""
        }
    }

    private func saveGatewaySettings() {
        appState.updateOpenClaw(
            gatewayURL: gatewayURL,
            token: token,
            source: isManualConfig ? "manual" : "auto"
        )
        connectionTestResult = nil
    }

    private func testConnection() {
        isTesting = true
        connectionTestResult = nil

        Task {
            let testClient = GatewayClient()
            do {
                guard let url = URL(string: gatewayURL.isEmpty ? "http://127.0.0.1:18789" : gatewayURL) else {
                    await MainActor.run {
                        connectionTestResult = .failure("Invalid URL")
                        isTesting = false
                    }
                    return
                }
                try await testClient.connect(url: url, token: token.isEmpty ? nil : token)
                await testClient.disconnect()
                await MainActor.run {
                    connectionTestResult = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
}
