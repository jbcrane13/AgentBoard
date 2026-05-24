# AgentBoard Product Requirements

Last updated: 2026-04-24

## Product Summary

AgentBoard is a Hermes-first SwiftUI app for Apple platforms that brings together:

- chat with a Hermes gateway
- GitHub Issues-backed work tracking
- companion-managed agent tasks and session visibility

The product direction is a modern shared app for macOS and iOS, not a continuation of the older pre-rewrite OpenClaw/beads desktop app.

## Product Goals

AgentBoard should let one person manage agent-assisted software work from a single app by making these workflows feel connected:

- talk to agents
- track work items
- assign and monitor execution work
- observe live session state

## Target Platforms

- macOS 26+
- iOS 26+

## Product Principles

- SwiftUI-first on both platforms
- one shared core with thin platform shells
- current Apple frameworks and strict Swift concurrency
- explicit backend boundaries instead of a monolithic app state
- local caching for resilience, but clear remote sources of truth

## Core Product Areas

## 1. Chat

Users can chat with Hermes through a modern conversation interface.

Requirements:

- configure Hermes gateway URL, auth, and preferred model
- send prompts and stream assistant responses in place
- expose connection and refresh state
- keep local conversation snapshots for quick restore
- support multiple conversations
- support all agent profiles 

## 2. Work

GitHub Issues are the canonical work source.

Requirements:

- connect one or more GitHub repositories
- load issues across configured repositories
- represent them as normalized work items
- show work as a board and as a list
- allow status changes to round-trip back to GitHub
- ability to auth to GHG account in settings
- -ability to select which projects to display in main ui
- Board with 

## 3. Agent Tasks

Agent tasks are execution-state objects layered on top of GitHub work.

Requirements:

- create a task from a work item
- assign a task to an agent
- track task status and priority
- link a task back to a GitHub issue
- group tasks alongside agent summaries

## 4. Sessions

Sessions represent live or recently seen execution state from the companion service.

Requirements:

- display active and recent sessions
- show session status, timestamps, and linked task or work context
- refresh from live companion updates

## 5. Settings

Configuration is modular rather than global.

Requirements:

- independently configure Hermes, GitHub, and companion endpoints
- persist non-secret settings locally
- store secrets in Keychain
- expose refresh and reconnect flows after settings changes

## Architecture Requirements

- two thin app shells over a shared core
- shared core owns models, stores, services, and local persistence
- companion runs as a separate Swift service
- source-of-truth split:
  - Hermes for chat
  - GitHub for work
  - companion for tasks, sessions, and live events

## Technical Requirements

- SwiftUI
- Observation
- Swift Concurrency
- SwiftData for local cache
- Keychain for secrets
- OSLog for structured logging
- Swift Testing for new tests

## Non-Goals

These are not part of the active rewrite target:

- reviving the old beads-backed board model
- reviving OpenClaw-specific chat/session flows
- terminal-capture-first client UX
- legacy canvas-heavy desktop workflows as a required v1 feature
- older OS compatibility layers

## Acceptance Direction

The rewrite should be considered directionally successful when:

- macOS and iOS share the same core product model
- chat, work, tasks, sessions, and settings all function from the new architecture
- active docs describe the current rewrite rather than the removed legacy app

For shipped status and open gaps, see `docs/implementation-status.md`.
