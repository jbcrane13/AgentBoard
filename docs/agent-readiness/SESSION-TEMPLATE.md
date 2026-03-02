# Session NN — Description

**Date:** YYYY-MM-DD  
**Agent:** [Droid / Claude Sonnet / Claude Opus / etc.]  
**Triggered by:** [Agent readiness action items / User request / Scheduled review]  
**Baseline score:** Level N (XX.X%)  
**Target:** Level N+1 (≥ XX%)

---

## Objective

_One sentence describing what this session set out to accomplish._

---

## Changes Made

### [Category, e.g. "Style & Validation"]

**File:** `path/to/file`  
**What changed:** _Describe the change._  
**Why:** _Link to action item or rationale._

### [Category]

_Repeat block for each change._

---

## Process / Workflow Updates

_Describe any changes to developer or agent workflow. Examples:_

- _New commands agents must run_
- _New hooks or CI steps_
- _Conventions agents must follow going forward_
- _Skills added or modified_

---

## Hooks & Automation

| Hook / Automation | File | Trigger | Action |
|-------------------|------|---------|--------|
| _e.g. SwiftLint pre-build_ | `.swiftlint.yml` + `project.yml` | Xcode build | Runs `swiftlint lint --strict`, warns if not installed |

---

## Skills Added / Modified

| Skill | File | Description |
|-------|------|-------------|
| _e.g. run-tests_ | `.factory/skills/run-tests/SKILL.md` | _What it does_ |

---

## Criteria Impact

| Criterion | Before | After | Change |
|-----------|--------|-------|--------|
| _e.g. lint_config_ | 0/1 | 1/1 | +1 |

**Net score change:** +N criteria → new pass rate XX.X% (Level N)

---

## Remaining Gaps (Top 5 by Impact)

1. **criterion-name** — _Why it matters, what needs to be done._
2. **criterion-name** — _Why it matters, what needs to be done._
3. **criterion-name** — _Why it matters, what needs to be done._
4. **criterion-name** — _Why it matters, what needs to be done._
5. **criterion-name** — _Why it matters, what needs to be done._

---

## Next Session Recommendation

_One paragraph: what a future agent should focus on, what prerequisites exist, what order to tackle gaps._

---

## Verification

```bash
# Commands run to verify changes work:
# (paste actual commands and output snippets)
```

_Build: PASS / FAIL_  
_Tests: PASS / FAIL (N passed, N failed)_  
_Lint: PASS / FAIL (N violations)_
