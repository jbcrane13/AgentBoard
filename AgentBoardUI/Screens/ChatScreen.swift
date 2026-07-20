import AgentBoardCore
import SwiftUI

#if os(iOS)
    import UIKit
#endif

struct ChatScreen: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @FocusState private var isTextFieldFocused: Bool
    @State private var showAttachmentPicker = false
    @State private var audioRecorder = AudioRecorderService()

    /// When set, ChatScreen renders a "chat-only" toggle in its header.
    /// The hosting view manages the actual hide/show and window-resize logic.
    var onToggleChatOnly: (() -> Void)?
    var isChatOnlyMode: Bool = false

    private var isCompact: Bool {
        hSizeClass == .compact
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            VStack(spacing: 0) {
                ChatHeader(
                    isCompact: isCompact,
                    onToggleChatOnly: onToggleChatOnly,
                    isChatOnlyMode: isChatOnlyMode
                )
                .padding(.horizontal, 16)
                .padding(.top, isCompact ? 12 : 10)
                .padding(.bottom, 8)
                .background(AppTheme.surface.ignoresSafeArea())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.borderSoft)
                        .frame(height: 1)
                }

                ChatMessageList(isCompact: isCompact) {
                    isTextFieldFocused = false
                }

                ChatComposeBar(
                    showAttachmentPicker: $showAttachmentPicker,
                    audioRecorder: audioRecorder,
                    isCompact: isCompact,
                    isTextFieldFocused: $isTextFieldFocused
                ) {
                    isTextFieldFocused = false
                }
            }
        }
        .agentBoardNavigationBarHidden(true)
        .agentBoardKeyboardDismissToolbar()
        .accessibilityIdentifier("screen_chat")
        #if os(iOS)
            .task {
                for await _ in NotificationCenter.default.notifications(
                    named: UIApplication.willEnterForegroundNotification
                ) {
                    await appModel.chatStore.autoReconnectIfNeeded()
                }
            }
        #endif
    }
}
