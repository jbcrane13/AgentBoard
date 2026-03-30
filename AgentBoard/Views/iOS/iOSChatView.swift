#if os(iOS)
    import SwiftUI

    struct iOSChatView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                ChatPanelView()
                    .navigationTitle(appState.agentName ?? "Agent Chat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(appState.chatConnectionState.color)
                                    .frame(width: 6, height: 6)
                                Text(appState.chatConnectionState.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(appState.chatConnectionState.color)
                            }
                        }
                    }
            }
            .onAppear {
                appState.clearUnreadChatCount()
            }
        }
    }
#endif
