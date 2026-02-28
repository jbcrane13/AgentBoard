---
name: run-tests
description: Run AgentBoard tests. Unit tests run locally. UI tests run on the build machine (mac-mini) which has a display session — never skip UITests permanently without escalating to Blake.
---

# Run Tests — AgentBoard

## Unit tests (run anywhere)

```bash
xcodebuild test \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  -skip-testing:AgentBoardUITests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## UI tests (build machine only — requires display session)

UI tests use fixture data (`--uitesting-dashboard-fixtures`) — no real agents needed.
Must run on mac-mini (Blake's Mac mini) which has a monitor attached.

```bash
ssh mac-mini "cd ~/Projects/AgentBoard && xcodebuild test \
  -scheme AgentBoard \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AgentBoardUITests \
  -derivedDataPath /tmp/ab-dd \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=YES"
```

## ⚠️ Policy — never skip UITests permanently

UI tests prove the user interaction contract. If a run is blocked:
1. Diagnose the cause (display session, signing, environment)
2. Notify Blake with details
3. Use `-skip-testing:AgentBoardUITests` only as a TEMPORARY workaround while the blocker is being resolved

**Known intentional skips (legitimate):**
- `NewSessionOutcomeTests` — skipped due to system notification interruptions in shared environments. Requires dedicated display + Do Not Disturb.

## Notes
- Launch args: `--uitesting`, `--disable-animations`, `--uitesting-dashboard-fixtures`
- MockURLProtocol: `AgentBoardTests/`
- TestFixtures: `AgentBoardTests/TestFixtures/GatewayClient/`
