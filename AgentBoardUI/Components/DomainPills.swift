import AgentBoardCore
import SwiftUI

struct WorkStatusPill: View {
    let state: WorkState

    var body: some View {
        BoardChip(label: state.title, systemImage: systemImage, tint: tint)
    }

    private var tint: Color {
        switch state {
        case .ready: AppTheme.statusBlue
        case .inProgress: AppTheme.accentOrange
        case .blocked: .red
        case .review: .purple
        case .done: AppTheme.accentGreen
        }
    }

    private var systemImage: String {
        switch state {
        case .ready: "circle"
        case .inProgress: "clock.arrow.circlepath"
        case .blocked: "exclamationmark.triangle"
        case .review: "eye"
        case .done: "checkmark.circle.fill"
        }
    }
}

struct PriorityPill: View {
    let priority: WorkPriority

    var body: some View {
        BoardChip(
            label: priority.title,
            systemImage: "flag.fill",
            tint: priority == .p0
                ? .red
                : priority == .p1 ? .orange : AppTheme.statusBlue
        )
    }
}

struct AgentHealthPill: View {
    let health: AgentHealthStatus

    var body: some View {
        BoardChip(label: health.title, systemImage: "waveform.path.ecg", tint: tint)
    }

    private var tint: Color {
        switch health {
        case .online: AppTheme.statusSuccess
        case .idle: AppTheme.statusIdle
        case .warning: AppTheme.accentOrange
        case .offline: .red
        }
    }
}

struct SessionStatusPill: View {
    let status: AgentSessionStatus

    var body: some View {
        BoardChip(label: status.title, systemImage: "bolt.circle.fill", tint: tint)
    }

    private var tint: Color {
        switch status {
        case .running: AppTheme.statusSuccess
        case .idle: AppTheme.statusIdle
        case .stopped: AppTheme.accentOrange
        case .error: .red
        }
    }
}
