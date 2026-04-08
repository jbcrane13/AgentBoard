# PRD: Ralph Loops Integration in AgentBoard

## Context
AgentBoard currently supports launching standard agent sessions (Claude Code, Codex, OpenCode) in tmux. The new workflow uses Ralph loops (`ralphy` CLI) as the default execution pattern. Friend agent now monitors coding sessions. We need to:
1. Add Friend to the assignable agents list
2. Add a "Session Type" option: Standard vs Ralph Loop
3. Make Ralph Loop the default when launching from a ticket
4. Use the new tmux socket path `~/.tmux/sock`

## Tasks
- [ ] Add Friend to AgentDefinition.knownAgents
- [ ] Add Friend to ReadyQueueView agentGroups
- [ ] Add SessionType enum (standard, ralphLoop) to CodingSession
- [ ] Update NewSessionSheet with Session Type picker
- [ ] Update SessionMonitor.launchSession to support ralph loop mode
- [ ] Use `~/.tmux/sock` as primary socket, fall back to legacy `/tmp/openclaw-tmux-sockets/openclaw.sock`
- [ ] Pre-select Ralph Loop when issueNumber is provided
- [ ] Update command generation for ralph loop (use `ralphy --claude/--codex` with completion hook)
- [ ] Run tests: `xcodebuild test -scheme AgentBoard -destination 'platform=macOS' -skip-testing:AgentBoardUITests`
- [ ] Run linter: `swiftlint lint`

## Constraints
- Don't break existing standard session functionality
- Socket path should be configurable but default to `~/.tmux/sock`
- Ralph loop sessions should still be identifiable by agent type (claude/codex)
- Completion hook format: `EXIT_CODE=$?; echo EXITED: $EXIT_CODE; openclaw system event --text 'Ralph loop <name> finished (exit $EXIT_CODE) in $(pwd)' --mode now; sleep 999999`