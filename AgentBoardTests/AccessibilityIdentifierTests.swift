import Foundation
import Testing

/// Guardrail tests that pin accessibility identifiers for interactive elements
/// across AgentBoard's SwiftUI screens. The strings tested here are referenced
/// by XCUITest suites that run on the secondary node (the gateway has no GUI
/// session), so a refactor that drops or renames an identifier shows up here
/// before it breaks the UI test rig.
///
/// We grep the source for each `.accessibilityIdentifier("...")` call rather
/// than instantiating the views: AgentBoardCore's `AgentBoardAppModel` pulls in
/// the gateway client, settings repository, and several singletons that aren't
/// ergonomic to construct from a unit test, and the identifier strings are the
/// only contract UI tests actually rely on.
@Suite("Accessibility identifier coverage")
struct AccessibilityIdentifierTests {
    @Test("Settings screen exposes identifiers for every interactive control")
    func settingsScreenIdentifiers() throws {
        let source = try readUISource("Screens/SettingsScreen.swift")
        let required = [
            "screen_settings",
            "settings_picker_theme",
            "settings_textfield_hermes_gateway_url",
            "settings_textfield_hermes_model",
            "settings_securefield_hermes_api_key",
            "settings_textfield_hermes_profile_name",
            "settings_button_save_hermes_profile",
            "settings_securefield_github_token",
            "settings_textfield_repository_owner",
            "settings_textfield_repository_name",
            "settings_button_add_repository",
            "settings_textfield_companion_url",
            "settings_securefield_companion_token",
            "settings_slider_auto_refresh",
            "settings_button_export_config",
            "settings_button_import_config",
            "settings_button_apply_backup",
            "settings_button_copy_export_path",
            "settings_button_open_in_finder",
            "settings_button_close_export_share",
            "settings_button_save_and_refresh",
            "settings_button_refresh_hermes",
            "settings_button_diagnose_hermes"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Settings screen tags repeated profile/repo controls with the row id")
    func settingsScreenInterpolatedIdentifiers() throws {
        let source = try readUISource("Screens/SettingsScreen.swift")
        #expect(source.contains(#"settings_button_use_hermes_profile_\(profile.id)"#))
        #expect(source.contains(#"settings_button_remove_hermes_profile_\(profile.id)"#))
        #expect(source.contains(#"settings_button_remove_repository_\(repo.id)"#))
    }

    @Test("Task detail sheet exposes identifiers for every interactive control")
    func taskDetailSheetIdentifiers() throws {
        let source = try readUISource("Screens/TaskDetailSheet.swift")
        let required = [
            "screen_task_detail",
            "task_detail_button_close",
            "task_detail_menu_actions",
            "task_detail_button_add_comment",
            "task_detail_button_complete",
            "task_detail_button_block",
            "task_detail_button_archive",
            "task_detail_textfield_comment",
            "task_detail_button_cancel_comment",
            "task_detail_button_post_comment"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Quick launch sheet exposes identifiers for every interactive control")
    func quickLaunchSheetIdentifiers() throws {
        let source = try readUISource("Screens/QuickLaunchSheet.swift")
        let required = [
            "screen_quick_launch",
            "quick_launch_textfield_task_title",
            "quick_launch_textfield_issue_number",
            "quick_launch_textfield_repo_name",
            "quick_launch_texteditor_custom_instructions",
            "quick_launch_button_cancel",
            "quick_launch_button_launch"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"quick_launch_button_agent_\(agent.id)"#))
        #expect(source.contains(#"quick_launch_button_preset_\(preset.id)"#))
    }

    @Test("Session detail sheet exposes identifiers for every interactive control")
    func sessionDetailSheetIdentifiers() throws {
        let source = try readUISource("Screens/SessionDetailSheet.swift")
        let required = [
            "screen_session_detail",
            "session_detail_picker_mode",
            "session_detail_button_close",
            "session_detail_menu_actions",
            "session_detail_button_stop"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Sessions screen exposes identifiers for refresh + per-row taps")
    func sessionsScreenIdentifiers() throws {
        let source = try readUISource("Screens/SessionsScreen.swift")
        let required = [
            "screen_sessions",
            "sessions_button_refresh"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"sessions_cell_session_\(session.id)"#))
    }

    @Test("Attachment picker tags both platforms' cancel buttons")
    func attachmentPickerCancelIdentifier() throws {
        let source = try readUISource("Components/Attachments/AttachmentPicker.swift")
        let cancelOccurrences = source.components(separatedBy: "attachment_picker_button_cancel").count - 1
        #expect(cancelOccurrences >= 2, "expected attachment_picker_button_cancel on both iOS and macOS branches")
    }

    @Test("Media viewer tags the pager and each page")
    func mediaViewerIdentifiers() throws {
        let source = try readUISource("Components/Attachments/MediaViewerView.swift")
        #expect(source.contains("media_viewer_tabview"))
        #expect(source.contains(#"media_viewer_page_\(index)"#))
    }

    // MARK: - Helpers

    private func readUISource(_ relativePath: String) throws -> String {
        let url = repoRoot
            .appendingPathComponent("AgentBoardUI")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var repoRoot: URL {
        // This file lives at <repo>/AgentBoardTests/AccessibilityIdentifierTests.swift.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertIdentifiers(_ identifiers: [String], in source: String) {
        for identifier in identifiers {
            let token = ".accessibilityIdentifier(\"\(identifier)\")"
            #expect(source.contains(token), "missing identifier modifier: \(identifier)")
        }
    }
}
