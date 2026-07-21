---
review_agents: [architecture-strategist, code-simplicity-reviewer]
plan_review_agents: [code-simplicity-reviewer]
---

# Review Context

- This is a shared SwiftUI app targeting macOS and iOS with Swift 6 strict concurrency.
- Preserve intentional actor isolation, `@MainActor`, and `Sendable` decisions.
- Prefer native platform controls and keep shared UI behavior coherent across both app targets.
- `project.yml` is the Xcode project source of truth; do not edit the generated project file directly.
- Keep changes minimal, architecture-aligned, and covered by Swift Testing where behavior changes.
