# Claude Notes

## Phase 1 Completed (2026-02-14)

- Tracking: `AgentBoard-qrw` (and children `.1` to `.5`) are closed.
- Baseline shell is implemented with `NavigationSplitView` + nested `HSplitView`.
- Window/layout contract:
  - Default: `1280x820`
  - Minimum: `900x600`
  - Sidebar fixed: `220`
  - Center min: `400`
  - Right panel ideal: `340` (resizable)
- Sidebar sections are collapsible: Projects, Sessions, Views.
- Phase 1 placeholders are intentional:
  - Board: empty Open/In Progress/Blocked/Done columns
  - Canvas: `No content`
- Project config decision:
  - `project.yml` is the source of truth
  - Re-run `xcodegen generate` after target/scheme edits
- Test gate decision:
  - `AgentBoardTests` exists with smoke tests
  - Run both:
    - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
    - `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`
