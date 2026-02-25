import SwiftUI

struct NotesView: View {
    @Environment(AppState.self) private var appState

    private var service: WorkspaceNotesService {
        appState.notesService
    }

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(service.selectedDate)
    }

    private var formattedDate: String {
        displayFormatter.string(from: service.selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dateNavBar
                dailyNotesSection
                knowledgeGraphSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Date Navigation

    private var dateNavBar: some View {
        HStack(spacing: 12) {
            Button {
                service.goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)

            Text(formattedDate)
                .font(.system(size: 15, weight: .semibold))

            Button {
                service.goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .opacity(isToday ? 0.4 : 1.0)
            .disabled(isToday)

            Spacer()

            if !isToday {
                Button("Today") {
                    service.goToToday()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Daily Notes

    private var dailyNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Notes")
                .font(.system(size: 18, weight: .semibold))

            if service.dailyNotes.isEmpty {
                HStack {
                    Spacer()
                    Text("No notes for \(formattedDate)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
            } else {
                notesContent
            }
        }
    }

    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let attributed = try? AttributedString(
                markdown: service.dailyNotes,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(service.dailyNotes)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - Knowledge Graph

    private var knowledgeGraphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Knowledge Graph")
                .font(.system(size: 18, weight: .semibold))

            if service.ontologyEntries.isEmpty {
                HStack {
                    Spacer()
                    Text("No knowledge graph entries for this day")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )
            } else {
                ontologyGroupedEntries
            }
        }
    }

    private var ontologyGroupedEntries: some View {
        let grouped = Dictionary(grouping: service.ontologyEntries, by: \.type)
        let order = ["Decision", "Lesson", "Bug"]

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(order, id: \.self) { type in
                if let entries = grouped[type], !entries.isEmpty {
                    ontologyGroup(type: type, entries: entries)
                }
            }
        }
    }

    private func ontologyGroup(type: String, entries: [OntologyDayEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(type)s")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(entries) { entry in
                    ontologyRow(entry)
                }
            }
        }
    }

    private func ontologyRow(_ entry: OntologyDayEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            typeBadge(entry.type)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !entry.summary.isEmpty && entry.summary != entry.title {
                    Text(entry.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let status = entry.status, !status.isEmpty {
                statusBadge(status)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    private func typeBadge(_ type: String) -> some View {
        Text(type)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(typeColor(type), in: Capsule())
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Decision": return .blue
        case "Lesson": return .purple
        case "Bug": return .orange
        default: return .gray
        }
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(statusColor(status), in: Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "resolved", "closed", "done": return .green
        case "open", "active": return .orange
        default: return .gray
        }
    }
}
