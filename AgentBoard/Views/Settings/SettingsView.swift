import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var gatewayURL = ""
    @State private var token = ""
    @State private var showingProjectImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Projects")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appState.projects) { project in
                        HStack(spacing: 10) {
                            Text(project.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(project.path.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button("Remove") {
                                appState.removeProject(project)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        .padding(10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        showingProjectImporter = true
                    } label: {
                        Label("Add Project", systemImage: "plus")
                    }
                }

                sectionTitle("OpenClaw")

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Gateway URL", text: $gatewayURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Gateway Token", text: $token)
                        .textFieldStyle(.roundedBorder)

                    Button("Save OpenClaw Settings") {
                        appState.updateOpenClaw(gatewayURL: gatewayURL, token: token)
                    }
                }

                if let status = appState.statusMessage {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            gatewayURL = appState.appConfig.openClawGatewayURL ?? ""
            token = appState.appConfig.openClawToken ?? ""
        }
        .fileImporter(
            isPresented: $showingProjectImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.addProject(at: url)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
    }
}
