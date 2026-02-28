---
name: run-tests
description: Run AgentBoard tests. Skip UITests — they require a running app with human interaction. Unit tests run cleanly on macOS without special signing.
---

# Run Tests — AgentBoard

## Standard test run

```bash
xcodebuild test \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  -skip-testing:AgentBoardUITests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## ⚠️ Always skip UITests

```bash
# UITests require the running app + human interaction — always skip:
-skip-testing:AgentBoardUITests
```

## Notes
- Test framework: Swift Testing (`@Test`, `#expect`) + XCTest coexist
- MockURLProtocol: `AgentBoardTests/` 
- TestFixtures: `AgentBoardTests/TestFixtures/GatewayClient/`
