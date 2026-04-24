import AgentBoardCore
import SwiftUI

struct WorkStatusPill: View {
    let state: WorkState

    var body: some View {
        BoardChip(label: state.title, systemImage: systemImage, tint: tint)
    }

    private var tint: Color {
        switch state {
        case .open: BoardPalette.cobalt
        case .inProgress: BoardPalette.gold
        case .blocked: BoardPalette.rose
        case .done: BoardPalette.mint
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
                ? BoardPalette.rose
                : priority == .high ? BoardPalette.coral : BoardPalette.cobalt
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
        case .online: BoardPalette.mint
        case .idle: BoardPalette.cobalt
        case .warning: BoardPalette.gold
        case .offline: BoardPalette.rose
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
        case .running: BoardPalette.mint
        case .idle: BoardPalette.cobalt
        case .stopped: BoardPalette.gold
        case .error: BoardPalette.rose
        }
    }
}
