import SwiftUI

struct HistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Timeline of bead changes, commits, and session events")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
