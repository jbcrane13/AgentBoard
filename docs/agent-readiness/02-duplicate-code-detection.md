# Session 02 — Duplicate Code Detection

**Date:** 2026-05-01
**Agent:** Droid (Claude Opus 4.7)
**Triggered by:** Agent readiness signal: `duplicate_code_detection` (0/1)
**Baseline score:** Level 2 (39.3%)
**Target:** Level 2 (40.0%+) — single criterion fix

---

## Objective

Add tooling to detect copy-paste / duplicated Swift code across the
AgentBoard SwiftUI app family and enforce DRY principles in CI.

---

## Changes Made

### Tooling

**File:** `.jscpd.json`
**What changed:** Added a `jscpd` configuration tuned for Swift sources:
`minTokens: 75`, `minLines: 8`, `format: ["swift"]`, ignore patterns for
`build/`, `DerivedData/`, generated files, the Xcode project bundle, and
test fixtures/mocks. Threshold set to `3%` duplication
(current baseline is `1.32%`, leaving safe headroom while still catching
new duplication).
**Why:** Establishes a deterministic, fast (<1s) duplicate detection pass
with a Swift-aware tokenizer. `jscpd` is the most widely used CPD tool
that natively supports Swift; PMD CPD requires Java and lacks first-class
Swift support.

### CI

**File:** `.github/workflows/ci.yml`
**What changed:** Added `Setup Node`, `Duplicate Code Detection (jscpd)`,
and an `Upload jscpd Report` step to the `build-and-test` job. The job
runs `npx jscpd@4.0.5 --config .jscpd.json` against every Swift target
directory and uploads the HTML+JSON report as an artifact.
**Why:** Wires the new check into the existing PR pipeline so
duplications above 3% fail the build and reviewers can inspect the
report on every PR.

### Hygiene

**File:** `.gitignore`
**What changed:** Added `reports/` and `.jscpd-report/` so locally
generated jscpd output never gets committed.

---

## Process / Workflow Updates

- New local command for agents and developers:
  ```bash
  npx --yes jscpd@4.0.5 --config .jscpd.json AgentBoardCore AgentBoardUI \
    AgentBoardCompanionKit AgentBoardMobile AgentBoardCompanion \
    AgentBoard AgentBoardTests
  ```
- The jscpd step runs after SwiftLint and before the macOS build in CI.
- HTML report is uploaded as the `jscpd-report` artifact on every run.

---

## Hooks & Automation

| Hook / Automation | File | Trigger | Action |
|-------------------|------|---------|--------|
| jscpd CI gate | `.github/workflows/ci.yml` | PR / push to `main` | Fails if Swift duplication exceeds 3% |
| jscpd config | `.jscpd.json` | Local + CI invocation | Defines tokens, line, ignore, threshold settings |

---

## Skills Added / Modified

_None._

---

## Criteria Impact

| Criterion | Before | After | Change |
|-----------|--------|-------|--------|
| `duplicate_code_detection` | 0/1 | 1/1 | +1 |

**Net score change:** +1 criterion.

---

## Remaining Gaps (Top 5 by Impact)

1. **dead_code_detection** — Add periphery or similar to detect unused
   Swift symbols in CI.
2. **deps_pinned** — Pin Homebrew SwiftLint/SwiftFormat versions used in
   CI for reproducibility.
3. **automated_pr_review** — No automated PR review droid is currently
   wired up; consider adding Factory PR review.
4. **secret_scanning** — No `gitleaks`/`trufflehog` workflow yet.
5. **distributed_tracing / metrics_collection** — No runtime
   observability for the companion service.

---

## Next Session Recommendation

Tackle `dead_code_detection` next — periphery integrates cleanly with the
existing XcodeGen + xcodebuild flow and complements jscpd for keeping the
codebase lean. Pair that work with pinning brew toolchain versions in
`ci.yml` to harden reproducibility.

---

## Verification

```bash
$ npx --yes jscpd@4.0.5 --config .jscpd.json AgentBoardCore AgentBoardUI \
    AgentBoardCompanionKit AgentBoardMobile AgentBoardCompanion \
    AgentBoard AgentBoardTests
# ...
# │ swift  │ 76             │ 17742 │ 157386 │ 9 │ 234 (1.32%) │ 2125 (1.35%) │
# Found 9 clones.
# Detection time:: ~1s
```

Baseline duplication: **1.32%** (below the 3% threshold) → exit code `0`.

_Build: not re-run (no Swift sources changed)_
_Tests: not re-run (no Swift sources changed)_
_Lint: not re-run (no Swift sources changed)_
