#if os(iOS)
    import SwiftUI

    struct iOSChatView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                ChatPanelView()
                    .navigationTitle(appState.currentSessionKey)
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
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("main") {
                                    Task { await appState.switchSession(to: "main") }
                                }
                                if !appState.gatewaySessions.isEmpty {
                                    Divider()
                                    ForEach(appState.gatewaySessions.filter { $0.key != "main" }) { session in
                                        Button(session.label ?? session.key) {
                                            Task { await appState.switchSession(to: session.key) }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.system(size: 14))
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
