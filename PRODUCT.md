# Product

## Register

product

## Users

Solo developers and small teams running Hermes-driven coding agents (Claude Code, Codex CLI, OpenCode) across multiple repositories. They live in the terminal and this app simultaneously, juggling three activities at once: tracking work, communicating with agents, and reviewing agent output.

Their context when using AgentBoard: they have just spawned (or are about to spawn) a coding session, they need to triage GitHub issues or kanban tasks, and they want to chat with the Hermes gateway to steer an agent mid-run. They are power users who value speed, density, and keyboard-first flow. They do not need hand-holding; they need the tool to disappear into the task.

The job to be done: unify AI-assisted development workflow (work tracking, agent communication, session monitoring) into one native macOS/iOS surface, replacing the terminal/browser/CLI juggling that fragments attention today.

## Product Purpose

AgentBoard is a native SwiftUI workspace (macOS 26+ / iOS 26+) that gives one shared app core for chat, GitHub issue tracking, agent task/session monitoring, and companion-backed live state. It is the control plane for a Hermes-first agent fleet: the Hermes gateway powers chat and owns kanban writes, `~/.hermes/kanban.db` is the task source of truth, GitHub Issues are the external work stream, and the companion service owns live session state.

Success looks like: a user opens the app, immediately sees which agents are running and what they're working on, can triage and create work, can steer any agent via chat, and can inspect a live terminal for any session — without leaving the window or reaching for a browser. The interface earns trust by behaving like the native tools the user already uses, not by advertising itself.

## Brand Personality

Calm, dense, trustworthy. Three words: **native, competent, fast.**

The voice is matter-of-fact. No marketing exclamation points, no "Let's get started!" copy. Status is reported in facts: "3 running", "No active sessions", "Connect a GitHub token and repository in Settings." The interface treats the user as someone who knows what they're doing; it gets out of the way and shows the right thing at the right moment.

The emotional goal is **earned familiarity**: a user fluent in the category's best tools (Linear, Raycast) sits down, trusts the interface, and stays in flow. No pauses at subtly-off components, no questioning whether a control does what it looks like it does.

## Anti-references

- **Generic "AI dashboard" slop.** Dark navy backgrounds, neon accent glows, gradient text, hero-metric templates, identical card grids with icon+heading+text. The category-reflex output of "AI agent tool → dark blue neon." AgentBoard is a tool, not a pitch deck.
- **The retired beads prototype.** The old OpenClaw/beads/macOS-only UI used neumorphic double-shadows and skeuomorphic extruded/recessed surfaces (ADR-015 retired it). That look is explicitly off-limits; the active app uses native platform materials.
- **Web-app-in-a-window feel.** Custom scrollbars, non-native form controls, Electron-grade chrome. The app must read as a first-class macOS/iOS citizen — `NavigationSplitView`, `.inspector`, `.sidebar`, system materials, system accent.
- **Over-decoration.** Gratuitous motion, display fonts in labels, invented affordances for standard tasks. Product UI's failure mode is strangeness without purpose.

## Design Principles

1. **Native chrome, not custom chrome.** Surfaces, materials, controls, and motion come from the platform. The app looks like macOS/iOS, not like a bespoke design system fighting the OS. (ADR-015.)
2. **The tool disappears into the task.** The interface earns trust by behaving predictably, not by drawing attention to itself. Status semantics (color, pills, dots) carry meaning; decoration carries none.
3. **Density for power users.** Users are fluent and multitasking. Show the information they need without making them click for it, but never crowd a decision point. Progressive disclosure, not progressive withholding.
4. **Status is semantic, not decorative.** Kanban columns, work states, session states, and chat connection all map to a small, consistent vocabulary of colors and pills. Color means something; it is never garnish.
5. **Earned familiarity over surprise.** Standard navigation, standard affordances, consistent component vocabulary screen to screen. Delight is saved for moments, not pages. Familiarity is a feature.

## Accessibility & Inclusion

Standard platform accessibility: rely on macOS/iOS VoiceOver, Dynamic Type, and Reduce Motion. Accessibility identifiers are required on every interactive element (convention: `{screen}_{element}_{description}`). Status colors should remain distinguishable beyond hue alone (paired with icons or text labels) where feasible, but full WCAG 2.2 AA conformance is not a target — this is a developer tool with a known, fluent audience.
