import AgentBoardCore
import SwiftUI

/// Hermes profile management: the saved-profile list, per-profile secrets
/// (API key + dashboard credential, both Keychain-backed), the dashboard URL
/// that selects a remote kanban backend, and the colour swatch row.
extension SettingsScreen {
    func profilesSection(s: SettingsStore) -> some View {
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
                            Button(role: .destructive) {
                                Task { await s.removeHermesProfile(profile) }
                            } label: {
                                Image(systemName: "trash.fill").foregroundStyle(.red).padding(10)
                            }
                            .background(Circle().fill(AppTheme.background)).buttonStyle(.plain)
                            .accessibilityIdentifier("settings_button_remove_hermes_profile_\(profile.id)")
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .insetSurface(cornerRadius: 16)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                labeledField("Profile API Key", alignment: .top) {
                    AppSecureField(placeholder: "API key for this profile (optional)", text: $s.hermesAPIKey)
                        .accessibilityIdentifier("settings_securefield_profile_api_key")
                }
                labeledField("Profile Color", alignment: .top) {
                    profileColorSwatchRow
                }
                labeledField("Dashboard URL", alignment: .top) {
                    AppTextField(placeholder: "http://<host>:9119 (optional)", text: $s.hermesDashboardURL)
                        .accessibilityIdentifier("settings_textfield_dashboard_url")
                }
                labeledField("Dashboard Username", alignment: .top) {
                    AppTextField(placeholder: "Dashboard username (optional)", text: $s.hermesDashboardUsername)
                        .accessibilityIdentifier("settings_textfield_dashboard_username")
                }
                labeledField("Dashboard Password", alignment: .top) {
                    AppSecureField(placeholder: "Dashboard password (optional)", text: $s.hermesDashboardPassword)
                        .accessibilityIdentifier("settings_securefield_dashboard_password")
                }
                Text(
                    "Dashboard credentials are stored in the Keychain. Leave the URL empty to keep " +
                        "the board reading the local ~/.hermes/kanban.db."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 12) {
                    labeledField("Profile Name", alignment: .top) {
                        AppTextField(placeholder: "Profile name", text: $hermesProfileName)
                            .accessibilityIdentifier("settings_textfield_hermes_profile_name")
                    }
                    Button("Save Current") {
                        Task {
                            await s.saveCurrentHermesProfile(named: hermesProfileName)
                            if s.errorMessage == nil {
                                applyPendingProfileColor(named: hermesProfileName, s: s)
                                hermesProfileName = ""
                                hermesProfileColorHex = nil
                            }
                        }
                    }
                    .buttonStyle(AppButtonStyle(isAccent: !hermesProfileName.isEmpty))
                    .disabled(hermesProfileName.isEmpty)
                    .accessibilityIdentifier("settings_button_save_hermes_profile")
                }
            }
        }
    }

    /// Row of tappable swatches from the fixed Hermes-profile color palette; selecting one
    /// stages a color override applied to the profile by `applyPendingProfileColor` on save.
    private var profileColorSwatchRow: some View {
        HStack(spacing: 8) {
            ForEach(SettingsStore.hermesProfileColorPalette, id: \.self) { hex in
                Button {
                    hermesProfileColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? AppTheme.textTertiary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(AppTheme.textPrimary, lineWidth: hermesProfileColorHex == hex ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile color \(hex)")
            }
        }
        .accessibilityIdentifier("settings_picker_profile_color")
    }

    /// Applies the staged `hermesProfileColorHex` (if any) to the profile just saved under
    /// `name`, overriding the palette color `saveCurrentHermesProfile` auto-assigned.
    private func applyPendingProfileColor(named name: String, s: SettingsStore) {
        guard let colorHex = hermesProfileColorHex,
              let index = s.hermesProfiles.firstIndex(where: {
                  $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
              }) else { return }
        s.hermesProfiles[index].colorHex = colorHex
    }
}
