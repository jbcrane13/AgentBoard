# PRD: Ralph Loops Integration in AgentBoard

## Status: ✅ COMPLETE

## Context
AgentBoard currently supports launching standard agent sessions (Claude Code, Codex, OpenCode) in tmux. The new workflow uses Ralph loops (`ralphy` CLI) as the default execution pattern. Friend agent now monitors coding sessions. We need to:
1. Add Friend to the assignable agents list
2. Add a "Session Type" option: Standard vs Ralph Loop
3. Make Ralph Loop the default when launching from a ticket
4. Use the new tmux socket path `~/.tmux/sock`

## Tasks
- [x] Add Friend to AgentDefinition.knownAgents
- [x] Add Friend to ReadyQueueView agentGroups
- [x] Add SessionType enum (standard, ralphLoop) to CodingSession
- [x] Update NewSessionSheet with Session Type picker
- [x] Update SessionMonitor.launchSession to support ralph loop mode
- [x] Use `~/.tmux/sock` as primary socket, fall back to legacy `/tmp/openclaw-tmux-sockets/openclaw.sock`
- [x] Pre-select Ralph Loop when issueNumber is provided
- [x] Update command generation for ralph loop (use `ralphy --claude/--codex` with completion hook)
- [x] Run tests: `xcodebuild test -scheme AgentBoard -destination 'platform=macOS' -skip-testing:AgentBoardUITests`
- [x] Run linter: `swiftlint lint`

## Implementation Details
- **SessionType enum**: Added `SessionType` with `.standard` and `.ralphLoop` cases, including `displayName` property for UI
- **Completion hook**: Ralph loops now fire `openclaw system event --text 'Ralph loop <name> finished (exit $EXIT_CODE) in $(pwd)' --mode now` so Friend can monitor
- **Detection**: `detectSessionType()` checks for "ralphy" in command to classify existing sessions
- **Socket path**: `~/.tmux/sock` is now primary (survives macOS /tmp cleanup)

## Commit
`e946685` — feat: Add Ralph Loop session type and Friend agent support