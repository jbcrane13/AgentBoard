---
name: run-tests
description: Run the active AgentBoard build and test gates for the Hermes-first SwiftUI app family.
---

# Run Tests — AgentBoard

## Shared-core tests

```bash
xcodebuild test \
  -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## macOS build

```bash
xcodebuild build \
  -project AgentBoard.xcodeproj \
  -scheme AgentBoard \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## iOS build

```bash
xcodebuild build \
  -project AgentBoard.xcodeproj \
  -scheme AgentBoardMobile \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Companion build

```bash
xcodebuild build \
  -project AgentBoard.xcodeproj \
  -scheme AgentBoardCompanion \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Notes

- Run `xcodegen generate` first if `project.yml` changed.
- `swiftlint lint --strict` is part of the quality gate for code changes.
- The retired UI test bundle and old OpenClaw/beads test paths are no longer part of the active app.
