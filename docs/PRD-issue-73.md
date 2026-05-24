# PRD: implement slash commands in chat

## Issue
#73 in jbcrane13/agentboard
## Tasks
- [x] Write failing tests that define expected behavior
- [x] Implement implement slash commands in chat to pass tests
- [x] Handle edge cases
- [x] Add accessibilityIdentifier to every interactive element
- [x] Run full test suite — all tests must pass
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"