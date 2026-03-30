#if os(iOS)
    import SwiftUI

    struct iOSBoardView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                ScrollView {
                    if let project = appState.selectedProject {
                        ProjectHeaderView(project: project)
                    }
                    BoardView()
                }
                .refreshable {
                    await appState.refreshBeads()
                }
                .navigationTitle("Board")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            appState.requestCreateBeadSheet()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("ios_board_button_add")
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        projectPicker
                    }
                }
            }
        }

        private var projectPicker: some View {
            Menu {
                ForEach(appState.projects) { project in
                    Button(project.name) {
                        appState.selectProject(project)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.selectedProject?.name ?? "Projects")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier("ios_board_menu_project")
        }
    }
#endif
