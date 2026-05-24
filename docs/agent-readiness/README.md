# Agent Readiness — AgentBoard

> **Read this before starting any work session.**

## Current Score

| Date | Level | Pass Rate | Sessions |
|------|-------|-----------|---------|
| 2026-05-01 | **Level 2** | 41.1% (23/56 non-skipped) | 01-initial-readiness, 02-duplicate-code-detection |
| 2026-02-28 | **Level 2** | 39.3% (22/56 non-skipped) | 01-initial-readiness |

## What Was Established

### Style and validation

- **SwiftLint** — `.swiftlint.yml` at repo root. Run `swiftlint lint --strict`.
- **Strict concurrency** — `SWIFT_STRICT_CONCURRENCY = complete` in `project.yml`. Preserve intentional `actor`, `@MainActor`, and `Sendable` decisions.
- **Project generation** — `project.yml` is the source of truth. Regenerate `AgentBoard.xcodeproj` with `xcodegen generate` after project edits.

### Testing

- **Test framework** — Swift Testing is the default for new tests.
- **Active test target** — `AgentBoardTests` covers `AgentBoardCore` and `AgentBoardCompanionKit`.
- **Coverage enabled** — the `AgentBoard` scheme gathers coverage for `AgentBoardCore` and `AgentBoardCompanionKit`.
- **Coverage threshold** — CI enforces ≥ 30% line coverage on `AgentBoardCore`.

### CI/CD

- **Workflow** — `.github/workflows/ci.yml`
- **Job** — `build-and-test`
- **Runner** — macOS 26
- **Checks** — SwiftLint strict, macOS build, macOS tests, iOS build, companion build, coverage threshold

## Key Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Primary agent instruction file |
| `project.yml` | XcodeGen source of truth |
| `.swiftlint.yml` | Lint configuration |
| `.github/workflows/ci.yml` | CI pipeline definition |
| `docs/architecture.md` | Current service and data-flow architecture |
| `docs/ADR.md` | Architecture decisions, including the Hermes-first rebuild |
| `.factory/skills/run-tests/SKILL.md` | Canonical local test workflow |

## Quality Gate Commands

```bash
# Lint
swiftlint lint --strict

# Regenerate the project after project.yml edits
xcodegen generate

# Build macOS app
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Test shared core + companion kit
xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build iOS app
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardMobile \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build companion tool
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardCompanion \
  -destination 'platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Score History

| Session | Date | Level | Pass Rate | Key Change |
|---------|------|-------|-----------|------------|
| [01](./01-initial-readiness.md) | 2026-02-28 | Level 2 | 39.3% | Baseline evaluation + SwiftLint, CI, branch protection, coverage, architecture docs |
| [02](./02-duplicate-code-detection.md) | 2026-05-01 | Level 2 | 41.1% | Added jscpd duplicate code detection (Swift) wired into CI |

## How To Add A New Session Entry

1. Copy `SESSION-TEMPLATE.md` to `NN-description.md` with the next sequential number.
2. Fill in all sections.
3. Update the Score History table above.
4. Commit with `docs: agent-readiness session NN — <brief description>`.
