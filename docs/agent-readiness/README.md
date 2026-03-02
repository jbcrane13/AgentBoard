# Agent Readiness — AgentBoard

> **Read this before starting any work session.**

## Current Score

| Date | Level | Pass Rate | Sessions |
|------|-------|-----------|---------|
| 2026-02-28 | **Level 2** | 39.3% (22/56 non-skipped) | 01-initial-readiness |

---

## What Was Established

### Style & Validation
- **SwiftLint** — `.swiftlint.yml` at repo root. Run `swiftlint lint --strict`. Rules cover naming, complexity, file/function length, dead code detection via `unused_declaration` analyzer. SwiftLint also runs as a Xcode pre-build script (warns if not installed).
- **Strict concurrency** — `SWIFT_STRICT_CONCURRENCY = complete` in project.yml. All `actor`, `@MainActor`, `Sendable`, and `@unchecked Sendable` usages are intentional and must be preserved.

### Testing
- **Test framework** — Swift Testing (`@Test`, `@Suite`, `#expect`) + XCTest coexist. New tests should use Swift Testing.
- **Coverage enabled** — `gatherCoverageData: true` with `coverageTargets: [AgentBoard]` in project.yml scheme. Coverage is collected on every test run locally and in CI.
- **Coverage threshold** — CI enforces ≥ 30% line coverage on the `AgentBoard` target. Threshold lives in `.github/workflows/ci.yml`. Raise it as coverage improves.
- **UI tests must be skipped in headless contexts** — always pass `-skip-testing:AgentBoardUITests` in CI or automated runs. The `.factory/skills/run-tests/SKILL.md` skill documents this.
- **Test parallelism** — `parallelizable: true` and `randomExecutionOrder: true` are set in project.yml for both test targets.

### CI/CD
- **GitHub Actions** — `.github/workflows/ci.yml` runs on every push and PR to `main`. Steps: SwiftLint → Build → Test (unit only) → Coverage check → Upload xcresult.
- **Job name** — `build-and-test` (must match branch protection status check name exactly).
- **xcpretty** — used as optional formatter for build output (`|| true` guard so it does not break CI if not present on runner).

### Branch Protection
- **Main branch** — protected via GitHub ruleset `main-protection`. Requires: PR before merging, ≥ 1 approving review, passing `CI / build-and-test` status check, no direct pushes. Admins are not exempt.

### Architecture Documentation
- **docs/architecture.md** — service dependency graph (Mermaid flowchart), connection sequence diagram (Mermaid sequenceDiagram), data flows table, and canvas directive protocol. Update when adding new services or data flows.

---

## Key Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Primary agent instruction file. Read first. |
| `CLAUDE.md` | Phase history, gateway protocol, ATS invariants. |
| `project.yml` | XcodeGen source of truth. **Never edit pbxproj directly.** |
| `.swiftlint.yml` | Linting rules for the project. |
| `.github/workflows/ci.yml` | CI pipeline definition. |
| `docs/architecture.md` | Service flow and dependency diagrams. |
| `docs/agent-readiness/` | This directory — agent readiness tracking. |
| `.factory/skills/run-tests/SKILL.md` | Skill for running tests (skip UITests). |

---

## Quality Gate Commands

```bash
# Lint
swiftlint lint --strict

# Build
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' build

# Test (skip UITests for headless)
xcodebuild test -scheme AgentBoard -destination 'platform=macOS' \
  -skip-testing:AgentBoardUITests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Regenerate xcodeproj after editing project.yml
xcodegen generate
```

---

## Score History

| Session | Date | Level | Pass Rate | Key Change |
|---------|------|-------|-----------|------------|
| [01](./01-initial-readiness.md) | 2026-02-28 | Level 2 | 39.3% | Baseline evaluation + SwiftLint, CI, branch protection, coverage, architecture docs |

---

## How to Add a New Session Entry

1. Copy `SESSION-TEMPLATE.md` → `NN-description.md` (next sequential number).
2. Fill in all sections.
3. Update the Score History table above with the new row.
4. Commit with message: `docs: agent-readiness session NN — <brief description>`
