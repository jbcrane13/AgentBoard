# Native UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute `docs/superpowers/specs/2026-07-19-native-ui-redesign-design.md` — replace the neumorphic theme with the native macOS/iOS 26 design language, adaptive light + dark, in two PRs (visual change, then mechanical rename/cleanup).

**Global Constraints:** as prior plans (strict concurrency, Swift Testing, SwiftLint strict, three schemes, full suite green — baseline per current main; `-derivedDataPath ./DerivedData`; xcodegen for file changes; dot-env hook workaround). NOTE: the checkout is shared with concurrent sessions — implementation runs in an **isolated git worktree**; expect a cold first build there.

---

## PR P — the visual change (`feat/native-ui-tokens`)

### Task P1: Token remapping in NeumorphicTheme.swift
Redefine every `NeuPalette` accessor per the spec's token table (system backgrounds via a small platform shim for NSColor/UIColor, `.primary/.secondary/.tertiary/.quaternary` text, `Color.accentColor` for the cyan accents, system semantic status colors, `.separator` borders, materials for raised surfaces). Keep the `NeuTheme` preset machinery compiling but collapse both presets to the single adaptive definition. `gradientTop/Bottom` → `background`. Where a token's type must change from `Color` to something material-like, prefer keeping `Color` tokens and introducing sibling accessors (e.g. `surfaceMaterial: Material`) so consumers migrate per-site without breakage.

### Task P2: Chrome components
Rework the shared card/chip/button chrome (`BoardChrome.swift`, the extruded/inset modifiers in NeumorphicTheme.swift, `NeuChatBubble` in ChatBubble.swift, dashboard tile styling): flat rounded cards (`.regularMaterial` raised / secondary background flat) + `.separator` hairline, drag-only shadows, capsule chips with semantic tints, native button styles where custom chrome is hand-drawn. `glassEffect` on compose bar + terminal header (degrade to `Material.thin` if legibility suffers; the terminal backdrop stays opaque).

### Task P3: Light-mode landmines
Fix `MarkdownText.swift`/`MarkdownBlockView` hardcoded `.white`/`.green`/`Color.black` → semantic per spec. Then sweep: every `grep -rn "\.white\b\|Color\.black" AgentBoardUI AgentBoard AgentBoardMobile` hit is fixed or justified-with-comment (text on accent fills is the main justified case).

### Task P4: Settings + guardrails + ADR
Remove the theme picker UI from SettingsScreen (leave store plumbing; PR 2 deletes it). Update `DesignSemanticsTests` to pin the new semantics + a no-hardcoded-white/black source assertion for shared components. Append **ADR-015** (native design language; supersedes ADR-010's visual direction; completes ADR-013) matching the ADR file format.

### Task P5: Verification
Suite + three schemes + lint. Then launch the macOS app in dark AND light (`defaults write -g AppleInterfaceStyle` toggle or the app running while switching system appearance) and screenshot each screen; check the spec's legibility list. Screenshots attached to the PR.

Commits: `feat: adaptive native token layer (#<issue>)`, `feat: native chrome — materials, glass, semantic colors (#<issue>)`, `fix: adaptive markdown and hardcoded-color sweep (#<issue>)`, `docs: ADR-015 native design language (#<issue>)`.

## PR Q — mechanical cleanup (`refactor/apptheme-rename`, after PR P merges)

Rename `NeuPalette → AppTheme`, `NeuTheme → (deleted)`, `Neu*` component prefixes; delete dead neumorphic modifiers, gradient tokens, preset machinery, theme-picker store plumbing + its tests. Zero visual change (before/after screenshots identical); suite green; single commit `refactor: rename theme layer to AppTheme, delete neumorphic remnants (#<issue>)`.

## Self-review notes
- P1 keeps the API stable so P2/P3 land on a compiling tree at every commit.
- The spec's judgment latitude on glass is bounded: compose bar + terminal header only, legibility wins.
- DesignSemanticsTests is the regression fence for future hardcoded-color drift.
