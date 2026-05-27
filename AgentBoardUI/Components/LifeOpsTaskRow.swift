import AgentBoardCore
import SwiftUI

struct LifeOpsTaskRow: View {
    let task: LifeTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LifeOpsPriorityBadge(priority: task.priority)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NeuPalette.textPrimary)
                        .lineLimit(2)

                    if task.isSarahOriginated {
                        Label("Sarah", systemImage: "message.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NeuPalette.accentOrange)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                }

                Text(task.nextAction)
                    .font(.caption)
                    .foregroundStyle(NeuPalette.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    metadataPill(task.category.title, systemImage: "tag")

                    if let source = task.source {
                        metadataPill(source.displayName, systemImage: sourceIcon(for: source.sourceType))
                    }

                    if let dueAt = task.dueAt {
                        metadataPill(dueAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    }

                    if task.owner != .blake || task.assignee != .blake {
                        metadataPill("\(task.owner.displayName) -> \(task.assignee.displayName)", systemImage: "person.2")
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(NeuPalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NeuPalette.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lifeops.task.row")
    }

    private func metadataPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(NeuPalette.textTertiary)
            .labelStyle(.titleAndIcon)
    }

    private func sourceIcon(for type: LifeSourceType) -> String {
        switch type {
        case .email: "envelope"
        case .calendar: "calendar"
        case .message: "message"
        case .manual: "square.and.pencil"
        case .chat: "bubble.left.and.bubble.right"
        case .jobSearch: "briefcase"
        case .family: "person.2"
        }
    }
}
