---
name: AgentBoard
description: Native macOS/iOS control surface for a Hermes-first agent fleet
colors:
  system-accent: "#0A84FF"
  window: "#ECECEC"
  control: "#FFFFFF"
  inset: "#F5F5F5"
  surface-hover: "#00000014"
  text-primary: "#000000"
  text-secondary: "#3C3C4399"
  text-tertiary: "#3C3C434C"
  text-disabled: "#3C3C432E"
  border-soft: "#3C3C4326"
  border: "#3C3C434D"
  border-strong: "#3C3C437A"
  status-open: "#0A84FF"
  status-success: "#34C759"
  status-idle: "#0A84FF"
  accent-orange: "#FF9500"
  accent-coral: "#FF3B30"
  accent-purple: "#AF52DE"
  accent-foreground: "#FFFFFF"
  shadow-dark: "#00000033"
typography:
  display:
    fontFamily: "SF Pro Display, -apple-system, system-ui, sans-serif"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.8px"
  headline:
    fontFamily: "SF Pro Display, -apple-system, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "normal"
  title:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "normal"
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "1.2px"
  mono:
    fontFamily: "SF Mono, JetBrains Mono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "normal"
rounded:
  xs: "8px"
  sm: "9px"
  md: "12px"
  lg: "14px"
  xl: "16px"
  card: "22px"
  bubble: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.system-accent}"
    textColor: "{colors.accent-foreground}"
    rounded: "{rounded.xs}"
    padding: "14px 8px"
  button-primary-pressed:
    backgroundColor: "{colors.system-accent}"
    textColor: "{colors.accent-foreground}"
    rounded: "{rounded.xs}"
    padding: "14px 8px"
  button-secondary:
    backgroundColor: "{colors.surface-hover}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.xs}"
    padding: "14px 8px"
  pill-status:
    backgroundColor: "{colors.system-accent}"
    textColor: "{colors.system-accent}"
    rounded: "999px"
    padding: "8px 4px"
  card-raised:
    backgroundColor: "{colors.control}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "18px"
  inset-well:
    backgroundColor: "{colors.inset}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.xl}"
    padding: "12px"
---

# Design System: AgentBoard

## 1. Overview

**Creative North Star: "The Control Surface"**

AgentBoard is a native console for a fleet of Hermes-driven coding agents. The aesthetic is calm at idle, clear in motion. The user is a power developer who runs multiple agent sessions, triages work, and steers agents mid-flight — the interface treats them as someone who knows what they're doing and stays out of their way.

The system is native macOS/iOS first. Surfaces, materials, controls, and motion come from the platform; the app reads as a first-class citizen of the OS, not a bespoke design system fighting it (ADR-015). Depth is carried by native materials and hairline borders, not bespoke shadows. Color is semantic: a small, consistent vocabulary maps kanban columns, work states, session states, and chat connection to meaning. Decoration carries no weight here; if a color or motion does not encode state, it does not belong.

This system explicitly rejects the retired beads prototype's neumorphic double-shadows and skeuomorphic extruded/recessed surfaces, and the generic "AI dashboard" slop lane — dark navy backgrounds, neon accent glows, gradient text, hero-metric templates, and identical icon-card grids. AgentBoard is a tool, not a pitch deck. The web-app-in-a-window feel (custom scrollbars, non-native form controls) is also forbidden.

**Key Characteristics:**
- Native chrome over custom chrome: `NavigationSplitView`, `.inspector`, `.sidebar`, system materials, system accent.
- Flat by default; shadows appear only on state (drag, floating chrome).
- Restrained color: one accent, a small semantic status vocabulary, tinted-native neutrals.
- Dense information for power users, progressive disclosure at decision points.
- Consistent component vocabulary screen to screen; delight is saved for moments, not pages.

## 2. Colors

The palette is Restrained: tinted-native neutrals carry the surface, one system accent carries primary action and selection, and a small semantic vocabulary encodes status. Neutrals resolve to the platform's dynamic window/control/inset colors so light and dark mode are automatic; the values below are the macOS light-mode approximations for reference only — the OS is the source of truth.

### Primary
- **System Accent** (#0A84FF): the system accent color from the asset catalog. Primary actions, current selection, and the kanban "ready"/"open" status. Used on ≤10% of any screen; its rarity is the point.

### Neutral
- **Window** (#ECECEC): window/scene background. The canvas behind everything.
- **Control** (#FFFFFF): control-background and raised-card surface. The resting layer for cards and tiles.
- **Inset** (#F5F5F5): inset wells, recessed fields, and kanban column backgrounds. One step below Control.
- **Surface Hover** (#00000014): hover/active tint applied to non-accent controls.
- **Text Primary** (#000000): primary text. In dark mode this inverts via the OS.
- **Text Secondary** (#3C3C4399): secondary labels and supporting copy.
- **Text Tertiary** (#3C3C434C): timestamps, counts, placeholders.
- **Border Soft** (#3C3C4326): card and inset hairlines at 0.5px.
- **Border** (#3C3C434D): stronger dividers and column outlines at 1px.

### Semantic Status
- **Status Open / Idle** (#0A84FF): ready and idle sessions. Reuses the accent.
- **Status Success** (#34C759): running tasks, resolved work, completed sessions.
- **Accent Orange** (#FF9500): in-progress work, blocked tasks, stalled sessions, "In Progress" kanban column.
- **Accent Coral** (#FF3B30): blocked work, error states, the streaming "stop" button.
- **Accent Purple** (#AF52DE): the chat tile accent and "review" status.

### Named Rules
**The One Voice Rule.** The system accent is used on primary actions, current selection, and the "ready/open" status only — never as decoration. ≤10% of any screen.
**The Semantic Color Rule.** Orange means progress or blocked; coral means error or stop; green means success; the accent means primary/open. Never repaint a status color for variety.
**The Native Neutrals Rule.** Neutrals come from the OS (`windowBackgroundColor`, `controlBackgroundColor`, `underPageBackgroundColor`). Never hand-roll a neutral hex; the OS owns light/dark adaptation.

## 3. Typography

**Display Font:** SF Pro Display (with `-apple-system, system-ui, sans-serif` fallback)
**Body Font:** SF Pro Text (with `-apple-system, system-ui, sans-serif` fallback)
**Label/Mono Font:** SF Mono / JetBrains Mono for references, counts, and code

**Character:** One family, system-native, doing everything. No display font in labels; no pairing. Hierarchy comes from weight and scale contrast (≥1.25 ratio between steps), kept tight for product density. The eyebrow/label style is uppercase, tracked, semibold — the only typographic flourish, and it reads as "instrument label," not marketing.

### Hierarchy
- **Display** (700, 30px / 34px compact, line-height 1.1, letter-spacing -0.8px): screen titles on the dashboard and major headers. Used sparingly — one per screen.
- **Headline** (700, 17px, line-height 1.2): section and sheet titles.
- **Title** (700, 15px, line-height 1.25): card and tile titles.
- **Body** (400, 13px, line-height 1.4): default body and descriptions.
- **Label** (600, 11px, letter-spacing 1.2px, uppercase): eyebrows, kanban column headers, and sender labels. Tracking is the personality; do not remove it.
- **Mono** (600, 11px): issue references, counts, slash-command names. `.monospacedDigit()` on all numeric stats.

### Named Rules
**The One Family Rule.** SF Pro carries headings, body, labels, and data. No display/body pairing, no editorial serif. System fonts are a feature.
**The Eyebrow Is Not Decoration Rule.** The uppercase tracked label style signals "instrument label" and maps to status/section meaning. If a label carries no semantic weight, set it in body weight, not eyebrow.

## 4. Elevation

Flat by default. Depth is carried by native materials (`.regularMaterial`, `.tertiary`) and hairline borders at 0.5–1px. There is no ambient shadow vocabulary at rest. The system provides its own lifted-preview shadow while a card is being dragged; AgentBoard does not add one. The two deliberate shadow uses are state-driven: a soft shadow on floating chrome (the compose bar's glass, the terminal header) and the tiny lift on a draggable card's create-issue button.

### Shadow Vocabulary (state-only)
- **Floating Chrome** (`shadow(color: shadowDark, radius: 4, y: 2)`): compose bar glass and slash-command popover. State-driven, not ambient.
- **Card Lift** (`shadow(color: shadowDark opacity 0.4, radius: 3, y: 1)`): the create-issue plus button. A affordance for the primary action, not resting decoration.

### Named Rules
**The Flat-By-Default Rule.** Surfaces are flat at rest. Shadows appear only as a response to state (drag, float, focus). Never add an ambient card shadow.
**The Material Hierarchy Rule.** Raised = `.regularMaterial` or Control; recessed = Inset or `.tertiary`. Do not invent a third material layer.
**The Hairline Rule.** Borders are 0.5px (soft) or 1px (standard). Anything thicker is skeuomorphic and forbidden.

## 5. Components

### Buttons
- **Shape:** 8px continuous corner radius (`RoundedRectangle(cornerRadius: 8, style: .continuous)`).
- **Primary (`AppButtonStyle(isAccent: true)`):** filled with System Accent, white foreground, semibold subheadline, 14×8 padding. The only filled button on a screen.
- **Secondary (`AppButtonStyle(isAccent: false)`):** clear fill over Surface Hover, text-primary foreground, 0.5px border. The default button.
- **Pressed:** opacity drops to 0.7; no custom scale or shadow animation. System feedback.
- **Circular accent:** the create-issue plus button is a 28px circle filled with System Accent, white glyph, 0.5px soft border, and the Card Lift shadow. Reserved for the single primary action of a screen.

### Pills / Chips
- **Status pill (`AgentBoardPill`):** capsule, color at 12% fill, semibold caption2 text in the color, 8×4 padding, 6px dot or 9px SF Symbol. Encodes one status.
- **Stat pill (`statPill` / `statChip`):** 7px filled circle with a 0.6-opacity color glow, rounded-bold count, caption label. Reads as "instrument reading."
- **Tool activity chip:** capsule, Surface Hover fill, text-secondary, 10×5 padding, with a mini ProgressView or checkmark. Fades to 0.65 opacity when complete.

### Cards / Containers
- **Raised card (`cardSurface`):** `.regularMaterial` fill, 0.5px soft border, 22px continuous radius (tiles) or 14px (work cards). Padding 18px (tiles) or 10px (work cards). Flat at rest.
- **Inset well (`insetSurface`):** Inset fill, 0.5px soft border, 16px radius. Kanban columns, search fields, slash-command category chips.
- **Kanban column:** Inset fill, 1px standard border, 14px radius, fixed 170px width, header with a 1px bottom divider and a count capsule.

### Inputs / Fields
- **Search field:** plain TextField in an Inset well, 8px radius, 10×6 padding, magnifyingglass + caption placeholder. No stroke at rest.
- **Compose field:** plain TextField, `lineLimit(1...6)`, submit label `.send`. Housed in the glass compose bar, not its own bordered box.
- **Focus:** relies on system focus; no custom glow or border shift.

### Navigation
- **Desktop:** `NavigationSplitView` with `.sidebar` list (220–320px), detail, and trailing `.inspector` chat (320–460px). Toolbar primary actions: Quick Launch + chat toggle.
- **Mobile:** `TabView(selection:)` with `NavigationStack`, inline title, hidden nav bar where the screen owns its header.
- **Sidebar rows:** native `Label` with SF Symbol, badges for counts, project color from a 3-color hash. Live sessions show status dot + secondary caption.

### Chat Bubble
- **Shape:** 24px continuous radius, 20px padding, aligned by role.
- **Assistant:** `.regularMaterial` fill, 1px soft border, text-primary, accent-cyan "Hermes" label, tool activity chips above content.
- **User:** solid System Accent fill, no border, white text, accent-orange "You" label.
- **System:** `.tertiary` fill, text-secondary.
- **Streaming:** mini ProgressView tinted accent; "typing..." placeholder when content is empty.

## 6. Do's and Don'ts

### Do:
- **Do** use native platform materials and colors (`windowBackgroundColor`, `controlBackgroundColor`, `underPageBackgroundColor`, `.regularMaterial`). The OS owns light/dark adaptation.
- **Do** keep the System Accent to primary actions, current selection, and the ready/open status — ≤10% of any screen (The One Voice Rule).
- **Do** map every status to the semantic vocabulary: orange = progress/blocked, coral = error/stop, green = success, accent = primary/open. Pair color with a dot, icon, or text label so it reads beyond hue.
- **Do** carry depth with materials and 0.5–1px hairlines. Shadows appear only on state: drag, float, the primary action's lift (The Flat-By-Default Rule).
- **Do** use SF Pro for everything; create hierarchy with weight and scale (≥1.25 step ratio). Reserve the uppercase tracked eyebrow for instrument labels that carry meaning.
- **Do** put accessibility identifiers on every interactive element (`{screen}_{element}_{description}`) and `.monospacedDigit()` on all numeric stats.
- **Do** keep component vocabulary consistent screen to screen — same button shape, same pill style, same card radius family.

### Don't:
- **Don't** use neumorphic double-shadows, extruded/recessed skeuomorphic surfaces, or any vestige of the retired beads prototype.
- **Don't** paint in the "AI dashboard" slop lane — dark navy backgrounds, neon accent glows, gradient text (`background-clip: text` + gradient), hero-metric templates, or identical icon+heading+text card grids.
- **Don't** add ambient card shadows at rest. If it is not being dragged or floating, it is flat.
- **Don't** use a `border-left`/`border-right` greater than 1px as a colored side-stripe accent on cards, list items, or callouts.
- **Don't** reinvent standard affordances — custom scrollbars, non-native form controls, Electron-grade chrome. The app reads as a first-class macOS/iOS citizen.
- **Don't** repaint a status color for variety or decoration. Color means state, always.
- **Don't** put a display font in a UI label, button, or data cell. The eyebrow style is uppercase tracked, not decorative.
- **Don't** use glassmorphism decoratively. Glass is reserved for floating chrome (compose bar, terminal header) where content scrolls behind it.
- **Don't** use em dashes in copy. Use commas, colons, semicolons, periods, or parentheses.
