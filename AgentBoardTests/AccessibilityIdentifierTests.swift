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

    @Test("Attachment preview strip tags each remove button with its row id")
    func attachmentPreviewStripIdentifiers() throws {
        let source = try readUISource("Components/Attachments/AttachmentPicker.swift")
        #expect(source.contains(#"attachment_preview_button_remove_\(attachment.id)"#))
    }

    @Test("Image and video attachment taps expose per-attachment identifiers")
    func attachmentTapIdentifiers() throws {
        let source = try readUISource("Components/Attachments/AttachmentViews.swift")
        #expect(source.contains(#"attachment_image_\(attachment.id)"#))
        #expect(source.contains(#"attachment_video_\(attachment.id)"#))
    }

    @Test("Chat bubble tags each rendered attachment with its id")
    func chatBubbleAttachmentIdentifiers() throws {
        let source = try readUISource("Components/ChatBubble.swift")
        #expect(source.contains(#"chat_bubble_attachment_\(attachment.id)"#))
    }

    @Test("Media viewer tags the pager and each page")
    func mediaViewerIdentifiers() throws {
        let source = try readUISource("Components/Attachments/MediaViewerView.swift")
        #expect(source.contains("media_viewer_tabview"))
        #expect(source.contains(#"media_viewer_page_\(index)"#))
    }

    @Test("Chat screen exposes identifiers for header, compose, and conversation rail controls")
    func chatScreenIdentifiers() throws {
        let source = try readUISource("Screens/ChatScreen.swift")
        let required = [
            "chat_button_toggle_chat_only",
            "chat_button_refresh",
            "chat_menu_session",
            "chat_menu_profile",
            "chat_menu_session_desktop",
            "chat_menu_profile_desktop",
            "chat_menuitem_session_new",
            "chat_textfield_rename_conversation",
            "chat_button_confirm_rename",
            "chat_menuitem_rename_conversation",
            "chat_menuitem_delete_conversation",
            "chat_button_attach",
            "chat_textfield_draft",
            "chat_button_send"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"chat_menuitem_session_\(conversation.id.uuidString)"#))
        #expect(source.contains(#"chat_menuitem_profile_\(profile.id)"#))
        #expect(source.contains(#"chat_button_conversation_\(conversation.id.uuidString)"#))
        #expect(source.contains(#"chat_button_slashcmd_\(cmd.name.dropFirst())"#))
    }

    @Test("Kanban board exposes identifiers for create flow and per-row actions")
    func agentsScreenIdentifiers() throws {
        let source = try readUISource("Screens/AgentsScreen.swift")
        let required = [
            "kanban_button_new_task",
            "kanban_textfield_title",
            "kanban_picker_assignee",
            "kanban_textfield_body",
            "kanban_picker_priority",
            "kanban_button_cancel",
            "kanban_button_create",
            "kanban_menuitem_launch_session",
            "kanban_menuitem_archive",
            "kanban_alert_button_archive",
            "kanban_alert_button_cancel"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"kanban_cell_task_\(task.id)"#))
    }

    @Test("Work screen exposes identifiers for header, search, repo picker, and create flow")
    func workScreenIdentifiers() throws {
        let source = try readUISource("Screens/WorkScreen.swift")
        let required = [
            "screen_work",
            "work_section_header",
            "work_button_search",
            "work_textfield_search",
            "work_button_create_issue",
            "work_picker_repository"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"work_column_\(column.state.rawValue)"#))
    }

    @Test("Create issue sheet exposes identifiers for every interactive control")
    func createIssueSheetIdentifiers() throws {
        let source = try readUISource("Screens/CreateIssueSheet.swift")
        let required = [
            "create_issue_picker_repository",
            "create_issue_textfield_title",
            "create_issue_texteditor_body",
            "create_issue_picker_type",
            "create_issue_picker_priority",
            "create_issue_picker_status",
            "create_issue_picker_agent",
            "create_issue_textfield_milestone",
            "create_issue_button_add_attachment",
            "create_issue_button_cancel",
            "create_issue_button_create"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Issue detail sheet exposes identifiers for view, edit, and lifecycle controls")
    func issueDetailSheetIdentifiers() throws {
        let source = try readUISource("Screens/IssueDetailSheet.swift")
        let required = [
            "issue_detail_button_close",
            "issue_detail_button_save",
            "issue_detail_button_edit",
            "issue_detail_button_toolbar_reopen",
            "issue_detail_button_toolbar_close_issue",
            "issue_detail_launch_session",
            "issue_detail_textfield_title",
            "issue_detail_texteditor_body",
            "issue_detail_textfield_milestone",
            "issue_detail_button_add_attachment",
            "issue_detail_button_card_reopen",
            "issue_detail_button_card_close_issue",
            "edit_issue_picker_type",
            "edit_issue_picker_priority",
            "edit_issue_picker_status",
            "edit_issue_picker_agent"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Session terminal view exposes identifiers for embedded, failed, and stalled states")
    func sessionTerminalViewIdentifiers() throws {
        let source = try readUISource("Screens/SessionTerminalView.swift")
        let required = [
            "session_terminal_toggle_expand",
            "session_terminal_open_terminal",
            "session_terminal_close",
            "session_terminal_embedded",
            "session_terminal_failed_open_terminal",
            "session_terminal_failed_close",
            "session_terminal_stalled_open_terminal",
            "session_terminal_stalled_close"
        ]
        assertIdentifiers(required, in: source)
    }

    @Test("Launch session sheet exposes identifiers for every interactive control")
    func launchSessionSheetIdentifiers() throws {
        let source = try readUISource("Screens/LaunchSessionSheet.swift")
        let required = [
            "screen_launchSession",
            "launchSession_textfield_repoName",
            "launchSession_textEditor_customInstructions",
            "launchSession_button_cancel",
            "launchSession_button_launch"
        ]
        assertIdentifiers(required, in: source)
        #expect(source.contains(#"launchSession_button_agent_\(agent.id)"#))
        #expect(source.contains(#"launchSession_button_preset_\(preset.id)"#))
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
