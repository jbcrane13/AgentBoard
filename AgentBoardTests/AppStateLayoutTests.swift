import Foundation
import Testing
@testable import AgentBoard

@Suite("AppState Layout")
@MainActor
struct AppStateLayoutTests {

    @Test("isFocusMode is true when both sidebar and board are hidden")
    func isFocusModeWhenBothHidden() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.sidebarVisible = false
        state.boardVisible = false
        #expect(state.isFocusMode == true)
    }

    @Test("isFocusMode is false when only one panel is hidden")
    func isFocusModeWhenOnlyOneHidden() {
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.sidebarVisible = false
        state.boardVisible = true
        #expect(state.isFocusMode == false)
    }

    @Test("toggleSidebar flips sidebarVisible and returns to original after two calls")
    func toggleSidebarFlipsVisibility() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        let original = state.sidebarVisible
        state.toggleSidebar()
        #expect(state.sidebarVisible == !original)
        state.toggleSidebar()
        #expect(state.sidebarVisible == original)
    }

    @Test("toggleBoard flips boardVisible and returns to original after two calls")
    func toggleBoardFlipsVisibility() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        let original = state.boardVisible
        state.toggleBoard()
        #expect(state.boardVisible == !original)
        state.toggleBoard()
        #expect(state.boardVisible == original)
    }

    @Test("toggleFocusMode hides both panels when starting from normal mode")
    func toggleFocusModeFromNormalToFocus() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.sidebarVisible = true
        state.boardVisible = true
        state.toggleFocusMode()
        #expect(state.sidebarVisible == false)
        #expect(state.boardVisible == false)
        #expect(state.isFocusMode == true)
    }

    @Test("toggleFocusMode restores both panels when starting from focus mode")
    func toggleFocusModeFromFocusToNormal() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        state.sidebarVisible = false
        state.boardVisible = false
        state.toggleFocusMode()
        #expect(state.sidebarVisible == true)
        #expect(state.boardVisible == true)
        #expect(state.isFocusMode == false)
    }

    @Test("persistLayoutState saves sidebarVisible inverse to UserDefaults")
    func persistLayoutStateSavesToUserDefaults() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }
        let _d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d, withIntermediateDirectories: true); let state = AppState(configStore: AppConfigStore(directory: _d))
        // Ensure sidebar is visible before toggling
        state.sidebarVisible = true
        state.toggleSidebar()
        // After toggle, sidebarVisible is false, so AB_sidebarCollapsed should be true
        let collapsed = UserDefaults.standard.bool(forKey: "AB_sidebarCollapsed")
        #expect(collapsed == !state.sidebarVisible)
    }

    @Test("sidebarVisible initializes from UserDefaults AB_sidebarCollapsed")
    func sidebarVisibleInitializesFromUserDefaults() {
        defer {
            UserDefaults.standard.removeObject(forKey: "AB_sidebarCollapsed")
            UserDefaults.standard.removeObject(forKey: "AB_boardCollapsed")
        }

        // Test 1: When AB_sidebarCollapsed is true, sidebarVisible should be false
        UserDefaults.standard.set(true, forKey: "AB_sidebarCollapsed")
        let _d1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d1, withIntermediateDirectories: true); let state1 = AppState(configStore: AppConfigStore(directory: _d1))
        #expect(state1.sidebarVisible == false)

        // Clean up and test 2: When AB_sidebarCollapsed is false, sidebarVisible should be true
        UserDefaults.standard.set(false, forKey: "AB_sidebarCollapsed")
        let _d2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: _d2, withIntermediateDirectories: true); let state2 = AppState(configStore: AppConfigStore(directory: _d2))
        #expect(state2.sidebarVisible == true)
    }
}
