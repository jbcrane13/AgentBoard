import Foundation
@testable import AgentBoard

/// Creates an AppState backed by a temp config directory that never touches ~/.agentboard/
@MainActor
func makeTestAppState() -> (AppState, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ABTest-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let store = AppConfigStore(directory: dir)
    let state = AppState(configStore: store)
    return (state, dir)
}
