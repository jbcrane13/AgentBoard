# PRD: Desktop app: Cannot change session or agent profile from picker above chat window

## Issue
#77 in jbcrane13/agentboard
## Tasks
- [x] Implement Desktop app: Cannot change session or agent profile from picker above chat window
- [x] Handle edge cases and error states
- [x] Add accessibilityIdentifier to every interactive element
- [x] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"