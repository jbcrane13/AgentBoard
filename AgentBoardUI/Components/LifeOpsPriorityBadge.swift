import AgentBoardCore
import SwiftUI

struct LifeOpsPriorityBadge: View {
    let priority: LifePriority

    var body: some View {
        Text(priority.displayName)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(backgroundColor.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(backgroundColor.opacity(0.6), lineWidth: 1)
            }
            .accessibilityIdentifier("lifeops.priority.badge")
    }

    private var backgroundColor: Color {
        switch priority {
        case .p0: NeuPalette.accentCoral
        case .p1: NeuPalette.accentOrange
        case .p2: NeuPalette.accentCyan
        case .p3: NeuPalette.textTertiary
        }
    }

    private var foregroundColor: Color {
        switch priority {
        case .p3: NeuPalette.textSecondary
        case .p0, .p1, .p2: backgroundColor
        }
    }
}
