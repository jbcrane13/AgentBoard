# PRD #255: Remove Large Text Field Behind Picklist in Ticket Create/Edit View

## Issue
In the CreateIssueSheet (and likely EditIssueSheet), there is a large text field visible behind the label/picklist rows (Repository, Type, Priority, Status, Agent). This creates visual noise and a cluttered look.

## Root Cause
The `labelDropdown` helper in `CreateIssueSheet.swift` wraps each Picker in `.neuRecessed(cornerRadius: 16, depth: 6)` which creates a recessed background. On iOS, `.pickerStyle(.menu)` renders as a compact tappable row that opens a popover. The recessed background is full-width and visually reads as a text input field behind the picker.

## Files to Modify
- `AgentBoardUI/Screens/CreateIssueSheet.swift` — labelDropdown helper and field layout
- Check for similar pattern in `AgentBoardUI/Screens/EditIssueSheet.swift` or `AgentBoardUI/Screens/IssueDetailSheet.swift` if they exist

## Tasks

### T1: Redesign labelDropdown for cleaner picklist layout
Replace the current `labelDropdown` implementation with a cleaner layout that doesn't look like a text field:

Option: **Inline chip-style picklist**
- Label on the left, current selection as a tappable chip/pill on the right
- No recessed background — use a subtle bottom border or minimal card
- This eliminates the "field behind picklist" look entirely

OR Option: **Compact labeled row**
- Label above (as current), but the picker row uses `.neuRecessed` with no inner padding and a reduced visual depth — more like a segmented control appearance
- Remove the `frame(maxWidth: .infinity)` on content that stretches the recessed area

Choose the approach that looks best with the existing NeuPalette design system. Be creative but consistent.

### T2: Apply same pattern to EditIssueSheet (if it exists)
- Search for `EditIssueSheet` or similar edit views
- Apply the same labelDropdown fix there

### T3: Verify
- Build: `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Build: `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoardMobile -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Visual: No text field artifacts visible behind picklists

## Constraints
- Follow NeuPalette design system (colors, styles)
- Maintain the same data flow — Pickers still bind to the same @State variables
- Required field indicators (red dot) must remain
- Keep `.pickerStyle(.menu)` on iOS — it's the native pattern
- Accessibility identifiers must be preserved or improved
- Build both macOS and iOS targets

## Definition of Done
- [ ] No visual text field artifact behind picklists in CreateIssueSheet
- [ ] Clean, well-organized layout for all label/picklist rows
- [ ] Same fix applied to EditIssueSheet if it exists
- [ ] macOS build succeeds
- [ ] iOS build succeeds
- [ ] All existing accessibility identifiers preserved
