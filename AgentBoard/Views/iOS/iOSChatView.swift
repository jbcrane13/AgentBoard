#if os(iOS)
    import SwiftUI

    struct iOSChatView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                ChatPanelView()
                    .navigationTitle("Chat")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                appState.clearUnreadChatCount()
            }
        }
    }
#endif
