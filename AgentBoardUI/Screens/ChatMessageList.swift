import AgentBoardCore
import SwiftUI

struct ChatMessageList: View {
    @Environment(AgentBoardAppModel.self) private var appModel
    @State private var scrollTarget: UUID?

    let isCompact: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        ScrollView {
            if appModel.chatStore.messages.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(appModel.chatStore.messages) { message in
                        NeuChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(isCompact ? 16 : 24)
            }
        }
        .scrollPosition(id: $scrollTarget, anchor: .bottom)
        .defaultScrollAnchor(.bottom)
        .onChange(of: appModel.chatStore.messages.last?.id, initial: true) { _, id in
            guard let id else { return }
            withAnimation {
                scrollTarget = id
            }
        }
        .onTapGesture {
            dismissKeyboard()
            AgentBoardKeyboard.dismiss()
        }
        .agentBoardScrollDismissesKeyboard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(NeuPalette.accentCyan)
            Text("Start a conversation")
                .font(.title3.weight(.bold))
                .foregroundStyle(NeuPalette.textPrimary)
            Text("Your messages stream live from the Hermes gateway and are saved locally.")
                .font(.subheadline)
                .foregroundStyle(NeuPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .neuExtruded(cornerRadius: 32, elevation: 12)
        .padding(32)
    }
}
