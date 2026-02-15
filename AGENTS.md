# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Phase 1 Snapshot (2026-02-14)

- Epic `AgentBoard-qrw` and child tasks `AgentBoard-qrw.1` through `AgentBoard-qrw.5` are closed.
- `project.yml` is the source of truth for targets/schemes; regenerate project files with `xcodegen generate` after project config changes.
- `AgentBoardTests` exists with smoke tests, and `xcodebuild ... test` is now part of the required quality gate.
- UI shell decision: `NavigationSplitView` for sidebar/detail, with `HSplitView` for center + right panel.
- Layout baseline: default window `1280x820`, minimum `900x600`, sidebar fixed to `220`, center minimum `400`, right panel ideal `340`.
- Phase 1 board and canvas are intentionally placeholders (`BoardView` empty canonical columns, canvas shows `No content`).
