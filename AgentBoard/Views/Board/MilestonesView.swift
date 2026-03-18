import SwiftUI

struct MilestonesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Milestones")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Coming soon — milestone progress tracking across all projects.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
        .accessibilityIdentifier("screen_milestones")
    }
}
