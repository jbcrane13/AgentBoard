# AgentBoard Current-State Design

Last updated: 2026-04-23

## Purpose

This document describes the Hermes-first AgentBoard rebuild as it exists in the repository today. It is not a proposal. It is a current-state design record that answers two questions:

1. What has actually been implemented?
2. What is still unfinished, partial, or intentionally deferred?

## Status Summary

The active product is now the new SwiftUI rebuild, not the old OpenClaw/beads app.

Implemented today:

- A shared SwiftUI architecture for macOS and iOS.
- A shared core module with feature-scoped stores.
- Hermes gateway chat with streaming replies.
- GitHub Issues as the work-item source.
- A separate companion service for agent tasks, sessions, and live events.
- SwiftData caching for local snapshots.
- Keychain-backed secret storage.
- Swift Testing coverage for the new shared core and companion storage.

Not fully implemented yet:

- Remote Hermes conversation history loading.
- Rich chat rendering and advanced chat controls.
- Full GitHub issue editing from the UI.
- Robust companion session discovery and control.
- End-to-end UI smoke automation.
- A few pieces promised in the rebuild plan that are only partially realized.

## Active Targets

The active targets defined in `project.yml` are:

- `AgentBoardCore` — shared framework for iOS and macOS.
- `AgentBoardCompanionKit` — macOS framework for the companion backend.
- `AgentBoard` — macOS SwiftUI app shell.
- `AgentBoardMobile` — iOS SwiftUI app shell.
- `AgentBoardCompanion` — macOS command-line companion service.
- `AgentBoardTests` — Swift Testing target for the new architecture.

Deployment targets are intentionally modern:

- macOS 26.0
- iOS 26.0

Strict Swift concurrency is enabled for the active targets.

## Architecture Overview

The rebuild is organized into four layers.

### 1. Platform shells

- `AgentBoard/` contains the macOS app shell.
- `AgentBoardMobile/` contains the iOS app shell.

These are intentionally thin. They host navigation and inject the shared `AgentBoardAppModel`.

### 2. Shared UI

- `AgentBoardUI/` contains shared screens, theme, and reusable components.

Current primary screens:

- `ChatScreen`
- `WorkScreen`
- `AgentsScreen`
- `SessionsScreen`
- `SettingsScreen`

### 3. Shared core

- `AgentBoardCore/` contains models, stores, services, and persistence.

Main stores:

- `ChatStore`
- `WorkStore`
- `AgentsStore`
- `SessionsStore`
- `SettingsStore`
- `AgentBoardAppModel` as the composition root

Main services:

- `HermesGatewayClient`
- `GitHubWorkService`
- `CompanionClient`

Persistence:

- `AgentBoardCache` uses SwiftData for local snapshots.
- `SettingsRepository` uses `UserDefaults` for non-secret settings and Keychain for secrets.

### 4. Companion backend

- `AgentBoardCompanion/` contains the executable entry point.
- `AgentBoardCompanionKit/` contains the HTTP server, SQLite store, and local probe logic.

The companion service owns runtime-oriented state:

- agent tasks
- detected sessions
- agent summaries
- live update events

## Source Of Truth Split

The new app is already split along the planned data boundaries:

- Hermes gateway is the source of truth for chat requests and model discovery.
- GitHub Issues are the source of truth for work items.
- The companion service is the source of truth for agent task state, session state, and live events.
- SwiftData is a local cache, not the canonical backend.

## What Is Implemented

## App Shells And Navigation

Implemented:

- macOS app shell built in SwiftUI.
- iOS app shell built in SwiftUI.
- Shared app model injected into both shells.
- Shared screen implementations reused across both platforms.

Current shape:

- iOS uses a tab-driven shell with navigation.
- macOS uses a desktop-oriented shell with sidebar/detail navigation.
- Platform differences are kept in the shell layer, not the shared core.

## Shared State Model

Implemented:

- Feature-scoped observable stores rather than a monolithic global app state.
- `AgentBoardAppModel.bootstrap()` wires settings, chat, work, agents, and sessions.
- Periodic refresh loop for work, agents, and sessions.
- Companion event subscription loop for live updates.

Implemented behavior:

- The app boots from persisted settings and cached data.
- The app reconnects to the companion event stream when it drops.
- The app can refresh all major surfaces after settings changes.

Still true:

- There is still a single app composition root (`AgentBoardAppModel`), but it composes smaller stores instead of owning all domain logic itself.

## Settings And Persistence

Implemented:

- Hermes URL, model, and API key persistence.
- GitHub token persistence.
- Configured repository list persistence.
- Companion URL, token, and refresh interval persistence.
- Keychain-backed storage for Hermes, GitHub, and companion secrets.
- SwiftData cache for:
  - chat conversations
  - chat messages
  - work items
  - agent tasks
  - sessions
  - agent summaries

What works today:

- The app restores cached state on launch.
- Secrets are stored separately from the non-secret settings snapshot.
- The app can operate from cached data before a refresh completes.

## Hermes Chat

Implemented in the core:

- Hermes endpoint configuration and validation.
- Health check via `GET /health`.
- Model discovery via `GET /v1/models`.
- Streaming chat via `POST /v1/chat/completions` with SSE-style `data:` parsing.
- Local conversation creation and selection.
- Streaming assistant message updates in place.
- Conversation snapshot persistence to SwiftData.

Implemented in the UI:

- Conversation rail for locally known conversations.
- Connection-state chip.
- Refresh actions for connection and model list.
- Compose box with prompt sending.
- Streaming status indicator in assistant bubbles.

Implemented user experience:

- A user can create a conversation.
- A user can send a prompt.
- Assistant output streams into the active conversation.
- The app remembers the conversation locally across launches.

## GitHub Work Surface

Implemented in the core:

- GitHub repository + token configuration.
- Issue fetch across multiple repositories.
- Pagination over GitHub issues.
- Pull request filtering.
- Mapping from GitHub Issue to `WorkItem`.
- Derived work status from labels and issue state.
- Derived priority from labels.
- Agent hint extraction from `agent:*` labels.
- Issue patching through GitHub API.

Implemented in the UI:

- Board and list layouts.
- Search across issue text and metadata.
- Status counts by column.
- Per-card status menu that round-trips to GitHub.

Implemented user experience:

- A configured repo list populates the work board.
- Issues appear as unified `WorkItem` cards across repositories.
- Status changes from the menu update both the UI and GitHub.

## Agents Surface

Implemented in the core:

- Companion-backed task fetch.
- Companion-backed agent summary fetch.
- Task creation via `AgentTaskDraft`.
- Task patching via `AgentTaskPatch`.
- Cache persistence for tasks and summaries.

Implemented in the UI:

- Agent summary cards.
- Task queue list.
- Create-task sheet linked to a GitHub work item.
- Status update menu on tasks.

Implemented user experience:

- A user can create a companion task tied to a GitHub issue.
- The app displays agent summaries and queued work together.
- Task status can be updated from the UI.

## Sessions Surface

Implemented in the core:

- Companion-backed session fetch.
- Cache persistence for sessions.
- Companion event handling for session refresh triggers.

Implemented in the UI:

- Session cards with status, source, model, linked task, linked work item, started time, and last seen time.

Implemented user experience:

- When the companion sees agent-like processes, they appear in the sessions view.
- Session updates flow into the app through refreshes and live event notifications.

## Companion Service

Implemented in the backend:

- Standalone Swift companion executable.
- TCP HTTP server built with `Network`.
- SQLite-backed persistence for tasks, sessions, and agents.
- REST endpoints for:
  - health
  - list tasks
  - create task
  - update task
  - list sessions
  - list agents
- Server-sent events stream for companion events.
- Periodic local probe refresh loop.

Implemented data model:

- `agent_tasks` table
- `sessions` table
- `agents` table

Implemented session discovery strategy:

- The local probe scans process lists with `ps`.
- It detects simple agent signatures such as `codex`, `claude`, `aider`, and `cursor`.
- It infers agent summaries and links sessions to tasks when possible.

## Tests And Verification

Implemented tests:

- Hermes client tests.
- Chat store tests.
- GitHub work-service tests.
- Companion SQLite store tests.

Verified locally during the rebuild:

- `xcodegen generate`
- `swiftlint lint --strict`
- macOS app tests
- iOS app build
- companion build

Current coverage gate status:

- `AgentBoardCore` is above the 30% threshold.
- `AgentBoardCompanionKit` is above the 30% threshold.

## What Is Unfinished

The rebuild is functional, but it is not complete against the full design goal. The biggest unfinished items are below.

## Hermes Chat Gaps

Not finished:

- `HermesGatewayClient.loadConversationHistory` is a stub and currently returns an empty array.
- Existing conversations are restored from local SwiftData cache only, not from a Hermes-backed remote history API.
- There is no remote conversation rename, delete, or sync flow.
- There is no model picker in the chat UI even though model discovery exists in the store.
- Chat messages render as plain text bubbles.

Missing chat polish:

- markdown rendering
- fenced code block styling
- attachments
- richer error recovery
- richer reconnect semantics than request-time retry and health refresh

## Work Surface Gaps

Not finished:

- The UI only exposes status changes.
- There is no UI yet for editing title, body, labels, assignees, or milestone.
- There is no issue detail screen.
- There are no repo-level filters beyond the shared search field.
- There is no create-issue flow.

Partially implemented:

- `GitHubWorkService` can patch more than status, but the UI does not expose those capabilities yet.

## Agents Surface Gaps

Not finished:

- Existing tasks do not have a dedicated edit form.
- There is no delete or archive flow for tasks.
- There is no drag/drop or board-style task planning surface.
- There is no explicit session-linking workflow in the UI.
- There is no agent assignment suggestion flow from `agent:*` labels.

## Sessions Surface Gaps

Not finished:

- Sessions are read-only.
- There is no session detail view.
- There is no log, console, transcript, or terminal output view.
- There are no controls to start, stop, nudge, or relaunch sessions.
- There is no first-class grouping by machine, project, agent, or repo.

## Companion Backend Gaps

Not finished:

- The companion currently uses REST + SSE only. The original rebuild plan allowed REST + SSE/WebSocket; WebSocket support is not implemented.
- Session discovery is heuristic process scanning, not a robust task-runtime integration.
- The local probe does not manage launches or supervise agent processes.
- The local probe can return empty snapshots when process inspection fails or no signatures match.
- There is no authentication handshake beyond an optional bearer token.
- There is no multi-machine federation or remote worker registration.
- There is no durable event log beyond the current SQLite tables.

## Platform And UX Gaps

Not finished:

- The app has a refreshed UI, but it is still version-one product polish.
- There are no dedicated UI smoke tests for the screens.
- There is no onboarding flow for first-run setup beyond the Settings screen.
- There is no built-in companion installer, launcher, or lifecycle management from the app shells.
- There is no offline conflict-resolution strategy beyond local cache replacement on refresh.

## Plan Deviations And Partial Realization

The current repo matches the rebuild plan in structure, but not every detail is complete.

Fully realized:

- SwiftUI-first shared architecture
- thin macOS and iOS shells
- feature-scoped stores
- SwiftData local cache
- Keychain secret storage
- Hermes/GitHub/companion source-of-truth split
- separate Swift companion service
- SQLite-backed companion persistence

Partially realized:

- Hermes conversation history exists locally but not remotely
- GitHub mutation support exists in the service layer but not fully in the UI
- live companion updates exist through SSE but not through WebSocket
- sessions exist as runtime objects but not as controllable runtime sessions
- tests cover core behavior but not full UI and end-to-end system behavior

Not yet realized:

- full remote chat history synchronization
- robust runtime/session orchestration
- richer issue and task editing surfaces
- production-grade onboarding and operational tooling

## Recommended Next Milestones

If work resumes from the current state, the highest-value follow-up milestones are:

1. Finish Hermes history and conversation synchronization.
2. Add issue detail and full GitHub editing flows.
3. Add task detail/edit flows and stronger work-to-agent linking.
4. Replace heuristic session discovery with a real runtime integration.
5. Add UI smoke coverage and end-to-end integration tests.

## Conclusion

The repository now contains a real Hermes-first SwiftUI rebuild with shared macOS/iOS code, a companion backend, modern persistence, and working end-to-end paths for chat, GitHub-backed work, agent tasks, and session visibility.

The remaining work is mostly in depth and productization, not in proving the architecture. The rebuild is no longer a prototype, but it is also not feature-complete relative to the full design target.
