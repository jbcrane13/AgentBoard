#if os(iOS)
    import SwiftUI

    struct iOSMoreView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                List {
                    Section("Views") {
                        NavigationLink {
                            EpicsView()
                                .navigationTitle("Epics")
                        } label: {
                            Label("Epics", systemImage: "flag")
                        }
                        .accessibilityIdentifier("ios_more_link_epics")

                        NavigationLink {
                            MilestonesView()
                                .navigationTitle("Milestones")
                        } label: {
                            Label("Milestones", systemImage: "star")
                        }
                        .accessibilityIdentifier("ios_more_link_milestones")

                        NavigationLink {
                            ReadyQueueView()
                                .navigationTitle("Ready Queue")
                        } label: {
                            Label("Ready Queue", systemImage: "tray.full")
                        }
                        .accessibilityIdentifier("ios_more_link_ready")

                        NavigationLink {
                            NotesView()
                                .navigationTitle("Notes")
                        } label: {
                            Label("Notes", systemImage: "note.text")
                        }
                        .accessibilityIdentifier("ios_more_link_notes")

                        NavigationLink {
                            HistoryView()
                                .navigationTitle("History")
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        .accessibilityIdentifier("ios_more_link_history")

                        NavigationLink {
                            AllProjectsBoardView()
                                .navigationTitle("All Projects")
                        } label: {
                            Label("All Projects", systemImage: "rectangle.stack")
                        }
                        .accessibilityIdentifier("ios_more_link_all_projects")
                    }

                    Section("App") {
                        NavigationLink {
                            SettingsView()
                                .navigationTitle("Settings")
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        .accessibilityIdentifier("ios_more_link_settings")
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("More")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
#endif
