# Native UI Redesign Design

- **Date:** 2026-07-19
- **Status:** Approved (direction + approach chosen by Blake 2026-07-19)
- **Author:** Blake Crane + Claude
- **Scope:** Replace the custom neumorphic dark theme with the native macOS/iOS 26 design language (materials, glass, system semantic colors), adaptive light + dark, across the whole app. Supersedes the visual-styling half of the neumorphic direction; completes ADR-013's "native shell, restrained content" trajectory. Record as **ADR-015**.

## Decisions (locked)

1. **Aesthetic:** native Apple / Liquid Glass — system materials + translucency, system semantic colors, first-party feel that ages with the OS.
2. **Appearance:** adaptive light + dark on both platforms (system-driven).
3. **Rollout:** whole app, token-first — one coherent visual change, no mixed-style period.
4. **Migration:** approach C — redefine the existing `NeuPalette` token API in place (PR 1: the entire visual change), then a mechanical rename `NeuPalette → AppTheme` + dead-code deletion (PR 2).

## Why token-first works here

All styling flows through `AgentBoardUI/Theme/NeumorphicTheme.swift`'s `NeuPalette` — ~20 semantic tokens (background, surface/surfaceRaised/surfaceHover/inset, accents, status colors, text tiers, borders) consumed across 21 view files, plus shared chrome components (`BoardChrome`, card/chip builders). Redefining tokens + chrome restyles the app without structural screen changes.

## PR 1 — the visual change

### Token remapping (NeuPalette, API preserved)

| Token group | New definition |
|---|---|
| `background` | system window background (`Color(nsColor:.windowBackgroundColor)` / `Color(uiColor:.systemBackground)` via platform shim) |
| `surface` / `surfaceRaised` | secondary system background for flat cards; `Material.regular` for raised/floating chrome |
| `surfaceHover` | `.quaternary` fill overlay on hover |
| `inset` | `.quinary`/tertiary system fill (recessed wells, code blocks) |
| `gradientTop/Bottom` | removed from rendering (map to `background` until PR 2 deletes them) |
| `accentCyan`/`accentCyanBright`/`accentForeground` | **system accent color** (`Color.accentColor`) + `.white`-on-accent foreground |
| `accentOrange/Coral/Purple/Green`, `statusBlue/Closed/Success/Idle` | system semantic colors (`.orange/.red/.purple/.green/.blue/.secondary`) — status/agent coding is kept, colors become adaptive |
| `textPrimary/Secondary/Tertiary/Disabled` | `.primary` / `.secondary` / `.tertiary` / `.quaternary` |
| `borderSoft` (and kin) | `.separator` hairline |

Both `NeuTheme` presets (blue/grey) collapse into one adaptive definition; the preset-switching machinery stays compiling but inert until PR 2. The Settings theme picker is removed from the UI in PR 1 (appearance follows the system); its store plumbing is deleted in PR 2.

### Chrome replacement

- **Cards** (board cards, dashboard tiles, list rows): rounded rect (existing radii ≈ 10–12pt kept), `.fill(.regularMaterial)` for raised elements or secondary background for flat ones, hairline `.separator` stroke, **no extruded/inset shadow pair**. A small drop shadow appears only during drag.
- **Glass:** `glassEffect` (OS 26 API, both platforms) on floating chrome — chat compose bar, session-terminal header, dashboard tile hover/press if it reads well; degrade to `Material.thin` where glass hurts legibility (terminal backdrop). Use judgment per surface; legibility beats spectacle.
- **Chat bubbles:** assistant = material surface with hairline stroke; user = accent-tinted fill with white text; system/info = tertiary fill. Streaming spinner/typing unchanged.
- **Chips/badges** (tool activity, blocked badge, status pills): capsule with semantic tint (`.tint.opacity` fills, semantic foregrounds) — no bespoke RGB.
- **Buttons/controls:** prefer native styles (`.bordered`, `.borderedProminent`, `.plain`) over custom button chrome wherever a shared component currently hand-draws one.

### Light-mode landmines (must fix in PR 1)

- `MarkdownText`/`MarkdownBlockView`: hardcoded `.white` prose, `.white.opacity(...)` accents, `.green` code text, `Color.black.opacity(...)` code backgrounds → semantic: `.primary` prose, `.secondary` accents, code blocks on `inset` fill with `.primary` monospaced text (or a dedicated adaptive code color).
- Repo-wide sweep: `grep -rn "\.white\|Color.black" AgentBoardUI` — every hit either justified (text on accent fill) with a comment, or fixed.

### Guardrails & docs

- `DesignSemanticsTests`: re-pin to the new semantics — assert NeuPalette tokens resolve to system-adaptive definitions, assert shared components don't hardcode `.white`/`Color.black` foregrounds (source-text check), update any test pinning neumorphic specifics.
- Accessibility identifiers: unchanged (rename-safe pins).
- **ADR-015** appended: native design language adopted; neumorphic theme retired; ADR-010's visual direction superseded, ADR-013 completed.

### Verification (beyond suite + 3 schemes + lint)

Launch the macOS app in **both** appearances; screenshot every screen (dashboard, chat, work board, agent board, sessions + terminal, settings) before/after. Legibility check on: markdown in chat (light mode!), terminal view, board cards, status colors on both appearances.

## PR 2 — mechanical cleanup

- Rename `NeuPalette → AppTheme` (and `NeuTheme`, `Neu*` component prefixes where they survive) across all consumers; delete dead neumorphic modifiers, gradient tokens, the blue/grey preset machinery, and the theme-picker store plumbing removed from UI in PR 1.
- Zero visual change — before/after screenshots must be identical; suite green.

## Out of scope

- Screen restructuring / navigation changes (ADR-013 shell stands).
- New app icon / brand assets.
- iOS-specific layout rework beyond what the token change implies.
- LifeOps module styling (unbuilt).

## Success criteria

- App renders correctly and legibly in light and dark on macOS and iOS; no hardcoded-white/black regressions (test-pinned).
- No neumorphic extrusion remains; materials/glass used on floating chrome; system accent drives interactive color.
- All 524+ tests green through both PRs; PR 2 is provably no-visual-change.
