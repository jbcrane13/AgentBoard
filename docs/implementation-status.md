# AgentBoard Implementation Status

Last updated: 2026-04-24

This document tracks what the Hermes-first rewrite currently has, what is only partial, and what remains unfinished.

## Implemented

## Documentation structure

- Active rewrite documentation now lives in:
  - `docs/PRD.md`
  - `docs/implementation-status.md`
  - `docs/architecture.md`
  - `docs/ADR.md`
- Pre-rewrite documentation has been moved under `docs/archive/pre-rewrite/`.

## Active architecture

- The active documented direction is a Hermes-first SwiftUI rebuild.
- Active architecture decisions for the rewrite are recorded in `docs/ADR.md`.
- The active system structure and runtime flow are recorded in `docs/architecture.md`.

## Product surfaces defined as active

These areas are part of the active rewrite scope:

- Chat
- Work
- Agent Tasks
- Sessions
- Settings

## Platform direction

- macOS 26+ only
- iOS 26+ only
- SwiftUI-first approach on both platforms
- latest Apple framework stack by default

## Implemented Feature Areas

## Chat

- Hermes gateway is the active chat backend.
- The documented product shape includes:
  - connection state
  - streaming replies
  - multiple conversations
  - local conversation snapshots

## Work

- GitHub Issues are the documented source of truth for work.
- The documented product shape includes:
  - multi-repo issue loading
  - normalized work items
  - board and list presentation
  - status updates flowing back to GitHub

## Agent Tasks

- Agent tasks are defined as companion-managed execution objects.
- The documented product shape includes:
  - task creation from work items
  - agent assignment
  - status and priority tracking
  - linkage back to GitHub work

## Sessions

- Sessions are defined as companion-owned runtime visibility.
- The documented product shape includes:
  - active and recent session display
  - session metadata
  - live-update refresh model

## Settings And Persistence

- The documented rewrite expects:
  - separate Hermes, GitHub, and companion configuration
  - local persistence for non-secret settings
  - Keychain storage for secrets
  - SwiftData-backed local cache

## Partial

## Product definition

- The PRD now exists as `docs/PRD.md`, but it is intentionally concise and product-oriented.
- Detailed system shape remains in `docs/architecture.md` and `docs/ADR.md` rather than being repeated in the PRD.

## Current-state tracking

- This file is now the implementation ledger, but it is documentation-only.
- It reflects the active rewrite direction and known gaps from the current design pass.

## Feature maturity

- The product areas are defined clearly enough to guide implementation work.
- The architecture, ADRs, and status doc now agree on the rewrite direction.
- The status doc is separated from the PRD so product intent and delivery status no longer compete in one file.

## Unfinished

## Product and implementation gaps still called out by the active docs

- Remote Hermes conversation history is not treated as complete.
- Richer chat rendering and advanced chat controls are not treated as complete.
- Full GitHub issue editing from the UI is not treated as complete.
- Session control and deep session detail workflows are not treated as complete.
- Companion session discovery is not treated as production-complete.
- End-to-end UI smoke coverage is not treated as complete.

## Area-by-area unfinished work

## Chat gaps

- Remote conversation history loading is still an open item.
- Richer rendering for markdown, code blocks, and attachments is still an open item.
- More complete reconnect and sync behavior is still an open item.

## Work gaps

- Full issue editing beyond status is still an open item.
- Dedicated issue detail and richer filtering are still open items.

## Agent task gaps

- Rich task editing flows are still an open item.
- Better session-linking and agent-assignment workflows are still open items.

## Session gaps

- Session controls remain an open item.
- Deeper session detail views remain an open item.
- Rich logs or transcript UX remain an open item.

## Companion gaps

- Companion runtime discovery is still treated as heuristic rather than production-grade.
- More robust runtime orchestration and operational tooling remain open.

## Quality gaps

- End-to-end UI smoke coverage remains open.
- There is still follow-up consistency work between active docs and the wider repository tree.

## Repo consistency work still needed

- Some older code and build-tree artifacts still exist in the repository even though the active docs now point at the rewrite direction.
- The active docs are now separated cleanly, but the repository still needs a future pass if we want file layout, targets, and docs to line up perfectly everywhere.

## Canonical Usage

- Use `docs/PRD.md` for product intent and scope.
- Use `docs/implementation-status.md` for implemented versus unfinished status.
- Use `docs/architecture.md` for structure and data flow.
- Use `docs/ADR.md` for major rewrite decisions.
