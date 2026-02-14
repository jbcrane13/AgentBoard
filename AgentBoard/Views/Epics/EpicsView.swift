import SwiftUI

struct EpicsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Epics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Grouped epic view with progress tracking")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
