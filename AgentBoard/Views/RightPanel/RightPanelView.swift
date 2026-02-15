import SwiftUI

struct RightPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            switch appState.rightPanelMode {
            case .chat:
                ChatPanelView()
            case .canvas:
                CanvasPanelView()
            case .split:
                SplitPanelView()
            }
        }
        .background(AppTheme.panelBackground)
        .onChange(of: appState.rightPanelMode) { _, mode in
            if mode == .chat || mode == .split {
                appState.clearUnreadChatCount()
            }
        }
    }

    private var panelHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color(red: 0.9, green: 0.478, blue: 0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                Text("Agent Chat")
                    .font(.system(size: 14, weight: .semibold))

                if appState.unreadChatCount > 0 {
                    Text("\(appState.unreadChatCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.chatConnectionState.color)
                        .frame(width: 6, height: 6)
                    Text(appState.chatConnectionState.label)
                        .font(.system(size: 11))
                        .foregroundStyle(appState.chatConnectionState.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            modePicker
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            Divider()
        }
    }

    private var modePicker: some View {
        @Bindable var state = appState
        return Picker("Mode", selection: $state.rightPanelMode) {
            ForEach(RightPanelMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
