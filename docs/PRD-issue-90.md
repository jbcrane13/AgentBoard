# PRD: Cross-device session sync via companion server

## Issue
#90 in jbcrane13/agentboard
## Tasks
- [x] Implement Cross-device session sync via companion server
- [x] Handle edge cases and error states
- [x] Add accessibilityIdentifier to every interactive element
- [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"
