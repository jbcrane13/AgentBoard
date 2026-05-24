# PRD: AgentBoard UI Fixes & Feature Completion

## Overview
Fix multiple UI issues and complete missing features in the AgentBoard macOS app. All changes are in the SwiftUI codebase at `/Users/blake/Projects/AgentBoard`.

## Architecture Reminder
- `AgentBoardUI/` — shared SwiftUI views/components
- `AgentBoardCore/` — stores, services, models, persistence
- `AgentBoard/` — macOS app shell (DesktopRootView)
- Build: `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- After changing project.yml: `xcodegen generate`

---

## Task 1: Fix ChatScreen Compose Area Layout

**File:** `AgentBoardUI/Screens/ChatScreen.swift`

**Problems:**
- Text field floats over the compose area instead of being properly contained
- Attachment, microphone, and send icons are too large (44-48pt frames)
- The ZStack layout with HStack overlay causes the text field to overlap with buttons

**Fix:**
Replace the current `composeArea` ZStack layout with a clean VStack/HStack structure:

```swift
private var composeArea: some View {
    @Bindable var chatStore = appModel.chatStore

    return VStack(spacing: 0) {
        // Error/status messages (keep existing)
        // ...

        // Attachment preview strip (keep existing)
        // ...

        // Compose row: [attach] [mic] [textfield] [send]
        HStack(spacing: 8) {
            // Attachment button - shrink to 28pt
            Button { showAttachmentPicker = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NeuPalette.accentCyan)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAttachmentPicker) {
                AttachmentPickerSheet { attachment in
                    chatStore.addAttachment(attachment)
                }
            }

            // Microphone button - shrink to 28pt
            VoiceRecordingButton(
                recorder: audioRecorder,
                onRecorded: { result in chatStore.addAttachment(result.toAttachment()) },
                onCancel: {}
            )

            // Text field - takes remaining space
            TextField("Message Hermes...", text: $chatStore.draft, axis: .vertical)
                .lineLimit(1...6)
                .focused($isTextFieldFocused)
                .foregroundStyle(NeuPalette.textPrimary)
                .textFieldStyle(.plain)

            // Send button - shrink to 32pt
            Button {
                isTextFieldFocused = false
                AgentBoardKeyboard.dismiss()
                Task { await chatStore.sendDraft() }
            } label: {
                Image(systemName: chatStore.isStreaming ? "stop.fill" : "paperplane.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(sendButtonForeground)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(sendButtonBackground))
            }
            .disabled(!canSend)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .neuRecessed(cornerRadius: 20, depth: 6)
    }
    .padding(.horizontal, isCompact ? 16 : 24)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .background(
        NeuPalette.background
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: NeuPalette.shadowDark, radius: 10, y: -4)
    )
}
```

Also fix `VoiceRecordingButton` in `AgentBoardUI/Components/Attachments/VoiceViews.swift`:
- Reduce the mic button frame from 44x44 to 28x28
- Reduce font size from 18 to 14

---

## Task 2: Fix AttachmentPicker on macOS

**File:** `AgentBoardUI/Components/Attachments/AttachmentPicker.swift`

**Problem:** On macOS, the attachment picker shows a sheet with "Choose File..." and "Choose Image..." buttons, but the sheet itself appears empty or broken because `List` in a sheet on macOS can have rendering issues.

**Fix:** On macOS, skip the sheet entirely and go straight to NSOpenPanel. Change the macOS `body` to immediately present the file picker and dismiss the sheet:

```swift
#else
    // On macOS, go straight to NSOpenPanel
    var body: some View {
        Color.clear
            .onAppear {
                presentMacFilePicker()
                dismiss()
            }
    }
#endif
```

Or better: keep the sheet but use a VStack of buttons instead of List on macOS:

```swift
#else
    Section {
        VStack(spacing: 12) {
            Button {
                dismiss()
                presentMacFilePicker()
            } label: {
                Label("Choose File...", systemImage: "doc")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
                presentMacImagePicker()
            } label: {
                Label("Choose Image...", systemImage: "photo")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
#endif
```

---

## Task 3: Fix Microphone Button on macOS

**File:** `AgentBoardCore/Services/AudioRecorderService.swift`

**Problem:** The microphone button may not work on macOS because `AVAudioSession` is iOS-only. Need to check if `AudioRecorderService` handles macOS properly.

**Fix:** Check the AudioRecorderService implementation. If it uses `AVAudioSession`, add `#if os(iOS)` guards and use `AVAudioRecorder` directly on macOS with proper microphone permission via `AVCaptureDevice`:

```swift
#if os(macOS)
import AVFoundation

// Request microphone permission on macOS
func requestMacMicrophonePermission() async -> Bool {
    return await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            continuation.resume(returning: granted)
        }
    }
}
#endif
```

---

## Task 4: Make Agents View a Single-Column Task List

**File:** `AgentBoardUI/Screens/AgentsScreen.swift`

**Problem:** On macOS, the Agents view shows a kanban board with 4 columns (Backlog, In Progress, Blocked, Done). Blake wants a single-column task list.

**Fix:** Change the macOS layout from `kanbanBoard` to a single-column list. Replace the body's conditional:

```swift
// In the body, replace:
if isCompact {
    compactTaskList
} else {
    kanbanBoard
}

// With:
taskList  // Always use single-column list
```

Create a new `taskList` property that shows all tasks in a single scrollable list, grouped by status with section headers but NOT in columns:

```swift
private var taskList: some View {
    ScrollView(showsIndicators: false) {
        LazyVStack(spacing: 16) {
            // Agent summaries at top (horizontal scroll)
            if !appModel.agentsStore.summaries.isEmpty {
                agentSummaryRail
            }

            // All tasks in a single list, grouped by status
            ForEach(AgentTaskState.allCases) { state in
                let tasks = appModel.agentsStore.tasks.filter { $0.status == state }
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(state.title.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(NeuPalette.textSecondary)
                            Spacer()
                            Text("\(tasks.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NeuPalette.textSecondary)
                        }
                        .padding(.horizontal, 8)

                        ForEach(tasks) { task in
                            TaskListRowNeu(task: task) { selectedTask = task }
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}
```

---

## Task 5: Make Work View Kanban with 3 Columns (Open, In Progress, Done)

**File:** `AgentBoardUI/Screens/WorkScreen.swift`

**Problem:** The Work view board layout shows all 4 WorkState cases (open, inProgress, blocked, done). Blake wants only 3 columns: Open, In Progress, Done.

**Fix:** Filter out the `blocked` state from the board layout. Change `groupedFilteredItems`:

```swift
private var groupedFilteredItems: [(state: WorkState, items: [WorkItem])] {
    // Only show Open, In Progress, Done columns (skip Blocked)
    [.open, .inProgress, .done].map { state in
        (state, filteredItems.filter { $0.status == state })
    }
}
```

This keeps blocked items hidden from the board. They'll still appear in list view if needed.

---

## Task 6: Fix CreateIssueSheet — Use Pickers for Structured Fields

**File:** `AgentBoardUI/Screens/CreateIssueSheet.swift`

**Problems:**
- Labels field is free-text comma-separated — should be a picker or tag selector
- Assignees field is free-text comma-separated — should be a picker
- These fields expect specific values but accept arbitrary input

**Fix:** 
1. **Labels** — Use a multi-select picker with common labels. Add a `knownLabels` array derived from existing issues:
```swift
private var knownLabels: [String] {
    let allLabels = appModel.workStore.items.flatMap { $0.labels }
    return Array(Set(allLabels)).sorted()
}
```

Use a `List` with toggleable rows for multi-select, or keep the text field but add a "Common Labels" section with tappable chips above it.

2. **Assignees** — Use a picker with known assignees from existing issues:
```swift
private var knownAssignees: [String] {
    let allAssignees = appModel.workStore.items.flatMap { $0.assignees }
    return Array(Set(allAssignees)).sorted()
}
```

3. **Priority** — Already a segmented picker (good)
4. **Status** — Already a segmented picker (good)

Replace the free-text fields with Picker views that also allow custom entry:

```swift
// Labels - multi-select with known values
VStack(alignment: .leading, spacing: 6) {
    Text("Labels").font(.headline).foregroundStyle(NeuPalette.textPrimary)
    if !knownLabels.isEmpty {
        FlowLayout(spacing: 8) {
            ForEach(knownLabels, id: \.self) { label in
                let isSelected = selectedLabels.contains(label)
                Button {
                    if isSelected { selectedLabels.remove(label) }
                    else { selectedLabels.insert(label) }
                } label: {
                    Text(label)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? NeuPalette.accentCyan : NeuPalette.surface)
                        .foregroundStyle(isSelected ? .black : NeuPalette.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    // Keep manual entry as fallback
    NeuTextField(placeholder: "Add custom label...", text: $customLabel)
}

// Assignees - picker with known values
VStack(alignment: .leading, spacing: 6) {
    Text("Assignees").font(.headline).foregroundStyle(NeuPalette.textPrimary)
    if !knownAssignees.isEmpty {
        FlowLayout(spacing: 8) {
            ForEach(knownAssignees, id: \.self) { assignee in
                let isSelected = selectedAssignees.contains(assignee)
                Button {
                    if isSelected { selectedAssignees.remove(assignee) }
                    else { selectedAssignees.insert(assignee) }
                } label: {
                    Text(assignee)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? NeuPalette.accentOrange : NeuPalette.surface)
                        .foregroundStyle(isSelected ? .black : NeuPalette.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    NeuTextField(placeholder: "Add custom assignee...", text: $customAssignee)
}
```

You'll need a simple `FlowLayout` or just use `WrapHStack` — or use a `LazyVGrid` with flexible columns.

---

## Task 7: Implement Session Launching

**Files:** 
- New: `AgentBoardCore/Services/SessionLauncher.swift`
- Modified: `AgentBoardUI/Screens/AgentsScreen.swift`
- New: `AgentBoardUI/Screens/LaunchSessionSheet.swift`

**Reference:** See `/Users/blake/Projects/AgentBoard-v2/AgentBoard/AgentBoard/Features/Board/SessionLauncher.swift` for the v2 implementation.

**What it does:**
- From the Agents screen, user can launch a new agent session for a task
- Creates a tmux session with PRD context
- Tracks the session in the sessions store

**Implementation:**
1. Create `SessionLauncher` service in AgentBoardCore that:
   - Takes a task/work item and launch config
   - Generates a PRD file
   - Creates a tmux session via Process()
   - Returns session info

2. Add a "Launch" button to `TaskListRowNeu` and `TaskCardNeu` in AgentsScreen

3. Create `LaunchSessionSheet` with:
   - Execution preset picker (Ralph Loop, TDD, Claude→Codex)
   - Custom instructions text field
   - Launch button

4. Add `launchSession` method to `AgentsStore` or create a standalone launcher

Key code from v2 to port:
```swift
func launchTmuxSession(sessionName: String, repo: String, preset: ExecutionPreset, prdPath: String) async throws {
    let shellCmd = "/opt/homebrew/bin/tmux -S \(socket) new -d -s \(sessionName)" +
        " \"cd \(projectDir) && unset ANTHROPIC_API_KEY" +
        " && /opt/homebrew/bin/ralphy --\(agent) --prd \(prdPath)" +
        "; EXIT_CODE=$?; echo EXITED: $EXIT_CODE; sleep 999999\""
    // Run via Process()
}
```

---

## Task 8: Verify GitHub Integration

**Files:** `AgentBoardCore/Stores/WorkStore.swift`, `AgentBoardCore/Stores/SettingsStore.swift`

**Check:**
1. Verify `isGitHubConfigured` returns true when token + repos are set
2. Verify `WorkStore.bootstrap()` calls `refresh()` when configured
3. Verify `refresh()` actually fetches and populates items
4. The code looks correct — likely the issue is that Blake hasn't configured the GitHub token/repos in Settings yet, OR the auto-refresh on tab switch isn't happening.

**Fix:** Add auto-refresh when the Work tab becomes visible. In `WorkScreen`, add:
```swift
.onAppear {
    Task { await appModel.workStore.bootstrap() }
}
```

Also ensure `AgentBoardAppModel.bootstrap()` calls `workStore.bootstrap()`.

---

## Build & Verify

After all changes:
```bash
cd /Users/blake/Projects/AgentBoard
xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Fix any build errors. Run `swiftlint lint --strict` to check for style issues.

---

## Constraints
- Swift 6 strict concurrency
- @Observable (not ObservableObject) for new stores
- accessibilityIdentifier on every interactive element
- Follow existing neumorphic design system (NeuPalette, NeuExtruded, NeuRecessed)
- macOS-first, but keep iOS compatibility with #if os() guards
- Do NOT edit AgentBoard.xcodeproj directly — use project.yml + xcodegen
