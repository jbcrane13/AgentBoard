# Interactive Terminal Sessions Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the read-only terminal capture view with a full interactive SwiftTerm-backed terminal so users can run commands and manage dev flows entirely within AgentBoard.

**Architecture:** An `NSViewRepresentable` wrapper (`InteractiveTerminalView`) hosts SwiftTerm's `LocalProcessTerminalView` and spawns `tmux attach-session -t <sessionID>` to connect to the existing tmux session. `TerminalView` keeps its toolbar but swaps the body to use `InteractiveTerminalView`. `SessionListView` rows are enriched with a bead chip and model label; stopped/error sessions are non-interactive.

**Tech Stack:** SwiftTerm (already linked via `project.yml`), SwiftUI `NSViewRepresentable`, macOS 15+, Swift 6 strict concurrency

---

## Chunk 1: InteractiveTerminalView + TerminalView update

### Task 1: Create `InteractiveTerminalView`

**Files:**
- Create: `AgentBoard/Views/Terminal/InteractiveTerminalView.swift`

- [ ] **Step 1: Create the file with the NSViewRepresentable wrapper**

Note: `startProcess` does **not** throw — no `try`/`do`/`catch` needed. When the tmux
session is not found, tmux prints its own error message to the PTY before exiting, so
the user sees a human-readable error directly in the terminal without any extra code.
Window resize propagates automatically: SwiftTerm's `setFrameSize` sends a PTY resize
signal internally when the NSView bounds change. No `xcodegen generate` is needed —
`project.yml` sources the `AgentBoard/` directory, so new `.swift` files are
auto-discovered. The existing refresh (`arrow.clockwise`) button is intentionally
omitted from the new toolbar because polling is replaced by the live interactive
terminal; there is nothing to manually refresh.

```swift
import SwiftUI
import SwiftTerm

/// Embeds a SwiftTerm LocalProcessTerminalView that attaches to an existing
/// tmux session by running `tmux attach-session -t <sessionID>`.
/// If the session is not found, tmux prints its own error to the terminal before
/// exiting — no extra error-handling code is required.
struct InteractiveTerminalView: NSViewRepresentable {
    let sessionID: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.configureNativeColors()
        tv.startProcess(
            executable: "/usr/bin/env",
            args: ["tmux", "attach-session", "-t", sessionID],
            environment: nil,
            execName: nil
        )
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm propagates NSView bounds changes to the PTY automatically.
    }
}
```

- [ ] **Step 2: Build to verify SwiftTerm import resolves and the file compiles**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add AgentBoard/Views/Terminal/InteractiveTerminalView.swift
git commit -m "feat: add InteractiveTerminalView wrapping SwiftTerm"
```

---

### Task 2: Update `TerminalView` to use `InteractiveTerminalView`

**Files:**
- Modify: `AgentBoard/Views/Terminal/TerminalView.swift`

Current `TerminalView` has:
- A `toolbar` (keep as-is — matches the approved slim single-line design)
- A `terminalOutput` read-only `ScrollView` with a polling loop (`refreshLoop`, `refreshOutput`)
- `@State private var outputText = ""`
- `@State private var isRefreshing = false`
- A `.task(id: session.id)` that starts the polling loop

All of the polling infrastructure gets removed. The `toolbar` is kept verbatim.

- [ ] **Step 1: Replace the body and remove polling code**

Replace the entire content of `TerminalView.swift` with:

```swift
import SwiftUI

struct TerminalView: View {
    @Environment(AppState.self) private var appState

    let session: CodingSession

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            InteractiveTerminalView(sessionID: session.id)
        }
        .background(AppTheme.appBackground)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                appState.backToBoardFromTerminal()
            } label: {
                Label("Back to Board", systemImage: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])

            Divider()
                .frame(height: 14)

            Text(session.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            statusChip

            if let model = session.model, !model.isEmpty {
                Text(model)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let beadID = session.beadId {
                Text(beadID)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
            }

            Text(elapsedLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Nudge") {
                Task {
                    await appState.nudgeSession(sessionID: session.id)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(session.status.rawValue.capitalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    private var statusColor: Color {
        AppTheme.sessionColor(for: session.status)
    }

    private var elapsedLabel: String {
        let elapsed = max(0, Int(session.elapsed))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 2: Build to verify no regressions**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run unit tests to verify nothing broke**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' test \
  -only-testing:AgentBoardTests 2>&1 | tail -10
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add AgentBoard/Views/Terminal/TerminalView.swift
git commit -m "feat: replace read-only terminal output with InteractiveTerminalView"
```

---

## Chunk 2: Enriched sidebar session rows

### Task 3: Update `SessionListView` — enriched rows + disable stopped sessions

**Files:**
- Modify: `AgentBoard/Views/Sidebar/SessionListView.swift`

Changes:
1. The `sessionRow` function adds a second line: bead chip (blue pill) + model label
2. Sessions with `.stopped` or `.error` status do not call `appState.openSessionInTerminal` and render dimmed

- [ ] **Step 1: Replace `sessionRow` with the enriched version**

Replace the `sessionRow` function in `SessionListView.swift`:

```swift
private func sessionRow(_ session: CodingSession) -> some View {
    let isInteractive = session.status == .running || session.status == .idle

    return Button {
        guard isInteractive else { return }
        appState.openSessionInTerminal(session)
    } label: {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 7, height: 7)
                .shadow(color: session.status == .running
                        ? statusColor(session.status).opacity(0.5)
                        : .clear, radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundStyle(isInteractive
                                     ? AppTheme.sidebarPrimaryText
                                     : AppTheme.sidebarMutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 5) {
                    if let beadId = session.beadId {
                        Text(beadId)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Color.accentColor.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 3)
                            )
                    }
                    if let model = session.model, !model.isEmpty {
                        Text(model)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.sidebarMutedText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(statusLabel(session))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.sidebarMutedText)

                if appState.sessionAlertSessionIDs.contains(session.id) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.231, blue: 0.188))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(appState.activeSessionID == session.id
                      ? Color.white.opacity(0.12)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .opacity(isInteractive ? 1.0 : 0.45)
    }
    .buttonStyle(.plain)
    .disabled(!isInteractive)
    .accessibilityIdentifier("SessionRow")
}
```

- [ ] **Step 2: Build to verify the layout compiles**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run unit tests**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' test \
  -only-testing:AgentBoardTests 2>&1 | tail -10
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add AgentBoard/Views/Sidebar/SessionListView.swift
git commit -m "feat: enrich session sidebar rows with bead chip and model; disable stopped sessions"
```

---

## Chunk 3: Final verification + push

### Task 4: End-to-end build and push

- [ ] **Step 1: Full project build**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Full unit test suite**

```bash
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard \
  -destination 'platform=macOS' test \
  -only-testing:AgentBoardTests 2>&1 | tail -10
```

Expected: all unit tests pass. Note: UITests follow the project's no-skip policy and
require a build machine — run them there before merging to main.

- [ ] **Step 3: Manual resize verification**

With a live tmux session open in the terminal pane, drag the window wider and narrower.
The terminal content should reflow to match the new column width (no fixed-width lines
or clipped text). This is the spec invariant for PTY resize propagation; there is no
automated test for it.

- [ ] **Step 4: Verify working tree is clean**

```bash
git status
```

Expected: `nothing to commit, working tree clean`

- [ ] **Step 5: Push**

```bash
git push
```
