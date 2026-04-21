# AgentBoard v2 — UI/UX Rewrite Spec

**Status:** Draft · **Scope:** UI/UX only (stack-agnostic) · **Audience:** The coding agent executing the rewrite.

> **How to use this document.** Read §0 first — it's the rules of the road. §1–§3 set the shape of the app. §4 is the design system: treat it as code. §5–§9 are per-surface specs with acceptance criteria. §10 is the anti-list: what NOT to carry over from v1. The wireframe at `docs/rewrite/wireframe.html` is the visual source of truth — if this spec and the wireframe disagree, the wireframe wins and this doc should be patched.

---

## 0. Operating rules for the implementing agent

These are constraints on *how* you build, not *what* you build.

1. **Treat this document as the spec.** Do not invent surfaces, controls, or modes that aren't here. If a question arises, write it under "Open Questions" at the bottom of this file and proceed with the most conservative interpretation.
2. **State is split, not merged.** Never create a single "AppState" god-object. Use domain stores (§3). A view should subscribe to the smallest store that satisfies its needs.
3. **Views never call services directly.** Views read stores and dispatch intents. Stores own service calls. This is non-negotiable.
4. **No hidden side-effects in navigation.** Opening a destination must not silently change a mode, toggle panels, or resize windows. Any such effect must be user-initiated or documented here.
5. **Filesystem/network access in views is forbidden.** Including config reads, shell calls, and `URLSession` usage. All of that belongs in services.
6. **Polling is coordinated.** Do not spawn ad-hoc `Task` loops in views or stores. All periodic work goes through a single `ScheduleRunner` that knows about app focus and visibility (§3.5).
7. **No magic numbers in layout.** Every size, spacing, radius, duration, and color references a design token (§4.1). Raw hex, raw pixels, or hardcoded RGB tuples are a review blocker.
8. **Every interactive element has four states:** default, hover, active/pressed, selected/focused. Ship all four or don't ship the element.
9. **Both color schemes ship together.** Dark and light must be designed at the same time. If light mode looks right and dark mode is "we'll fix it later," the task is not done.
10. **Test gate:** the app must build and the layout regression tests (§11) must pass before any feature is marked complete.

---

## 1. Vision and scope

AgentBoard v1 had the right concept — three panes unifying work tracking, agent chat, and agent session monitoring — but the execution had three problems: overlapping navigation systems, weak visual hierarchy, and performance friction from a god-object state tree.

v2 keeps the concept. It rebuilds the UI around three principles:

- **One navigator.** The sidebar is the only global navigator. The center panel is a tabbed workspace where destinations (Board, Terminal, Epic-detail, Bead-detail) open as tabs.
- **One source of truth per concern.** Connection state, unread counts, layout persistence — each lives in exactly one place and every view reads from that place.
- **Canvas is a surface, not a mode.** Chat is always available. Canvas opens as a drawer between center and chat when something is "sent to canvas." No mode picker.

Out of scope for v2: multi-window, detachable panes, mobile, in-app code editor.

---

## 2. Layout contract

See `wireframe.html` for the authoritative visual.

### 2.1 Window shape

| Dimension               | Default | Min     | Max   |
| ----------------------- | ------- | ------- | ----- |
| Window width            | 1440    | 960     | —     |
| Window height           | 900     | 600     | —     |
| Sidebar width           | 224     | 220     | 280   |
| Chat dock width         | 380     | 320     | 520   |
| Canvas drawer min width | 520     | 480     | —     |
| Center panel min width  | 480     | 440     | —     |

### 2.2 Grid

The main content area is a horizontal grid with up to four columns:

```
[ sidebar ] [ center ] [ canvas? ] [ chat ]
   224         flex      flex        380
```

Only `center` and `canvas` may flex. Sidebar and chat are user-resizable via their inner edge. Canvas appears only when there is canvas content and the user hasn't explicitly dismissed it.

### 2.3 Visibility states

Each of the three side regions (sidebar, canvas, chat) is independently toggleable. Order of precedence when space is constrained (< 960 px effective):

1. Canvas drawer closes automatically.
2. Then sidebar collapses to a 48 px rail (icons only, no labels).
3. Chat never auto-collapses — it's the primary conversation surface. At minimum it becomes a detachable floating pill the user can re-expand.

Collapsing sidebar must NOT affect chat. Collapsing chat must NOT affect sidebar. The v1 "Hide Dashboard" button which toggled both together is explicitly forbidden.

### 2.4 Top bar

A single 40 px-tall chrome bar runs the full width above the grid. It contains, in order: window controls (if not using native titlebar), app mark + breadcrumb, spacer, connection chip, notifications icon, settings icon. See §5.

The top bar is the **only** place connection state and global notifications appear. Any other rendering of these is a bug.

---

## 3. State architecture

### 3.1 Store decomposition

Replace the v1 monolithic `AppState`. Create these domain stores. Each is small, observable, and independently testable. Views subscribe only to the stores they need.

| Store                  | Responsibility                                                                                       |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `ProjectStore`         | List of projects, active project, per-project counts.                                                |
| `BoardStore`           | Beads for the active project, filter state, selection, drag-in-progress state.                       |
| `SessionStore`         | Live tmux/agent sessions, capture output, launch/interrupt intents.                                  |
| `ChatStore`            | Messages, streaming state, current chat session key, thinking level.                                 |
| `CanvasStore`          | Canvas history stack, current surface, visibility, nav index.                                        |
| `ConnectionStore`      | Gateway WebSocket state, last error, retry schedule. **Sole source of truth for connection status.** |
| `LayoutStore`          | Sidebar/chat widths, sidebar visibility, chat visibility, tab strip, active destination.             |
| `NotificationStore`    | Unread counts per channel (chat, sessions, builds), transient toasts, dismissals.                    |
| `PreferencesStore`     | User preferences: theme, hotkeys, default thinking level, agent model.                               |

Rules:

- Stores never reference each other directly. Cross-store effects flow through a thin `Coordinator` layer.
- Stores publish change notifications only when their domain changes. Example: incoming chat tokens update `ChatStore` and never cause `BoardStore` readers to re-render.
- `LayoutStore` owns the *current destination* (e.g. `.board`, `.terminal(sessionId)`, `.epic(id)`, `.bead(id)`, `.settings`). Views switch what they render based on destination, not based on a `selectedTab` enum duplicated across sidebar and center.

### 3.2 Intents, not properties

Mutations to stores go through methods, not direct property writes from views. Example:

```
// ❌ forbidden
chatStore.isStreaming = true

// ✅ required
chatStore.beginStream(runId: id)
```

This makes mutations traceable and testable.

### 3.3 No integer-increment sheet triggers

v1 used patterns like `appState.newSessionSheetRequestID += 1` watched by a view. This is forbidden. Sheets are driven by a single optional state (`@State var presenting: SheetKind?`). Opening is `presenting = .newSession`; closing is `presenting = nil`.

If a command elsewhere (menu bar, keyboard shortcut) needs to open a sheet, it dispatches an intent to `LayoutStore`, which publishes a one-shot event the root view consumes. No incrementing counters.

### 3.4 Layout persistence

`LayoutStore` persists exactly these preferences and nothing else:

- sidebar width (integer)
- chat width (integer)
- sidebar visible (bool)
- chat visible (bool)
- canvas visible (bool, default `false`; does NOT persist across launches — canvas only opens when there's something to show)
- open tab strip entries (array of destinations)

Persistence is JSON at `~/.agentboard/layout.json`. It loads once at launch. It writes on change, debounced 500 ms. Window frame is owned by AppKit — do not persist it manually.

### 3.5 ScheduleRunner

Single actor that owns all periodic work. Each subscriber registers a `WorkItem` with:

- `id` (string)
- `interval` (Duration)
- `runWhen` — a predicate (e.g. "only when app is foreground AND this destination is visible")
- `action` — async closure
- `backoff` — linear or exponential with a cap, applied on consecutive errors

The runner ticks once per second and invokes items whose next-run time has arrived and whose predicate passes. This replaces v1's five independent polling loops. Idle cadences (app backgrounded, destination not visible) must be ≥ 4× the active cadence.

---

## 4. Design system

### 4.1 Tokens

All values in the app must come from this token set. See `wireframe.html` `:root` block for the canonical values. This table is the spec.

#### Color tokens (semantic)

| Token             | Light                          | Dark                           | Usage                                                 |
| ----------------- | ------------------------------ | ------------------------------ | ----------------------------------------------------- |
| `bg.app`          | `#fafaf7`                      | `#141418`                      | Window background                                     |
| `bg.surface`      | `#ffffff`                      | `#1f1f23`                      | Cards, inputs, chat bubble (agent)                    |
| `bg.elevated`     | `#f2f2ed`                      | `#26262a`                      | Column backing, hover states                          |
| `bg.sidebar`      | `#1c1c1f` (always dark)        | `#1c1c1f`                      | Sidebar. Sidebar does NOT follow theme.               |
| `bg.chrome`       | `#ffffff`                      | `#1a1a1e`                      | Top bar                                               |
| `border.soft`     | `rgba(0,0,0,0.06)`             | `rgba(255,255,255,0.05)`       | Cards, panel separators                               |
| `border.med`      | `rgba(0,0,0,0.10)`             | `rgba(255,255,255,0.08)`       | Buttons, inputs                                       |
| `border.strong`   | `rgba(0,0,0,0.18)`             | `rgba(255,255,255,0.14)`       | Hover, focus                                          |
| `text.primary`    | `#1a1a1f`                      | `#ececee`                      | Body text, titles                                     |
| `text.secondary`  | `#5a5a62`                      | `#a2a2a9`                      | Labels, captions                                      |
| `text.muted`      | `#8a8a92`                      | `#6a6a72`                      | Timestamps, metadata                                  |
| `accent`          | `#e8742c`                      | `#e8742c`                      | CTAs, active, brand                                   |
| `accent.strong`   | `#c65a18`                      | `#c65a18`                      | Hover state of CTAs                                   |
| `accent.soft`     | `#fff0e3`                      | `rgba(232,116,44,0.14)`        | Filter-active bg, canvas-ref link bg                  |
| `accent.on`       | `#ffffff`                      | `#ffffff`                      | Text on accent                                        |
| `status.open`     | `#3e7cff`                      | `#5d8fff`                      | Open column, user message accents                     |
| `status.progress` | `#e8742c`                      | `#e8742c`                      | In Progress column, streaming indicator               |
| `status.blocked`  | `#d93b3b`                      | `#e85555`                      | Blocked column                                        |
| `status.done`     | `#2fa36b`                      | `#3bc47e`                      | Done column, connected indicator                      |
| `status.muted`    | `#8a8a92`                      | `#6a6a72`                      | Stopped session, neutral                              |

#### Spacing scale

`2, 4, 6, 8, 12, 16, 20, 24, 32, 48`. All padding, margin, and gaps must be one of these.

#### Radius scale

| Token       | Value | Usage                                   |
| ----------- | ----- | --------------------------------------- |
| `radius.sm` | 4     | Badges, pill tags, small chips          |
| `radius.md` | 8     | Cards, buttons, inputs                  |
| `radius.lg` | 12    | Board columns, containers               |
| `radius.xl` | 16    | Window frame, large sheets              |

Cards use **exactly** 8. Not 5, not 12. The v1 inconsistency (12 for card, 5 for badge inside) is forbidden.

#### Type scale

| Token       | Size | Weight options | Usage                     |
| ----------- | ---- | -------------- | ------------------------- |
| `fs.caption`| 11   | 400, 500, 600  | Metadata, IDs, badges     |
| `fs.body`   | 13   | 400, 500       | Default UI text           |
| `fs.title`  | 15   | 500, 600       | Section heads, chat header|
| `fs.heading`| 20   | 600            | Project title             |

Monospace (`SF Mono` / `JetBrains Mono`) for: bead IDs, commit SHAs, file paths, code blocks.

#### Motion

| Token            | Duration | Curve                       |
| ---------------- | -------- | --------------------------- |
| `motion.instant` | 60 ms    | ease-out                    |
| `motion.fast`    | 120 ms   | ease-out                    |
| `motion.std`     | 220 ms   | cubic-bezier(.2,.6,.3,1)    |
| `motion.slow`    | 360 ms   | cubic-bezier(.2,.6,.3,1)    |

Panel open/close animations: `motion.std`. Card hover: `motion.fast`. Micro-feedback (button press): `motion.instant`. Avoid animations longer than `motion.slow` except for one-time-per-session events (first launch).

### 4.2 Elevation

Three levels only:

- **Level 0 (flat):** flush surfaces, 0.5 px hairline border.
- **Level 1 (raised card):** `0 1px 2px rgba(0,0,0,0.04)` + hairline.
- **Level 2 (floating):** `0 2px 8px rgba(0,0,0,0.06)` + hairline. Used for hover lift and drawer shadow.
- **Level 3 (modal/sheet only):** `0 10px 30px rgba(0,0,0,0.12)`.

Do not stack shadows. Do not use `.blur` as a decoration.

---

## 5. Top bar

Height 40. Full width. Content order:

1. Window traffic lights (system-native; only if using a custom titlebar).
2. **Breadcrumb:** `[app mark] [project name] › [destination]`. Project is a dropdown. Destination updates live with the current tab.
3. Flex spacer.
4. **Connection chip:** compact pill, dot + text ("Connected · main" / "Reconnecting…" / "Offline — click to retry"). Click opens a connection details popover.
5. **Notifications icon bell:** badge when unread. Click opens a notifications popover listing recent events (build completed, session stopped, chat reply received while in another destination).
6. **Settings icon gear:** opens settings as a *destination* (new tab in center strip), not as a sheet.

Hard rules:
- There is NO mode picker, NO tab strip, and NO duplicate connection state rendered anywhere else in the app.
- Breadcrumb text is copyable. Clicking segments jumps (project name → project picker popover; destination → already there, no-op).

Acceptance:
- Unit test verifies that mutating `ConnectionStore.state` updates exactly one visible chip.
- UI test verifies the breadcrumb reflects destination switches.

---

## 6. Sidebar

Always dark (does not follow theme). Width 224 by default, resizable 220–280 via inner edge drag.

### 6.1 Structure

```
┌────────────────────────┐
│ [A] AgentBoard      ‹  │   40 px head
├────────────────────────┤
│ PROJECTS           +   │
│  📡 NetMonitor-iOS  15 │
│  🎛 AgentBoard      42 │
│                        │
│ SESSIONS · 3      +    │
│  ● ab-net-nwpath   4m  │
│  ● ab-agent-df9.4 12m  │
│  ○ ab-openclaw-r  idle │
│                        │
│ VIEWS                  │
│  ◐ Board               │
│  ◈ Epics            3  │
│  ⚡ Ready queue     4  │
│  🕐 History            │
│  📝 Notes              │
│                        │
├────────────────────────┤
│ ● GitHub · connected ⚙ │
│ [  ＋  New session  ]  │
└────────────────────────┘
```

### 6.2 Sections

- **Projects.** Click to switch active project. Selected project has left accent rail + tinted background. Count on the right is open-bead count. Plus button opens project importer.
- **Sessions.** Live list of tmux/agent sessions for the active project. Each row: status dot, session name (truncated, ellipsis), meta (elapsed for running/idle, "stopped" / "error" otherwise). Clicking opens the session in the center panel as a new surface tab. Plus button opens New Session sheet.
- **Views.** Project-scoped destinations. Clicking changes the active surface tab (or opens it if not already open): Board, Epics, Ready Queue, History, Notes.

### 6.3 Footer

Two rows:

1. GitHub / integration status (dot + label). Clicking opens settings at the GitHub section.
2. Full-width "New session" button (dashed border, low contrast — secondary action, not a primary CTA since project/session launching is a subflow, not the hero action).

### 6.4 Error recovery

If `SessionStore` cannot reach the tmux socket, the Sessions section shows an inline banner: `⚠ tmux socket unavailable · [Retry] [Launch tmux]`. Do NOT silently clear the sessions list. The last-known sessions remain dimmed.

### 6.5 Collapsed rail

At window widths below 960 px effective, the sidebar collapses to a 48 px rail showing only icons (one per project, a pill for "sessions count," and a gear). Hovering a rail icon shows a tooltip with the full label. Re-expand via top-bar toggle.

Acceptance:
- Switching projects updates BoardStore, ChatStore context chips, and top bar breadcrumb but NOT layout width.
- Session list auto-refreshes via a `ScheduleRunner` work item, not an ad-hoc loop.

---

## 7. Center panel

The center panel is a **tabbed workspace**. There is a tab strip at the top (above the project header) and the body swaps based on the active tab.

### 7.1 Surface tab strip

Thin (32 px) tab strip. Tabs are Destinations. Tab shape: rounded top corners, active tab has surface background continuing into the body (visual continuity). Each tab shows:

- Small color dot (matches destination kind: board = muted, session = orange pulse if running, epic = purple, bead-detail = blue).
- Truncated label (max 150 px wide).
- Close `✕` that appears on hover, except for the Board tab which is pinned and cannot be closed.

Tabs are reorderable by drag. Tab count is capped at 12; opening a 13th closes the least-recently-active non-pinned tab.

Shortcut: `⌘⌥→` next tab, `⌘⌥←` prev tab, `⌘W` close current tab (no-op if pinned).

### 7.2 Project header

Below the tab strip, 64 px tall, only rendered for Board / Epics / Ready / History destinations (not for Terminal / Bead-detail / Epic-detail — those own their own header).

Layout:

- Left: emoji/icon, project name (fs.heading), path + branch + session count (fs.caption muted mono).
- Right: four stat tiles (Open / In Progress / Blocked / Done). Numbers are large (`font-size: 18`, tabular-nums), labeled below (`fs.caption`, uppercase). Each tile is clickable and scopes the board to that column.

### 7.3 Board destination

Toolbar (48 px) between header and columns:

- Filter chips: Kind, Owner, Epic, Labels, "Hide backlog" toggle.
- Active chips use `accent.soft` background + `accent.strong` text + inline `✕` to clear.
- "Clear all filters" appears only when ≥ 2 chips are active.
- Right-aligned: search box (fuzzy by ID + title), refresh, `＋ New bead` (primary button).

Four columns (Open / In Progress / Blocked / Done), equal flex, 12 px gap. Columns use `bg.elevated`.

Column head: status dot + uppercase label + count pill. No color beyond the dot.

Cards (see §9.1).

Drag-and-drop between columns writes via the store, which shells to `bd` CLI. Optimistic UI: card moves immediately, reverts if the write fails.

### 7.4 Terminal destination

Rendered when a session is the active tab.

Top subheader (40 px):

- Status dot, session name, model, elapsed, linked bead (click → open bead-detail tab).
- Right: `⏎ Nudge`, `✋ Interrupt`, `⏹ Stop`, `↗ Attach in iTerm` (copies the tmux attach command).

Body is a monospace pane rendering tmux capture. Do NOT use SwiftTerm unless fully interactive input is needed; start with read-only styled capture for v2.0 and evaluate interactivity later.

Auto-scrolls to bottom when new output arrives AND user's scroll position is already at or near bottom. If user scrolled up, show a "Jump to live" pill at bottom-right.

### 7.5 Epics / Ready / History / Notes destinations

Placeholder specs — full layouts TBD after v2.0 lands. Minimum requirement: same header + toolbar pattern as Board; list-based bodies. These must not reintroduce the v1 "tab bar that duplicates sidebar nav" anti-pattern.

### 7.6 Bead detail

Opens as a tab, NOT a sheet. Full two-pane: description + comments on the left, metadata (assignee, epic, labels, dependencies, linked commits) on the right. "Edit" is inline, not a separate modal.

---

## 8. Canvas drawer

### 8.1 When it appears

The canvas drawer appears when any of these happen, and only then:

- Agent message contains a canvas directive (`<!-- canvas:markdown -->…<!-- /canvas -->` or structured tool output).
- User right-clicks a chat message → "Open in canvas".
- User drags a file into the chat input.
- User presses `⌘.`.

It opens between center and chat with `motion.std`. It does NOT replace the center panel.

### 8.2 Shape

Fills the space between center-min and chat. Minimum 520 px wide. The divider between center and canvas is draggable. Double-click the divider to reset to default proportion (center 45 / canvas 55).

### 8.3 Header (44 px)

- Surface type dot, canvas title (agent-provided or filename).
- Canvas-history ← → (agent may push multiple surfaces over time; these navigate the stack).
- `↓` Export, `✕` Close (closing does not delete the stack — re-opening resumes where you were).

### 8.4 Body

Renders the current canvas surface. Surface kinds:

| Kind      | Renderer                                         |
| --------- | ------------------------------------------------ |
| markdown  | styled markdown in native text view              |
| html      | WebView (shared instance, navigation-blocked)    |
| image     | image view with fit/fill toggle                  |
| diff      | side-by-side or unified (user preference)        |
| mermaid   | rendered via mermaid.js in the shared WebView    |
| terminal  | monospace capture (reused from Terminal dest.)   |

The WebView is created once, reused across renders. Do NOT create a new WebView per render — that was a v1 perf sink.

### 8.5 Rules

- Closing the canvas does not close chat.
- Resizing the canvas never resizes the chat or changes the chat's width percentage — the center panel absorbs the delta.
- Canvas content is never auto-pushed when the drawer is closed and the user manually closed it in the current session; instead, the most recent canvas-ref appears as a small pill at the top of the chat (`📋 1 new canvas update`).

Acceptance:
- Opening canvas from a chat message animates in without a layout jump elsewhere.
- Typing in chat while canvas is open remains uninterrupted (focus retained).

---

## 9. Chat dock

Always visible by default. 380 px wide. Resizable 320–520 via its left edge.

### 9.1 Header (44 px)

- Session picker (small pill): dot + session key + chevron. Clicking lists gateway sessions.
- Flex spacer.
- Thinking-level chip (🧠 + level). Click cycles: off → low → medium → high → default.
- New-chat icon (✎), history icon (⧉).

NO connection indicator here. Connection lives in the top bar only.

### 9.2 Message list

`LazyVStack` in `ScrollView`, single level. Do not nest additional `ScrollView`s inside.

#### Message bubble

- Role-based: agent = `bg.elevated` with bottom-left tail (border-bottom-left-radius: 4), user = `accent` with bottom-right tail.
- Max bubble width: 92% of dock width.
- Meta line (above the bubble for agent, above for user with reversed layout): `[name] · [relative time]`. Meta uses `fs.caption` muted.
- Timestamps are mandatory. Format: "just now", "2m", "14m", "1h", "Yesterday 3:42 PM", "Mar 14 3:42 PM".

#### Bead references

Any `AgentBoard-xxx` substring in agent output renders as a monospace pill (`bead-ref` class). Clicking opens that bead's detail tab. Bead refs are detected by regex but only considered valid if they resolve against `BoardStore`.

#### Canvas references

If an agent message pushed content to canvas, append a small bordered link row at the bottom of the bubble: `📋 Sent to canvas · <title>`. Click opens the canvas drawer at that surface.

#### Code blocks

Rendered with a muted monospace background and a copy button on hover. No syntax highlighting in v2.0 unless it's free (ships with the markdown renderer).

#### Typing indicator

Three-dot animated bubble in agent style appears while streaming. Remove when the final event arrives.

### 9.3 Context bar

A thin strip above the input. Shows the context envelope that will be sent with the next message:

- Active project pill
- Active destination pill (read-only)
- Selected bead pill (removable `✕`)
- Gateway session pill (read-only)

This is not decorative — it's the literal prompt context. If the user removes the bead pill, the next message omits it.

### 9.4 Input

- Textarea that grows from 36 px min to 160 px max, then scrolls.
- Placeholder: `Message Claude…   /command  @bead  ⌘↵ to send`.
- Slash-command completions appear as a dropdown above the input (already exists in v1 via `SlashCommandService`).
- Send button = accent square, `⌘↵` keyboard shortcut. While streaming, the send button becomes a red stop button.

Focus rules:
- `⌘⇧L` focuses the input.
- Tabbing out does not lose the draft.
- Switching projects does NOT clear the input.
- Switching chat sessions shows a confirmation if the draft is non-empty.

---

## 10. Components

### 10.1 Card (Bead)

```
┌────────────────────────────┐
│ BEAD-ID  [KIND]            │
│ Title with up to 3 lines   │
│ [avatars]     [git·sha·4h] │
└────────────────────────────┘
```

- Padding 12 · 10.
- Background `bg.surface`, border `border.soft`, radius `radius.md` (8).
- Hover: border `border.strong`, `shadow-hover`, translateY(-1px), `motion.fast`.
- Selected: accent border + 3 px `accent.soft` ring.
- ID row: monospace 10 px, muted. Kind badge inline (Feat / Bug / Epic / Chore — colored per kind, subtle).
- Title: `fs.body` 500 weight. 2-line clamp by default, full on hover/selection (use CSS `line-clamp: 2`).
- Meta row: avatars (agent-colored or human) on the left, git/commit info (mono 10 px) or "N min ago" on the right.
- If an agent is actively working the bead, replace the avatar stack with a pulsing dot + "agent" label (`status.progress` color).

### 10.2 Filter chip

- Pill, padding 5 · 10, `radius: 999px`.
- Inactive: `bg.elevated`, transparent border, muted text.
- Hover: bordered, primary text.
- Active: `accent.soft` bg, accent border (`rgba(232,116,44,0.4)`), `accent.strong` text, 500 weight, inline `✕`.

### 10.3 Button

Three variants:

| Variant   | Background         | Text            | Border          | Usage                      |
| --------- | ------------------ | --------------- | --------------- | -------------------------- |
| Primary   | `accent`           | `accent.on`     | `accent`        | Single per toolbar         |
| Secondary | `bg.surface`       | `text.primary`  | `border.med`    | All other actions          |
| Ghost     | transparent        | `text.secondary`| transparent     | Icon buttons, sidebar rows |

All buttons: `fs.caption` or `fs.body`, `radius.md`, 8–16 horizontal padding.

Only ONE primary button per toolbar. If tempted to add a second, it's a ghost or secondary.

### 10.4 Status dot

6 or 7 px circle. Paired with a label unless context makes the meaning obvious (e.g. in a status chip). Always accompanied by a text alternative for a11y.

### 10.5 Avatar

18 × 18 circle, 9 px bold initials. Palette by role:

- Human: gray gradient
- Claude: orange gradient
- Codex: green gradient
- OpenCode: blue gradient

Stacked avatars overlap by 6 px with a 1.5 px bg-colored ring for separation.

### 10.6 Toast / banner

Connection errors and transient app errors appear as a red banner at the top of the chat dock (small, non-modal) OR as a top bar flash (`motion.std`, auto-dismiss 8 s). Never as a blocking modal.

---

## 11. Acceptance criteria (ship gate)

A rewrite phase cannot be marked complete unless all of these pass:

### 11.1 Visual

- [ ] Every color in the running app maps to a token in §4.1. A grep for raw hex or RGB tuples in view files returns zero.
- [ ] Every radius is 4, 8, 12, or 16. No other values.
- [ ] Dark mode is reviewed side-by-side with light. Screenshots attached to the PR.
- [ ] No instance of a button group, mode picker, or tab strip appears outside the wireframe.

### 11.2 IA / behavior

- [ ] There is exactly one breadcrumb/nav surface. Grep for "breadcrumb" or "nav" components returns one canonical implementation.
- [ ] Connection state is displayed in exactly one place (the top bar). Unit test asserts this.
- [ ] Sheets are presented via `@State var presenting: SheetKind?` pattern. No request-ID counters.
- [ ] Closing the sidebar does not close the chat dock, and vice versa.
- [ ] Switching projects does not alter the chat draft.
- [ ] Opening a session creates a new surface tab; it does not replace the center panel.
- [ ] Canvas drawer can open and close without affecting chat width.

### 11.3 State / architecture

- [ ] `AppState` does not exist. Code review rejects PRs introducing it.
- [ ] Each domain store has unit tests that construct the store in isolation.
- [ ] No view file imports `URLSession`, `Process`, or filesystem APIs.
- [ ] All periodic work goes through `ScheduleRunner`. Grep for `Task { while true }` or `Timer.publish` in non-service files returns zero.
- [ ] `LayoutStore` persists only the fields in §3.4.

### 11.4 Performance

- [ ] With a 500-bead fixture, typing a single character into chat does NOT cause `BoardView` to re-render (verified via a render-count debug overlay or instrumentation).
- [ ] Dragging the canvas-center divider does not cause the WebView to re-initialize.
- [ ] Scrolling a chat with 1000 messages is smooth at 60 fps on an M1.
- [ ] Backgrounding the app cuts polling load by ≥ 75 %.

### 11.5 Accessibility

- [ ] All interactive elements reachable by keyboard.
- [ ] Focus indicators visible.
- [ ] Color contrast: text on surfaces ≥ 4.5:1 (WCAG AA).
- [ ] Status is not conveyed by color alone — dot + label always paired.

---

## 12. Anti-list — patterns NOT to carry forward from v1

Agents sometimes re-introduce old patterns by pattern-matching on similar-looking code. Treat this list as a hard deny-list.

1. **`AppState` as a god-object.** Replaced by §3.1 domain stores.
2. **Integer-increment request IDs** (`createBeadSheetRequestID`, `chatInputFocusRequestID`, `newSessionSheetRequestID`). Use `@State` sheet enum + `LayoutStore` one-shot events.
3. **Mode picker** (Chat / Canvas / Split segmented control). Canvas is a drawer (§8). There are no modes.
4. **Hide Dashboard compound toggle** that toggled sidebar + board together with window auto-resize. Each panel toggles independently.
5. **Connection state rendered in 3 places.** One top-bar chip. Period.
6. **9-tab tab bar.** Destinations open as tabs in a workspace strip. Sidebar is the only navigator.
7. **Terminal replacing the center panel.** Terminal is a tab.
8. **ScrollView > LazyVStack > ScrollView** nesting. One scroll container per pane.
9. **Uncoordinated polling loops.** One `ScheduleRunner`.
10. **`NSApplication.shared.keyWindow` window-frame math from inside a view.** Views don't touch window frames.
11. **Raw RGB tuples and magic numbers in views.** Tokens only.
12. **`filteredBeads` recomputed every render.** Memoize on (beads, filter) input.
13. **Silent tmux disconnect** that empties the sessions list. Show last-known + recovery affordance.
14. **Auto-focus side effect that flips mode.** No hidden side effects.
15. **Settings as a conditional branch in `ContentView`**. Settings is a destination.

---

## 13. Phased delivery (suggested)

Each phase is a standalone ship — the app must build and pass §11 at each.

| Phase | Scope                                                                                                      |
| ----- | ---------------------------------------------------------------------------------------------------------- |
| R1    | Tokens, top bar, sidebar, LayoutStore, ConnectionStore, destination routing, empty center (Board stub).    |
| R2    | BoardStore + Board destination + Project header + filter chips + card component.                           |
| R3    | ChatStore wiring + chat dock (header, messages, input, context bar). No canvas yet.                        |
| R4    | SessionStore + Terminal destination + new-session sheet + sidebar sessions section with error recovery.    |
| R5    | CanvasStore + canvas drawer + canvas protocol parsing + "sent to canvas" chat references.                  |
| R6    | NotificationStore + notifications popover + top bar badges + Settings destination.                         |
| R7    | Bead-detail, Epic-detail, History, Ready, Notes destinations. Polish pass against §11 acceptance.          |

At R1 the app should already *feel* different from v1 even though it doesn't do much — the new chrome, the new sidebar, the new tokens, and the absence of the old tab-mode-picker friction is the point.

---

## 14. Open questions (fill in as they arise)

- (none yet)

---

## 15. References

- Wireframe: `docs/rewrite/wireframe.html`
- Original design: `DESIGN.md` (v1)
- Execution audit: *(this branch's commit, summary in the rewrite PR description)*
- v1 chat protocol reference: `docs/CHAT-REWRITE-SPEC.md` (gateway WS JSON-RPC, still valid)
- v1 gateway connection invariants: `CLAUDE.md` — "Gateway Connection: Implementation Reference" (carry forward intact)
