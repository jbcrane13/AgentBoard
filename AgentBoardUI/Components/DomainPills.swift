import AgentBoardCore
import SwiftUI

struct WorkStatusPill: View {
    let state: WorkState

    var body: some View {
        BoardChip(label: state.title, systemImage: systemImage, tint: tint)
    }

    private var tint: Color {
        switch state {
        case .open: NeuPalette.statusBlue
        case .inProgress: NeuPalette.accentOrange
        case .blocked: .red
        case .done: NeuPalette.statusClosed
        }
    }

    private var systemImage: String {
        switch state {
        case .open: "circle"
        case .inProgress: "clock.arrow.circlepath"
        case .blocked: "exclamationmark.triangle"
        case .done: "checkmark.circle"
        }
    }
}

struct PriorityPill: View {
    let priority: WorkPriority

    var body: some View {
        BoardChip(
            label: priority.title,
            systemImage: "flag.fill",
            tint: priority == .critical
                ? .red
                : priority == .high ? .red : NeuPalette.statusBlue
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
