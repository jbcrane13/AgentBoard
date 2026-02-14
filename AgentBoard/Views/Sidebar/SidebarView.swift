import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectListView()

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            SessionListView()

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            ViewsNavView()

            Spacer()

            newSessionButton
        }
        .frame(minWidth: 220, idealWidth: 220, maxWidth: 220)
        .background(Color(red: 0.173, green: 0.173, blue: 0.18))
    }

    private var newSessionButton: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("New Session")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }
}
