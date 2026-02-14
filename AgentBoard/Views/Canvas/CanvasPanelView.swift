import SwiftUI
import WebKit

struct CanvasPanelView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Canvas")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Chat with your agent to see content here.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
