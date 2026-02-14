import SwiftUI

struct AgentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Agents")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Running sessions, models, tokens, and linked beads")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
