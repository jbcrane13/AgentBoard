#if os(iOS)
    import SwiftUI

    struct iOSAgentsView: View {
        @Environment(AppState.self) private var appState

        var body: some View {
            NavigationStack {
                AgentsView()
                    .navigationTitle("Agents")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
#endif
