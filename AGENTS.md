<!-- BEGIN COMPOUND CODEX TOOL MAP -->
## Compound Codex Tool Mapping (Claude Compatibility)

This section maps Claude Code plugin tool references to Codex behavior.
Only this block is managed automatically.

Tool mapping:
- Read: use shell reads (cat/sed) or rg
- Write: create files via shell redirection or apply_patch
- Edit/MultiEdit: use apply_patch
- Bash: use shell_command
- Grep: use rg (fallback: grep)
- Glob: use rg --files or find
- LS: use ls via shell_command
- WebFetch/WebSearch: use curl or Context7 for library docs
- AskUserQuestion/Question: ask the user in chat
- Task/Subagent/Parallel: run sequentially in main thread; use multi_tool_use.parallel for tool calls
- TodoWrite/TodoRead: use file-based todos in todos/ with file-todos skill
- Skill: open the referenced SKILL.md and follow it
- ExitPlanMode: ignore
<!-- END COMPOUND CODEX TOOL MAP -->


<claude-mem-context>
# Memory Context

# [recursing-saha-48fc39] recent context, 2026-04-16 11:43pm CDT

No previous sessions found.
</claude-mem-context>

--- project-doc ---

# Agent Instructions

This project uses **GitHub Issues** (`gh` CLI) for issue tracking. Repo: `jbcrane13/AgentBoard`.

## Agent Readiness

**Read `docs/agent-readiness/README.md` before starting any work session.**

It contains the current agent readiness score, conventions, key file locations, and quality gate commands. Treat it as the source of truth for active tooling rules.

Quick orientation:
- **Score as of 2026-02-28:** Level 2 → targeting Level 3
- **Lint:** `swiftlint lint --strict`
- **Test:** `xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Build macOS:** `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Build iOS:** `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Build companion:** `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardCompanion -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- **Regenerate xcodeproj after `project.yml` edits:** `xcodegen generate`

## Quick Reference

```bash
gh issue list --repo jbcrane13/AgentBoard --label "status:ready" --state open --json number,title,labels
gh issue edit <number> --repo jbcrane13/AgentBoard --add-label "status:in-progress" --remove-label "status:ready"
gh issue close <number> --repo jbcrane13/AgentBoard --comment "Done: <summary>"
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

1. **File issues for remaining work** if follow-up is needed
2. **Run quality gates** for any code changes
3. **Update issue status** when working against tracked issues
4. **Push to remote**
   ```bash
   git pull --rebase
   git push
   git status
   ```
5. **Clean up** stashes or temporary branches if you created them
6. **Verify** the branch is up to date with origin
7. **Hand off** any relevant context for the next session

Critical rules:
- Work is not complete until `git push` succeeds
- Never leave implementation changes stranded locally
- Never say "ready to push when you are"

## Active App Architecture

The active product is the Hermes-first SwiftUI rebuild.

### Targets

- `AgentBoard` — macOS app shell
- `AgentBoardMobile` — iOS app shell
- `AgentBoardUI` — shared SwiftUI views/components
- `AgentBoardCore` — shared stores, services, models, persistence
- `AgentBoardCompanionKit` — companion server/store implementation
- `AgentBoardCompanion` — companion executable
- `AgentBoardTests` — Swift Testing coverage for the shared stack

### Source of truth split

- Hermes gateway powers chat
- GitHub Issues power work tracking
- AgentBoard companion powers agent tasks, sessions, and live runtime state

### Networking requirement

Both app targets intentionally allow insecure development networking in their Info.plists because Hermes and the companion service may run on loopback or plain-HTTP LAN/Tailscale addresses during development.

### Project management

- `project.yml` is the source of truth
- Never edit `AgentBoard.xcodeproj/project.pbxproj` directly
- Run `xcodegen generate` after target, scheme, resource, or build-setting edits

## Historical Notes

The older OpenClaw/beads/macOS-only prototype has been removed from the active source tree. Historical documents such as `CLAUDE.md`, `DESIGN.md`, and `IMPLEMENTATION-PLAN.md` are archival context only.

## Activity — 2026-05-01
- 512d7cd Replace app icon with dark geometric design
- 48e6e35 Add Hermes agent signatures
- 70b4389 Potential fix for pull request finding
- 922f450 Potential fix for pull request finding
- ce1e150 ci: add jscpd duplicate code detection for Swift
