import SwiftUI

struct ProjectListView: View {
    @Environment(AppState.self) private var appState
    let showHeader: Bool

    init(showHeader: Bool = true) {
        self.showHeader = showHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                sectionHeader("Projects")
            }

            ForEach(appState.projects) { project in
                projectRow(project)
            }
        }
        .padding(.horizontal, showHeader ? 12 : 2)
        .padding(.top, showHeader ? 16 : 2)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    private func projectRow(_ project: Project) -> some View {
        Button(action: {
            appState.selectedProject = project
        }) {
            HStack(spacing: 8) {
                Text(project.icon)
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)
                    .opacity(0.7)

                Text(project.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.878, green: 0.878, blue: 0.878))
                    .lineLimit(1)

                Spacer()

                Text("\(project.totalCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.selectedProject?.id == project.id
                          ? Color.white.opacity(0.12)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
