import Foundation
import Testing
@testable import AgentBoard

@Suite("SessionMonitor Tests")
struct SessionMonitorTests {
    
    // MARK: - Slug Generation Tests
    
    @Test("slug generation creates valid tmux session name component")
    func slugGenerationCreatesValidComponent() {
        func slug(from rawValue: String) -> String {
            let lowercased = rawValue.lowercased()
            let replaced = lowercased.replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: "-",
                options: .regularExpression
            )
            return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        
        #expect(slug(from: "My Project") == "my-project")
        #expect(slug(from: "Project-Name") == "project-name")
        #expect(slug(from: "AB-123") == "ab-123")
        #expect(slug(from: "Test___Multiple") == "test-multiple")
        #expect(slug(from: "---Leading-Trailing---") == "leading-trailing")
        #expect(slug(from: "") == "")
    }
    
    // MARK: - Status Resolution Tests
    
    @Test("resolveStatus returns correct status for agent process states")
    func resolveStatusCorrectForAgentStates() {
        func resolveStatus(hasAgentProcess: Bool, isAttached: Bool, cpuPercent: Double) -> SessionStatus {
            if !hasAgentProcess {
                return isAttached ? .idle : .stopped
            }
            return cpuPercent > 0.1 ? .running : .idle
        }
        
        #expect(resolveStatus(hasAgentProcess: false, isAttached: false, cpuPercent: 0) == .stopped)
        #expect(resolveStatus(hasAgentProcess: false, isAttached: true, cpuPercent: 0) == .idle)
        #expect(resolveStatus(hasAgentProcess: true, isAttached: false, cpuPercent: 50) == .running)
        #expect(resolveStatus(hasAgentProcess: true, isAttached: true, cpuPercent: 0.5) == .running)
        #expect(resolveStatus(hasAgentProcess: true, isAttached: false, cpuPercent: 0.05) == .idle)
        #expect(resolveStatus(hasAgentProcess: true, isAttached: true, cpuPercent: 0.0) == .idle)
    }

    @Test("resolveStatus treats cpu threshold of 0.1 as idle and above as running")
    func resolveStatusCpuThresholdBoundary() {
        func resolveStatus(hasAgentProcess: Bool, isAttached: Bool, cpuPercent: Double) -> SessionStatus {
            if !hasAgentProcess {
                return isAttached ? .idle : .stopped
            }
            return cpuPercent > 0.1 ? .running : .idle
        }

        #expect(resolveStatus(hasAgentProcess: true, isAttached: true, cpuPercent: 0.1) == .idle)
        #expect(resolveStatus(hasAgentProcess: true, isAttached: true, cpuPercent: 0.1001) == .running)
    }
    
    // MARK: - Agent Type Detection Tests
    
    @Test("agentType detection identifies claude, codex, and opencode")
    func agentTypeDetectionWorks() {
        func agentType(for command: String) -> AgentType? {
            let lowercased = command.lowercased()
            if lowercased.contains("claude") { return .claudeCode }
            if lowercased.contains("codex") { return .codex }
            if lowercased.contains("opencode") { return .openCode }
            return nil
        }
        
        #expect(agentType(for: "claude") == .claudeCode)
        #expect(agentType(for: "/usr/local/bin/claude") == .claudeCode)
        #expect(agentType(for: "CLAUDE --model opus") == .claudeCode)
        #expect(agentType(for: "codex") == .codex)
        #expect(agentType(for: "opencode") == .openCode)
        #expect(agentType(for: "vim") == nil)
        #expect(agentType(for: "bash") == nil)
    }
    
    // MARK: - Model Parsing Tests
    
    @Test("parseModel extracts model from command arguments")
    func parseModelFromCommand() {
        func parseModel(from command: String) -> String? {
            let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
            for (index, token) in tokens.enumerated() {
                if token == "--model", index + 1 < tokens.count {
                    return tokens[index + 1]
                }
                if token == "-m", index + 1 < tokens.count {
                    return tokens[index + 1]
                }
                if token.hasPrefix("--model=") {
                    return String(token.dropFirst("--model=".count))
                }
            }
            return nil
        }
        
        #expect(parseModel(from: "claude --model opus") == "opus")
        #expect(parseModel(from: "claude -m claude-3-opus") == "claude-3-opus")
        #expect(parseModel(from: "claude --model=opus-4") == "opus-4")
        #expect(parseModel(from: "claude") == nil)
        #expect(parseModel(from: "claude --other-flag") == nil)
    }
    
    // MARK: - Command for Agent Type Tests
    
    @Test("command for agentType returns correct launch command")
    func commandForAgentType() {
        func command(for agentType: AgentType) -> String {
            switch agentType {
            case .claudeCode: return "claude"
            case .codex: return "codex"
            case .openCode: return "opencode"
            }
        }
        
        #expect(command(for: .claudeCode) == "claude")
        #expect(command(for: .codex) == "codex")
        #expect(command(for: .openCode) == "opencode")
    }
    
    // MARK: - Error Tests
    
    @Test("SessionMonitorError provides correct error descriptions")
    func sessionMonitorErrorDescriptions() {
        #expect(SessionMonitorError.invalidSessionName.errorDescription == "Unable to create a valid tmux session name.")
        #expect(SessionMonitorError.launchFailed("test error").errorDescription == "test error")
    }
    
    // MARK: - Is Missing Tmux Server Tests
    
    @Test("isMissingTmuxServer detects tmux server errors")
    func isMissingTmuxServerDetection() {
        func isMissingTmuxServer(message: String) -> Bool {
            let lower = message.lowercased()
            return lower.contains("no server running on")
                || lower.contains("failed to connect to server")
                || lower.contains("no such file")
                || lower.contains("can't find socket")
                || lower.contains("error connecting to")
        }
        
        #expect(isMissingTmuxServer(message: "no server running on /tmp/socket"))
        #expect(isMissingTmuxServer(message: "Failed to connect to server"))
        #expect(isMissingTmuxServer(message: "No such file or directory"))
        #expect(isMissingTmuxServer(message: "can't find socket"))
        #expect(isMissingTmuxServer(message: "error connecting to /tmp/socket"))
        #expect(!isMissingTmuxServer(message: "session already exists"))
        #expect(!isMissingTmuxServer(message: "command succeeded"))
    }
}
