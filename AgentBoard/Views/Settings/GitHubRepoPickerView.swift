import SwiftUI

/// Fetches the authenticated user's GitHub repos and lets them pick which ones to add as projects.
struct GitHubRepoPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let token: String

    @State private var repos: [GitHubRepoInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedRepos: Set<String> = [] // "owner/repo" strings

    private var filteredRepos: [GitHubRepoInfo] {
        if searchText.isEmpty { return repos }
        return repos.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Repos already configured as projects
    private var existingRepoKeys: Set<String> {
        Set(appState.appConfig.projects.compactMap { project in
            guard let owner = project.githubOwner, let repo = project.githubRepo else { return nil }
            return "\(owner)/\(repo)"
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading repositories…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await fetchRepos() } }
                    }
                    .padding()
                } else {
                    List(filteredRepos) { repo in
                        let key = repo.fullName
                        let alreadyAdded = existingRepoKeys.contains(key)

                        Button {
                            if !alreadyAdded {
                                if selectedRepos.contains(key) {
                                    selectedRepos.remove(key)
                                } else {
                                    selectedRepos.insert(key)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedRepos.contains(key) ? "checkmark.circle.fill" :
                                    alreadyAdded ? "checkmark.circle" : "circle")
                                    .foregroundStyle(alreadyAdded ? .green :
                                        selectedRepos.contains(key) ? .blue : .secondary)
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.name)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(repo.fullName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    if let desc = repo.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if alreadyAdded {
                                    Text("Added")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.green.opacity(0.1), in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded)
                        .accessibilityIdentifier("github_repo_row_\(repo.name)")
                    }
                    .searchable(text: $searchText, prompt: "Filter repos…")
                }
            }
            .navigationTitle("GitHub Repos")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(!selectedRepos.isEmpty ? "(\(selectedRepos.count))" : "")") {
                            addSelectedRepos()
                            dismiss()
                        }
                        .disabled(selectedRepos.isEmpty)
                    }
                }
        }
        .task { await fetchRepos() }
    }

    private func fetchRepos() async {
        isLoading = true
        errorMessage = nil

        do {
            repos = try await GitHubRepoFetcher.fetchUserRepos(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func addSelectedRepos() {
        for key in selectedRepos {
            let parts = key.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repo = String(parts[1])

            // Use a synthetic path for GitHub-only projects (no local directory needed)
            let syntheticPath = "github://\(owner)/\(repo)"

            // Skip if already exists
            guard !appState.appConfig.projects.contains(where: { $0.path == syntheticPath }) else { continue }

            let project = ConfiguredProject(
                path: syntheticPath,
                icon: "📦",
                githubOwner: owner,
                githubRepo: repo
            )
            appState.appConfig.projects.append(project)
        }

        appState.persistConfig()
        appState.rebuildProjectsPublic()
    }
}

// MARK: - GitHub API Types & Fetcher

struct GitHubRepoInfo: Identifiable, Decodable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

enum GitHubRepoFetcher {
    static func fetchUserRepos(token: String) async throws -> [GitHubRepoInfo] {
        var allRepos: [GitHubRepoInfo] = []
        var page = 1

        while true {
            var request = URLRequest(
                url: URL(string: "https://api.github.com/user/repos?per_page=100&page=\(page)&sort=updated")!
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 401 {
                throw NSError(
                    domain: "GitHubAPI", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub token. Check Settings."]
                )
            }

            guard httpResponse.statusCode == 200 else {
                throw NSError(
                    domain: "GitHubAPI", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "GitHub API error: \(httpResponse.statusCode)"]
                )
            }

            let pageRepos = try JSONDecoder().decode([GitHubRepoInfo].self, from: data)
            allRepos.append(contentsOf: pageRepos)

            if pageRepos.count < 100 { break }
            page += 1
        }

        return allRepos
    }
}
