# 2026-04-29 — Port v2 toolbar, columns, and chat input chrome to AgentBoard

## Background

`AgentBoard-v2` is deprecated, but its top-of-window chrome (compact repo picker + stat
chips + search) and chat input bar are visually preferred to the current AgentBoard
equivalents. The current AgentBoard `WorkScreen` and `ChatScreen` use a heavy header
treatment ("WORKSPACE" eyebrow + 30pt title) and a tall two-row chat compose area with
32×32 attach/mic/send buttons — described by the user as "huge blocky".

This spec ports the v2 *layout* (compact, slim, denser) into AgentBoard while keeping
the existing Neumorphic theme (`NeuPalette`, `neuExtruded`, `neuRecessed`) used
throughout the rest of the app.

## Goals

1. Replace the WorkScreen header with a single-row compact toolbar matching v2's
   information density.
2. Make board columns narrower with a darker background for visual depth.
3. Collapse the ChatScreen header and compose area to v2's slim footprint without
   losing any existing functionality.

## Non-goals

- No new functionality. No store, model, or service changes.
- No new screens. No changes to sidebar, settings, agents, or sessions screens.
- No theme rewrite. We adapt v2 *layout* into the Neu palette, not v2's flat system
  styling.

## Section 1 — `WorkScreen` header

**Current** (`AgentBoardUI/Screens/WorkScreen.swift:99-141`)

- `AgentBoardEyebrow("WORKSPACE")` + 30pt bold "GitHub Issues" title (left).
- Repo picker (only when >1 repo) + dead `Filter` button + `NeuButtonTarget(isAccent: true)` "+" button (right).

**New**

Single `HStack` row. No eyebrow, no title.

```
[Repo Picker ▾]   ●Open N   ●In Progress N   ●Done N      [🔍 Search…]   [+]
```

- **Repo picker**: reuse existing `filterRepositoryPicker`. `Picker(...)` with `.menu`
  pickerStyle, `.frame(minWidth: 140)`. The system Picker label already renders as a
  compact menu button on macOS; do NOT wrap it in `neuExtruded` (the modifier would
  paint behind the system control without affecting its chevron/border, producing a
  doubled background). Keep the "All repos" tag and the existing `.tint`.
- **Stat chips**: a private `statChip(label:count:color:)` helper.
  - 7pt circle filled with status color, `count` in `system(.caption, design: .rounded, weight: .semibold).monospacedDigit()`,
    `label` in `.caption` secondary.
  - Colors: `NeuPalette.statusBlue` (Open), `NeuPalette.accentOrange` (In Progress),
    `NeuPalette.accentGreen` (Done).
  - Counts pulled from `groupedFilteredItems`. `.review` is folded into "In Progress"
    for the chip totals (matches the v2 mental model — review is a sub-state of
    in-progress, not a top-level column-equivalent).
- **Search field**: magnifyingglass icon + plain `TextField` bound to
  `$appModel.workStore.searchText`. `.frame(maxWidth: 180)`, recessed
  `NeuPalette.inset` background, 8pt corner radius.
- **"+" button**: existing create-issue action. Replace `NeuButtonTarget(isAccent: true)`
  with a 28×28 circle, 14pt `plus` icon, `neuExtruded(cornerRadius: 14, elevation: 3)`,
  accent tint. Disabled when `!appModel.settingsStore.isGitHubConfigured`.
- **Removed**: `AgentBoardEyebrow`, the "GitHub Issues" `Text`, the dead `Filter` button
  (it does nothing today — no functionality lost).

Header padding shrinks: `.padding(.horizontal, isCompact ? 22 : 28)`,
`.padding(.top, isCompact ? 16 : 14)`, `.padding(.bottom, 10)` (was top 20, bottom 14).

## Section 2 — Board columns

**Current** (`AgentBoardUI/Screens/WorkScreen.swift:143-211`)

- Column width computed as `max((proxy.size.width - 32) / 3, 190)`.
- Background `NeuPalette.background.opacity(0.62)`.

**New**

- Column width fixed at `170` (`.frame(width: 170, height: proxy.size.height - 28, alignment: .topLeading)`).
- Background `NeuPalette.background` at full opacity. The surrounding `NeuBackground()`
  is lighter, so removing the `0.62` gives the column-vs-canvas contrast the user
  liked in v2.
- Border, corner radius (14), and the rest of the column structure unchanged.
- Horizontal scroll already exists; with 170pt columns the scroll behavior is the
  user's intent (more columns visible on wide screens, scrollable on narrow).

## Section 3 — `ChatScreen` header

**Current** (`AgentBoardUI/Screens/ChatScreen.swift:58-114`)

- Optional chat-only toggle button (left).
- `AgentBoardEyebrow("HERMES AI")` + 18pt (28pt compact) "Live Link" title.
- Spacer.
- `desktopSessionMenu`/`desktopProfileMenu` (or compact equivalents), connection dot,
  refresh button.

**New**

Drop the eyebrow + title `VStack` (lines 74–80). Header collapses to a single short row:

```
[chat-only toggle]                    [session ▾] [profile ▾] ● [↻]
```

- Left: chat-only toggle button only (when `onToggleChatOnly` provided and not compact).
- Right: existing menus + status dot + refresh button. No size changes — they're
  already compact pills.
- Vertical padding: `.padding(.top, 10).padding(.bottom, 8)` (was top 14, bottom 12).
- Bottom 1pt `NeuPalette.borderSoft` divider preserved.

## Section 4 — `ChatScreen` compose area

**Current** (`AgentBoardUI/Screens/ChatScreen.swift:424-540`)

- Secondary toolbar HStack at lines 451–478: 32×32 paperclip + 32×32 mic in raised
  Neu circles, above the textfield.
- Primary row HStack at lines 481–516: textfield + 32×32 send button inside an 18-radius
  pill with thick shadow (`shadow(radius: 6, y: 2)`).

**New**

Single row, no secondary toolbar.

```
[📎] [🎤] [ Message Hermes…                       ] [↑]
```

- Layout: `HStack(spacing: 8)` containing in order:
  1. Paperclip button — 14pt `paperclip` icon, foreground `accentCyan` (or
     `textSecondary` when disabled), 22×22 hit area, `buttonStyle(.plain)`. No circle
     background, no shadow. Same `showAttachmentPicker` sheet as today.
  2. `VoiceRecordingButton` — re-styled or wrapped to render as a flat 14pt
     `mic` icon in the same color treatment. (If `VoiceRecordingButton` doesn't expose
     an icon-only mode, replace its visual layer locally without touching its model.)
  3. `TextField(" Message Hermes...", text: $chatStore.draft, axis: .vertical)` with
     `lineLimit(1...6)` and the existing `.onKeyPress(.return, ...)` send handler.
     Unchanged.
  4. Send button — 22×22 circle, `arrow.up` 12pt bold, `accentCyan` fill when
     `canSend`, clear when not. Switches to red `stop.fill` when streaming. Same
     `sendDraftWithRetry()` action as today.
- Outer pill: `padding(.horizontal, 12).padding(.vertical, 8)`, `RoundedRectangle(cornerRadius: 12)`,
  `NeuPalette.surfaceRaised` fill, `NeuPalette.borderSoft` 1pt stroke, soft shadow
  `radius: 3, y: 1` (was 6/2).
- Outer wrapper padding: `.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)`
  (was 14/10/12).
- `slashCommandSuggestions` overlay and `AttachmentPreviewStrip` kept unchanged above
  the input row.
- All existing accessibility identifiers preserved verbatim:
  `chat_button_attach`, `chat_button_send`, plus the `VoiceRecordingButton`'s own.

## Files touched

- `AgentBoardUI/Screens/WorkScreen.swift` — replace `header` body, replace
  `filterRepositoryPicker`, retune column frame + background in `boardLayout`. Add
  private `statChip` helper.
- `AgentBoardUI/Screens/ChatScreen.swift` — replace `header` body, replace
  `composeArea` body. No new files.

No changes to `AgentBoardCore`, `AgentBoardUI/Theme`, `AgentBoardUI/Components`, or
sheets.

## Risks and mitigations

- **Risk:** `VoiceRecordingButton` may have a fixed visual that doesn't accept a
  size/style. **Mitigation:** wrap or re-style at the call site; do not modify the
  recorder service or its model.
- **Risk:** Stat chip totals could miscount if `WorkState.review` is not folded into
  In Progress. **Mitigation:** spec is explicit — `.review` rolls into the In Progress
  count; `.done` and `.ready` map directly.
- **Risk:** Compact (iOS) layout might overflow the toolbar. **Mitigation:** stat chips
  hide on compact (`if !isCompact`); search field shrinks to icon-only when too narrow,
  or hides on compact entirely. Defer iOS-specific tuning until verified visually.

## Verification

- `xcodebuild -scheme AgentBoard -destination 'platform=macOS' build` (run on `mac-mini`
  per CLAUDE.md, never locally).
- Visual check: open Work tab, confirm single-row toolbar, narrower darker columns,
  search filters issues, +/picker still work. Open Chat tab, confirm one-row compose,
  attach + mic + send all functional.
- All existing accessibility identifiers grep-locatable post-change.
