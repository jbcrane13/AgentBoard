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
            NeuBackground()
            VStack(spacing: 0) {
                header
                    .padding(isCompact ? 16 : 24)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        appearanceSection(settingsStore: settingsStore)
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
    }

    // MARK: - Appearance

    private func appearanceSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("APPEARANCE")
            VStack(alignment: .leading, spacing: 16) {
                Picker("Theme", selection: $s.designTheme) {
                    ForEach(AgentBoardDesignTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .tint(NeuPalette.accentCyan)

                HStack(spacing: 10) {
                    ForEach(AgentBoardDesignTheme.allCases) { theme in
                        SettingsThemeSwatch(theme: theme, isSelected: s.designTheme == theme)
                    }
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    // MARK: - Hermes Gateway

    private func hermesSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("HERMES GATEWAY")
            VStack(spacing: 20) {
                NeuTextField(placeholder: "Gateway URL", text: $s.hermesGatewayURL)
                NeuTextField(placeholder: "Preferred model", text: $s.hermesModelID)
                NeuSecureField(placeholder: "API key (optional)", text: $s.hermesAPIKey)
                profilesSection(s: s)
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    private func profilesSection(s: SettingsStore) -> some View {
        @Bindable var s = s
        return VStack(alignment: .leading, spacing: 12) {
            Text("Saved Profiles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NeuPalette.textPrimary)

            if !s.hermesProfiles.isEmpty {
                VStack(spacing: 12) {
                    ForEach(s.hermesProfiles) { profile in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).font(.subheadline.weight(.medium))
                                    .foregroundStyle(NeuPalette.textPrimary)
                                Text(profile.gatewayURL).font(.caption)
                                    .foregroundStyle(NeuPalette.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Use") { s.selectHermesProfile(id: profile.id) }
                                .buttonStyle(NeuButtonTarget(isAccent: s.selectedHermesProfileID == profile.id))
                            Button(role: .destructive) { s.removeHermesProfile(profile) } label: {
                                Image(systemName: "trash.fill").foregroundStyle(.red).padding(10)
                            }
                            .background(Circle().fill(NeuPalette.background)).buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .neuRecessed(cornerRadius: 16, depth: 4)
                    }
                }
            }

            HStack(spacing: 12) {
                NeuTextField(placeholder: "Profile name", text: $hermesProfileName)
                Button("Save Current") {
                    s.saveCurrentHermesProfile(named: hermesProfileName)
                    if s.errorMessage == nil { hermesProfileName = "" }
                }
                .buttonStyle(NeuButtonTarget(isAccent: !hermesProfileName.isEmpty))
                .disabled(hermesProfileName.isEmpty)
            }
        }
    }

    // MARK: - GitHub

    private func githubSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("GITHUB ISSUES")
            VStack(alignment: .leading, spacing: 20) {
                NeuSecureField(placeholder: "GitHub token", text: $s.githubToken)
                if !s.repositories.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(s.repositories) { repo in
                            HStack {
                                Text(repo.fullName).font(.subheadline.weight(.medium))
                                    .foregroundStyle(NeuPalette.textPrimary)
                                Spacer()
                                Button(role: .destructive) { s.removeRepository(repo) } label: {
                                    Image(systemName: "trash.fill").foregroundStyle(.red).padding(10)
                                }
                                .background(Circle().fill(NeuPalette.background)).buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .neuRecessed(cornerRadius: 16, depth: 4)
                        }
                    }
                }
                HStack(spacing: 12) {
                    NeuTextField(placeholder: "Owner", text: $repositoryOwner)
                    NeuTextField(placeholder: "Repo", text: $repositoryName)
                    Button {
                        s.addRepository(owner: repositoryOwner, name: repositoryName)
                        repositoryOwner = ""
                        repositoryName = ""
                    } label: { Image(systemName: "plus") }
                        .buttonStyle(NeuButtonTarget(isAccent: !(repositoryOwner.isEmpty || repositoryName.isEmpty)))
                        .disabled(repositoryOwner.isEmpty || repositoryName.isEmpty)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    // MARK: - Companion

    private func companionSection(settingsStore: SettingsStore) -> some View {
        @Bindable var s = settingsStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("COMPANION SERVICE")
            VStack(spacing: 20) {
                NeuTextField(placeholder: "Companion URL", text: $s.companionURL)
                NeuSecureField(placeholder: "Companion token", text: $s.companionToken)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Auto refresh").font(.subheadline).foregroundStyle(NeuPalette.textPrimary)
                        Spacer()
                        Text("\(Int(s.autoRefreshInterval))s").font(.subheadline.weight(.bold))
                            .foregroundStyle(NeuPalette.accentCyan)
                    }
                    Slider(value: $s.autoRefreshInterval, in: 15 ... 120, step: 15)
                        .tint(NeuPalette.accentCyan)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
        }
    }

    // MARK: - Backup and Restore

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("BACKUP AND RESTORE")
            VStack(alignment: .leading, spacing: 16) {
                Text("Export your configuration to restore on another device or after a fresh install.")
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)

                HStack(spacing: 12) {
                    Button {
                        Task { await exportBackup() }
                    } label: {
                        Label("Export Config", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(NeuButtonTarget(isAccent: true))

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Config", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(NeuButtonTarget(isAccent: false))
                }

                if let summary = backupSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pending Import Preview")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NeuPalette.accentCyan)
                        Text(summary.description)
                            .font(.caption)
                            .foregroundStyle(NeuPalette.textPrimary)
                        Button("Apply Backup") {
                            Task { await applyPendingBackup() }
                        }
                        .buttonStyle(NeuButtonTarget(isAccent: true))
                    }
                    .padding(12)
                    .neuRecessed(cornerRadius: 12, depth: 4)
                }

                if let msg = backupStatusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }
            .padding(24)
            .neuExtruded(cornerRadius: 24, elevation: 8)
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
                #if os(iOS)
                    ShareSheet(items: [url])
                #else
                    VStack(spacing: 16) {
                        Text("Backup exported to:")
                            .font(.headline)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(NeuPalette.textSecondary)
                        HStack {
                            Button("Copy Path") {
                                #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.path, forType: .string)
                                #endif
                            }
                            .buttonStyle(NeuButtonTarget(isAccent: false))

                            Button("Open in Finder") {
                                #if os(macOS)
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                #endif
                            }
                            .buttonStyle(NeuButtonTarget(isAccent: true))

                            Button("Close") {
                                showExportShare = false
                            }
                            .buttonStyle(NeuButtonTarget(isAccent: false))
                        }
                    }
                    .padding(32)
                    .frame(minWidth: 400)
                #endif
            }
        }
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
            .buttonStyle(NeuButtonTarget(isAccent: true))

            Button("Refresh Hermes") {
                Task {
                    await appModel.chatStore.refreshConnection()
                    await appModel.chatStore.refreshModels()
                }
            }
            .buttonStyle(NeuButtonTarget(isAccent: false))

            Button("Diagnose Hermes") {
                Task { await appModel.chatStore.diagnoseConnection() }
            }
            .buttonStyle(NeuButtonTarget(isAccent: false))

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
                            ? NeuPalette.textSecondary : .red
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
                    .foregroundStyle(NeuPalette.textPrimary)
                    .tracking(-0.8)
            }
            Spacer()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1)
            .foregroundStyle(NeuPalette.textSecondary)
            .padding(.horizontal, 8)
    }
}

private struct SettingsThemeSwatch: View {
    let theme: AgentBoardDesignTheme
    let isSelected: Bool

    var body: some View {
        let palette = NeuTheme.preset(theme)
        return HStack(spacing: 10) {
            HStack(spacing: -5) {
                Circle()
                    .fill(palette.background)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(palette.surfaceRaised)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(palette.primaryAccentBright)
                    .frame(width: 20, height: 20)
            }
            Text(theme.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? NeuPalette.textPrimary : NeuPalette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NeuPalette.inset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? palette.primaryAccentBright : NeuPalette.borderSoft,
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }
}

// MARK: - Shared Components

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
                .agentBoardTextInputAutocapitalizationNever()
        }
        .neuRecessed(cornerRadius: 16, depth: 6)
    }
}

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
                .agentBoardTextInputAutocapitalizationNever()
        }
        .neuRecessed(cornerRadius: 16, depth: 6)
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
