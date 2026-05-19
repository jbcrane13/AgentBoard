# PRD: Expand modern AgentBoard coverage for companion events and UI smoke flows

## Issue
#46 in jbcrane13/agentboard
## Tasks
- [ ] Implement Expand modern AgentBoard coverage for companion events and UI smoke flows
- [ ] Handle edge cases and error states
- [ ] Add accessibilityIdentifier to every interactive element
- [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"