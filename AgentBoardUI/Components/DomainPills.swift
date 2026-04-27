import AgentBoardCore
import SwiftUI

struct WorkStatusPill: View {
    let state: WorkState

    var body: some View {
        BoardChip(label: state.title, systemImage: systemImage, tint: tint)
    }

    private var tint: Color {
        switch state {
        case .ready: NeuPalette.statusBlue
        case .inProgress: NeuPalette.accentOrange
        case .blocked: .red
        case .review: .purple
        }
    }

    private var systemImage: String {
        switch state {
        case .ready: "circle"
        case .inProgress: "clock.arrow.circlepath"
        case .blocked: "exclamationmark.triangle"
        case .review: "eye"
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
                : priority == .p1 ? .orange : NeuPalette.statusBlue
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
        case .online: NeuPalette.statusSuccess
        case .idle: NeuPalette.statusIdle
        case .warning: NeuPalette.accentOrange
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
        case .running: NeuPalette.statusSuccess
        case .idle: NeuPalette.statusIdle
        case .stopped: NeuPalette.accentOrange
        case .error: .red
        }
    }
}
