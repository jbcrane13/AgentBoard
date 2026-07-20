import AgentBoardCore
import SwiftUI

struct SettingsScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var repositoryOwner = ""
    @State private var repositoryName = ""
    @State private var hermesProfileName = ""
    @State private var backupService: ConfigBackupService?
    @State private var backupSummary: BackupSummary?
    @State private var backupStatusMessage: String?
    @State private var showImportPicker = false
    @State private var showExportShare = false
    @State private var exportedFileURL: URL?
    @State private var lastImportedURL: URL?

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        @Bindable var settingsStore = appModel.settingsStore

        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        hermesSection(settingsStore: settingsStore)
                        githubSection(settingsStore: settingsStore)
                        companionSection(settingsStore: settingsStore)
                        backupSection
                        actionButtons
                    }
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
        .agentBoardKeyboardDismissToolbar()
        .accessibilityIdentifier("screen_settings")
    }

    // MARK: - Hermes Gateway

    private func hermesSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("HERMES GATEWAY")
            VStack(spacing: 20) {
                AppTextField(placeholder: "Gateway URL", text: $s.hermesGatewayURL)
                    .accessibilityIdentifier("settings_textfield_hermes_gateway_url")
                AppTextField(placeholder: "Preferred model", text: $s.hermesModelID)
                    .accessibilityIdentifier("settings_textfield_hermes_model")
                AppSecureField(placeholder: "API key (optional)", text: $s.hermesAPIKey)
                    .accessibilityIdentifier("settings_securefield_hermes_api_key")
                profilesSection(s: s)
            }
            .padding(24)
            .cardSurface(cornerRadius: 24, elevation: 8)
        }
    }

    private func profilesSection(s: SettingsStore) -> some View {
        @Bindable var s = s
        return VStack(alignment: .leading, spacing: 12) {
            Text("Saved Profiles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if !s.hermesProfiles.isEmpty {
                VStack(spacing: 12) {
                    ForEach(s.hermesProfiles) { profile in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(profile.gatewayURL).font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Use") { s.selectHermesProfile(id: profile.id) }
                                .buttonStyle(AppButtonStyle(isAccent: s.selectedHermesProfileID == profile.id))
                                .accessibilityIdentifier("settings_button_use_hermes_profile_\(profile.id)")
                            Button(role: .destructive) { s.removeHermesProfile(profile) } label: {
                                Image(systemName: "trash.fill").foregroundStyle(.red).padding(10)
                            }
                            .background(Circle().fill(AppTheme.background)).buttonStyle(.plain)
                            .accessibilityIdentifier("settings_button_remove_hermes_profile_\(profile.id)")
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .insetSurface(cornerRadius: 16, depth: 4)
                    }
                }
            }

            HStack(spacing: 12) {
                AppTextField(placeholder: "Profile name", text: $hermesProfileName)
                    .accessibilityIdentifier("settings_textfield_hermes_profile_name")
                Button("Save Current") {
                    s.saveCurrentHermesProfile(named: hermesProfileName)
                    if s.errorMessage == nil { hermesProfileName = "" }
                }
                .buttonStyle(AppButtonStyle(isAccent: !hermesProfileName.isEmpty))
                .disabled(hermesProfileName.isEmpty)
                .accessibilityIdentifier("settings_button_save_hermes_profile")
            }
        }
    }

    // MARK: - GitHub

    private func githubSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("GITHUB ISSUES")
            VStack(alignment: .leading, spacing: 20) {
                AppSecureField(placeholder: "GitHub token", text: $s.githubToken)
                    .accessibilityIdentifier("settings_securefield_github_token")
                if !s.repositories.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(s.repositories) { repo in
                            HStack {
                                Text(repo.fullName).font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button(role: .destructive) { s.removeRepository(repo) } label: {
                                    Image(systemName: "trash.fill").foregroundStyle(.red).padding(10)
                                }
                                .background(Circle().fill(AppTheme.background)).buttonStyle(.plain)
                                .accessibilityIdentifier("settings_button_remove_repository_\(repo.id)")
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .insetSurface(cornerRadius: 16, depth: 4)
                        }
                    }
                }
                HStack(spacing: 12) {
                    AppTextField(placeholder: "Owner", text: $repositoryOwner)
                        .accessibilityIdentifier("settings_textfield_repository_owner")
                    AppTextField(placeholder: "Repo", text: $repositoryName)
                        .accessibilityIdentifier("settings_textfield_repository_name")
                    Button {
                        s.addRepository(owner: repositoryOwner, name: repositoryName)
                        repositoryOwner = ""
                        repositoryName = ""
                    } label: { Image(systemName: "plus") }
                        .buttonStyle(AppButtonStyle(isAccent: !(repositoryOwner.isEmpty || repositoryName.isEmpty)))
                        .disabled(repositoryOwner.isEmpty || repositoryName.isEmpty)
                        .accessibilityIdentifier("settings_button_add_repository")
                }
            }
            .padding(24)
            .cardSurface(cornerRadius: 24, elevation: 8)
        }
    }

    // MARK: - Companion

    private func companionSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("COMPANION SERVICE")
            VStack(spacing: 20) {
                AppTextField(placeholder: "Companion URL", text: $s.companionURL)
                    .accessibilityIdentifier("settings_textfield_companion_url")
                AppSecureField(placeholder: "Companion token", text: $s.companionToken)
                    .accessibilityIdentifier("settings_securefield_companion_token")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Auto refresh").font(.subheadline).foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(Int(s.autoRefreshInterval))s").font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.accentCyan)
                    }
                    Slider(value: $s.autoRefreshInterval, in: 30 ... 300, step: 30)
                        .tint(AppTheme.accentCyan)
                        .accessibilityIdentifier("settings_slider_auto_refresh")
                }
            }
            .padding(24)
            .cardSurface(cornerRadius: 24, elevation: 8)
        }
    }

    // MARK: - Backup and Restore

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("BACKUP AND RESTORE")
            VStack(alignment: .leading, spacing: 16) {
                Text("Export your configuration to restore on another device or after a fresh install.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Button {
                        Task { await exportBackup() }
                    } label: {
                        Label("Export Config", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(AppButtonStyle(isAccent: true))
                    .accessibilityIdentifier("settings_button_export_config")

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Config", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(AppButtonStyle(isAccent: false))
                    .accessibilityIdentifier("settings_button_import_config")
                }

                if let summary = backupSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pending Import Preview")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accentCyan)
                        Text(summary.description)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                        Button("Apply Backup") {
                            Task { await applyPendingBackup() }
                        }
                        .buttonStyle(AppButtonStyle(isAccent: true))
                        .accessibilityIdentifier("settings_button_apply_backup")
                    }
                    .padding(12)
                    .insetSurface(cornerRadius: 12, depth: 4)
                }

                if let msg = backupStatusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(24)
            .cardSurface(cornerRadius: 24, elevation: 8)
        }
        .onAppear {
            if backupService == nil {
                backupService = ConfigBackupService(
                    settingsStore: appModel.settingsStore,
                    repository: SettingsRepository()
                )
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportedFileURL {
                exportShareSheet(for: url)
            }
        }
    }

    @ViewBuilder
    private func exportShareSheet(for url: URL) -> some View {
        #if os(iOS)
            ShareSheet(items: [url])
        #else
            VStack(spacing: 16) {
                Text("Backup exported to:").font(.headline)
                Text(url.lastPathComponent).font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.path, forType: .string)
                    }
                    .buttonStyle(AppButtonStyle(isAccent: false))
                    .accessibilityIdentifier("settings_button_copy_export_path")

                    Button("Open in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(AppButtonStyle(isAccent: true))
                    .accessibilityIdentifier("settings_button_open_in_finder")

                    Button("Close") { showExportShare = false }
                        .buttonStyle(AppButtonStyle(isAccent: false))
                        .accessibilityIdentifier("settings_button_close_export_share")
                }
            }
            .padding(32)
            .frame(minWidth: 400)
        #endif
    }

    private func exportBackup() async {
        guard let service = backupService else { return }
        do {
            let data = try await service.exportBackupData()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let filename = "agentboard-backup-\(formatter.string(from: .now)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            exportedFileURL = url
            showExportShare = true
            backupStatusMessage = "Backup ready."
        } catch {
            backupStatusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        guard let service = backupService else { return }
        do {
            let data = try Data(contentsOf: url)
            let summary = try service.validateBackup(data)
            backupSummary = summary
            lastImportedURL = url
            backupStatusMessage = nil
        } catch {
            backupStatusMessage = "Import failed: \(error.localizedDescription)"
            backupSummary = nil
        }
    }

    private func applyPendingBackup() {
        guard let service = backupService, let url = lastImportedURL else { return }
        Task {
            do {
                let data = try Data(contentsOf: url)
                try await service.restoreFromBackup(data)
                backupSummary = nil
                lastImportedURL = nil
                backupStatusMessage = "Backup restored successfully."
                await appModel.settingsStore.bootstrap()
                await appModel.saveSettingsAndReconnect()
            } catch {
                backupStatusMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(alignment: .center, spacing: 16) {
            Button("Save and Refresh") {
                Task { await appModel.saveSettingsAndReconnect() }
            }
            .buttonStyle(AppButtonStyle(isAccent: true))
            .accessibilityIdentifier("settings_button_save_and_refresh")

            Button("Refresh Hermes") {
                Task {
                    await appModel.chatStore.refreshConnection()
                    await appModel.chatStore.refreshModels()
                }
            }
            .buttonStyle(AppButtonStyle(isAccent: false))
            .accessibilityIdentifier("settings_button_refresh_hermes")

            Button("Diagnose Hermes") {
                Task { await appModel.chatStore.diagnoseConnection() }
            }
            .buttonStyle(AppButtonStyle(isAccent: false))
            .accessibilityIdentifier("settings_button_diagnose_hermes")

            if let msg = appModel.settingsStore.errorMessage
                ?? appModel.settingsStore.statusMessage
                ?? appModel.chatStore.errorMessage
                ?? appModel.chatStore.statusMessage
                ?? appModel.statusMessage {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(
                        appModel.settingsStore.errorMessage == nil
                            && appModel.chatStore.errorMessage == nil
                            ? AppTheme.textSecondary : .red
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                AgentBoardEyebrow(text: "SETTINGS")
                Text("Configuration")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 8)
    }
}

// MARK: - Shared Components

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .agentBoardTextInputAutocapitalizationNever()
    }
}

struct AppSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .agentBoardTextInputAutocapitalizationNever()
    }
}

// MARK: - iOS Share Sheet

#if os(iOS)
    import UIKit

    struct ShareSheet: UIViewControllerRepresentable {
        let items: [Any]

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
