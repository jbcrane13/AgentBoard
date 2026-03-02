import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedProject: String = "All Projects"
    @State private var selectedEventType: EventTypeFilter = .all
    @State private var selectedDateRange: DateRangeFilter = .last30Days

    var body: some View {
        VStack(spacing: 10) {
            filterBar

            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "No History Events",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Try widening your filter range.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredEvents) { event in
                            historyRow(event)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Project", selection: $selectedProject) {
                Text("All Projects").tag("All Projects")
                ForEach(projectOptions, id: \.self) { project in
                    Text(project).tag(project)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)
            .accessibilityIdentifier("HistoryProjectPicker")

            Picker("Event", selection: $selectedEventType) {
                ForEach(EventTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .accessibilityIdentifier("HistoryEventPicker")

            Picker("Range", selection: $selectedDateRange) {
                ForEach(DateRangeFilter.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .accessibilityIdentifier("HistoryRangePicker")

            Spacer()
        }
    }

    private var projectOptions: [String] {
        Set(appState.historyEvents.compactMap(\.projectName)).sorted()
    }

    private var filteredEvents: [HistoryEvent] {
        appState.historyEvents.filter { event in
            let projectMatch = selectedProject == "All Projects" || event.projectName == selectedProject
            let typeMatch = selectedEventType.matches(event.type)
            let dateMatch = selectedDateRange.includes(event.occurredAt)
            return projectMatch && typeMatch && dateMatch
        }
    }

    private func historyRow(_ event: HistoryEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.type.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("HistoryEventTitle-\(event.id.uuidString)")
                    Text(event.occurredAt, format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(event.type.label)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                    if let projectName = event.projectName {
                        Text(projectName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if let beadID = event.beadID {
                        Text(beadID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if let details = event.details, !details.isEmpty {
                    Text(details)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }
}

private enum EventTypeFilter: String, CaseIterable {
    case all
    case bead
    case session
    case commit

    var label: String {
        switch self {
        case .all:
            return "All Events"
        case .bead:
            return "Bead Events"
        case .session:
            return "Session Events"
        case .commit:
            return "Commits"
        }
    }

    func matches(_ type: HistoryEventType) -> Bool {
        switch self {
        case .all:
            return true
        case .bead:
            return type == .beadCreated || type == .beadStatus
        case .session:
            return type == .sessionStarted || type == .sessionCompleted
        case .commit:
            return type == .commit
        }
    }
}

private enum DateRangeFilter: String, CaseIterable {
    case last24Hours
    case last7Days
    case last30Days
    case allTime

    var label: String {
        switch self {
        case .last24Hours:
            return "Last 24h"
        case .last7Days:
            return "Last 7d"
        case .last30Days:
            return "Last 30d"
        case .allTime:
            return "All Time"
        }
    }

    func includes(_ date: Date) -> Bool {
        switch self {
        case .allTime:
            return true
        case .last24Hours:
            return date >= Date().addingTimeInterval(-86_400)
        case .last7Days:
            return date >= Date().addingTimeInterval(-604_800)
        case .last30Days:
            return date >= Date().addingTimeInterval(-2_592_000)
        }
    }
}
