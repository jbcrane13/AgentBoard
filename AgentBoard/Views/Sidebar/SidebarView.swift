import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var projectsExpanded = true
    @State private var sessionsExpanded = true
    @State private var viewsExpanded = true
    @State private var showingNewSessionSheet = false
    @State private var handledNewSessionRequestID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    section(
                        title: "Projects",
                        isExpanded: $projectsExpanded
                    ) {
                        ProjectListView(showHeader: false)
                    }

                    section(
                        title: "Sessions",
                        isExpanded: $sessionsExpanded
                    ) {
                        SessionListView(showHeader: false)
                    }

                    section(
                        title: "Views",
                        isExpanded: $viewsExpanded
                    ) {
                        ViewsNavView(showHeader: false)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }

            Spacer()

            newSessionButton
        }
        .frame(minWidth: 220, idealWidth: 220, maxWidth: 220)
        .background(AppTheme.sidebarBackground)
        .onAppear {
            handleNewSessionRequestIfNeeded()
        }
        .onChange(of: appState.newSessionSheetRequestID) { _, _ in
            handleNewSessionRequestIfNeeded()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
        }
    }

    private var newSessionButton: some View {
        Button {
            showingNewSessionSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("New Session")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }

    private func section<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content()
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(AppTheme.sidebarMutedText)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .padding(.horizontal, 2)
        .tint(AppTheme.sidebarMutedText)
    }

    private func handleNewSessionRequestIfNeeded() {
        guard appState.newSessionSheetRequestID != handledNewSessionRequestID else { return }
        handledNewSessionRequestID = appState.newSessionSheetRequestID
        showingNewSessionSheet = true
    }
}
