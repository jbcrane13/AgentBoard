import AgentBoardCore
import SwiftUI

// MARK: - Consolidated status primitives

/// A small filled circle. Flat — no glow, no shadow. The single bare-dot
/// indicator used across the boards in place of the former `*Neu` dot types.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// The canonical full status capsule: an icon (or a dot when `systemImage`
/// is nil) plus a label, tinted by `color`. Replaces the former `BoardChip`
/// and the hand-rolled `*Neu` dot+label capsules.
struct StatusPill: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            } else {
                Circle()
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// A bare priority flag (no label). The condensed companion to `PriorityPill`.
struct PriorityFlag: View {
    let priority: WorkPriority

    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 10))
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch priority {
        case .p0: AppTheme.accentCoral
        case .p1: AppTheme.accentCoral.opacity(0.82)
        case .p2: AppTheme.accentOrange
        case .p3: AppTheme.textTertiary
        }
    }
}

// MARK: - Semantic pills (full capsule rendering)

struct WorkStatusPill: View {
    let state: WorkState

    var body: some View {
        StatusPill(label: state.title, systemImage: systemImage, tint: tint)
    }

    private var tint: Color {
        switch state {
        case .ready: AppTheme.accentCyan
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
        StatusPill(
            label: priority.title,
            systemImage: "flag.fill",
            tint: priority == .p0
                ? .red
                : priority == .p1 ? .orange : AppTheme.accentCyan
        )
    }
}

struct AgentHealthPill: View {
    let health: AgentHealthStatus

    var body: some View {
        StatusPill(label: health.title, systemImage: "waveform.path.ecg", tint: tint)
    }

    private var tint: Color {
        switch health {
        case .online: AppTheme.statusSuccess
        case .idle: AppTheme.accentCyan
        case .warning: AppTheme.accentOrange
        case .offline: .red
        }
    }
}

struct SessionStatusPill: View {
    let status: AgentSessionStatus

    var body: some View {
        StatusPill(label: status.title, systemImage: "bolt.circle.fill", tint: tint)
    }

    private var tint: Color {
        switch status {
        case .running: AppTheme.statusSuccess
        case .idle: AppTheme.accentCyan
        case .stopped: AppTheme.accentOrange
        case .error: .red
        }
    }
}

private extension StatusPill {
    init(label: String, systemImage: String?, tint: Color) {
        self.init(text: label, color: tint, systemImage: systemImage)
    }
}
