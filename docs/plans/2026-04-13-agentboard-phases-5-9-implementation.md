# AgentBoard Phases 5-9 - Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Add file attachments, subtask support, agent notifications, session-task linking, and cross-review workflow to AgentBoard.

**Tech Stack:** SwiftUI, SwiftData, Swift 6 strict concurrency, GitHub API, Telegram Bot API, tmux.

---

## Phase 5: File Attachments for Issues

### Task 1: Create Attachment SwiftData model

**Objective:** Model for storing file attachments on issues

**Files:**
- Create: `AgentBoard/Models/Attachment.swift`

**Step 1:** Create the model

```swift
import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID
    var filename: String
    var fileExtension: String
    var fileSize: Int64
    var mimeType: String
    var thumbnailData: Data?
    var createdAt: Date
    
    // Link to issue
    var issueNumber: Int?
    var projectName: String?
    
    // File storage
    var storagePath: String // Relative path in app's documents
    
    init(filename: String, mimeType: String, fileSize: Int64, storagePath: String, issueNumber: Int? = nil, projectName: String? = nil) {
        self.id = UUID()
        self.filename = filename
        self.fileExtension = (filename as NSString).pathExtension
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.storagePath = storagePath
        self.issueNumber = issueNumber
        self.projectName = projectName
        self.createdAt = Date()
    }
    
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
    
    var isDocument: Bool {
        mimeType.hasPrefix("application/") || mimeType.hasPrefix("text/")
    }
    
    var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(storagePath)
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Models/Attachment.swift
git commit -m "feat: add Attachment SwiftData model for file uploads"
```

---

### Task 2: Create file attachment picker and manager

**Objective:** UI for attaching files to issues

**Files:**
- Create: `AgentBoard/Views/Attachments/AttachmentPicker.swift`

**Step 1:** Create attachment picker

```swift
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct AttachmentPicker: View {
    @Binding var attachments: [Attachment]
    @State private var showingFilePicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    
    let issueNumber: Int?
    let projectName: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                showingFilePicker = true
            } label: {
                Label("File", systemImage: "doc")
            }
            
            Button {
                showingPhotoPicker = true
            } label: {
                Label("Photo", systemImage: "photo")
            }
            
            Button {
                captureScreenshot()
            } label: {
                Label("Screenshot", systemImage: "camera")
            }
            
            if !attachments.isEmpty {
                Text("\(attachments.count) attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .pdf, .plainText, .sourceCode, .log],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItem
        )
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if let attachment = saveFileToAttachment(url) {
                    attachments.append(attachment)
                }
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        
        let filename = "photo_\(Date().timeIntervalSince1970).jpg"
        let storagePath = "attachments/\(UUID().uuidString)/\(filename)"
        
        // Save to documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(storagePath)
        
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL)
        
        let attachment = Attachment(
            filename: filename,
            mimeType: "image/jpeg",
            fileSize: Int64(data.count),
            storagePath: storagePath,
            issueNumber: issueNumber,
            projectName: projectName
        )
        
        attachments.append(attachment)
    }
    
    private func saveFileToAttachment(_ url: URL) -> Attachment? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        let filename = url.lastPathComponent
        let storagePath = "attachments/\(UUID().uuidString)/\(filename)"
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(storagePath)
        
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL)
        
        let mimeType = mimeTypeForExtension(url.pathExtension)
        
        return Attachment(
            filename: filename,
            mimeType: mimeType,
            fileSize: Int64(data.count),
            storagePath: storagePath,
            issueNumber: issueNumber,
            projectName: projectName
        )
    }
    
    private func captureScreenshot() {
        // Use screencapture CLI
        let tempPath = NSTemporaryDirectory() + "screenshot_\(Date().timeIntervalSince1970).png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempPath]
        
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0,
           let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) {
            let storagePath = "attachments/\(UUID().uuidString)/screenshot.png"
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent(storagePath)
            
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL)
            
            let attachment = Attachment(
                filename: "screenshot.png",
                mimeType: "image/png",
                fileSize: Int64(data.count),
                storagePath: storagePath,
                issueNumber: issueNumber,
                projectName: projectName
            )
            
            attachments.append(attachment)
        }
        
        try? FileManager.default.removeItem(atPath: tempPath)
    }
    
    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "swift": return "text/x-swift"
        case "log": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Attachments/AttachmentPicker.swift
git commit -m "feat: add file attachment picker with drag-drop and screenshots"
```

---

## Phase 6: Subtask Support (Epic > Tasks)

### Task 3: Add parent-child relationship to Bead

**Objective:** Support 2-level hierarchy (Epic > Tasks)

**Files:**
- Modify: `AgentBoard/Models/Bead.swift`

**Step 1:** Add parent/child properties to Bead

```swift
// Add to Bead model
var parentIssueNumber: Int?  // nil = top-level epic
var subtaskProgress: Double {
    // Calculate from child beads
}
```

**Step 2:** Add query for child tasks

```swift
// Add to AppState
func childTasks(of epicNumber: Int) -> [Bead] {
    beads.filter { $0.parentIssueNumber == epicNumber }
}
```

**Step 3:** Build and verify

**Step 4:** Commit

```bash
git add AgentBoard/Models/Bead.swift AgentBoard/App/AppState.swift
git commit -m "feat: add parent-child relationship for Epic > Tasks hierarchy"
```

---

### Task 4: Create expandable epic card view

**Objective:** Show subtasks in expandable cards

**Files:**
- Create: `AgentBoard/Views/Board/EpicCardView.swift`

**Step 1:** Create epic card with expand/collapse

```swift
import SwiftUI

struct EpicCardView: View {
    let epic: Bead
    let childTasks: [Bead]
    @State private var isExpanded = false
    
    var completedCount: Int {
        childTasks.filter { $0.status == .done }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Epic header
            HStack {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Text(epic.title)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(completedCount)/\(childTasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            if !childTasks.isEmpty {
                ProgressView(value: Double(completedCount), total: Double(childTasks.count))
                    .tint(completedCount == childTasks.count ? .green : .accentColor)
            }
            
            // Child tasks (expanded)
            if isExpanded && !childTasks.isEmpty {
                VStack(spacing: 4) {
                    ForEach(childTasks) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.status == .done ? .green : .secondary)
                            
                            Text(task.title)
                                .font(.caption)
                                .strikethrough(task.status == .done)
                            
                            Spacer()
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Board/EpicCardView.swift
git commit -m "feat: add expandable epic card with subtask progress"
```

---

## Phase 7: Agent Assignment Notifications

### Task 5: Create notification service for Telegram

**Objective:** Notify agents when assigned to tasks

**Files:**
- Create: `AgentBoard/Services/AgentNotificationService.swift`

**Step 1:** Create notification service

```swift
import Foundation

@MainActor
@Observable
final class AgentNotificationService {
    private let telegramService = TelegramService()
    
    func notifyAssignment(agent: String, task: Bead) async {
        let message = """
        📋 Task Assigned: #\(task.number) \(task.title)
        
        Project: \(task.project)
        Priority: \(task.priority)
        
        Ready to start? Reply "got it" to acknowledge.
        """
        
        await telegramService.sendMessage(message)
    }
    
    func notifyCompletion(agent: String, task: Bead) async {
        let message = """
        ✅ Task Completed: #\(task.number) \(task.title)
        
        All done! Ready for review.
        """
        
        await telegramService.sendMessage(message)
    }
    
    func acknowledgeAssignment(taskNumber: Int) async {
        let message = "👍 Got it! Working on #\(taskNumber)"
        await telegramService.sendMessage(message)
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Services/AgentNotificationService.swift
git commit -m "feat: add Telegram notification service for agent assignments"
```

---

### Task 6: Integrate notifications into task assignment

**Objective:** Auto-notify when assigning tasks

**Files:**
- Modify: `AgentBoard/Views/Board/TaskDetailSheet.swift`

**Step 1:** Add notification on assignment

```swift
@State private var notificationService = AgentNotificationService()

// In assignment action
Button("Assign to \(agent)") {
    task.assignedAgent = agent
    Task {
        await notificationService.notifyAssignment(agent: agent, task: task)
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Board/TaskDetailSheet.swift
git commit -m "feat: auto-notify agents when assigned to tasks"
```

---

## Phase 8: Session-Task Linking

### Task 7: Add session ID to Bead model

**Objective:** Link coding sessions to issues

**Files:**
- Modify: `AgentBoard/Models/Bead.swift`

**Step 1:** Add session tracking

```swift
// Add to Bead
var activeSessionId: String?
var sessionHistory: [String] = []  // Array of past session IDs
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Models/Bead.swift
git commit -m "feat: add session tracking to Bead model"
```

---

### Task 8: Create session launcher from issue

**Objective:** Start coding session linked to issue

**Files:**
- Create: `AgentBoard/Views/Sessions/SessionLauncher.swift`

**Step 1:** Create session launcher

```swift
import SwiftUI

struct SessionLauncher: View {
    let issue: Bead
    let agent: String  // "claude" or "codex"
    @State private var sessionManager = TmuxSessionManager()
    @State private var isLaunching = false
    
    var body: some View {
        Button {
            launchSession()
        } label: {
            Label("Start \(agent.capitalized) Session", systemImage: "terminal")
        }
        .disabled(isLaunching)
    }
    
    private func launchSession() {
        isLaunching = true
        
        Task {
            let task = """
            Working on issue #\(issue.number): \(issue.title)
            
            \(issue.body ?? "")
            
            Project: \(issue.project)
            """
            
            await sessionManager.launchSession(
                name: "\(agent)-issue-\(issue.number)",
                agent: agent,
                project: issue.project,
                task: task
            )
            
            // Link session to issue
            issue.activeSessionId = sessionManager.sessions.last?.id
            
            isLaunching = false
        }
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Sessions/SessionLauncher.swift
git commit -m "feat: add session launcher from issue cards"
```

---

## Phase 9: Cross-Review Workflow

### Task 9: Create cross-review service

**Objective:** Enable Codex to review Claude's work and vice versa

**Files:**
- Create: `AgentBoard/Services/CrossReviewService.swift`

**Step 1:** Create cross-review service

```swift
import Foundation

@MainActor
@Observable
final class CrossReviewService {
    var activeReviews: [ReviewSession] = []
    
    struct ReviewSession: Identifiable {
        let id: String
        let reviewingAgent: String  // "codex" or "claude"
        let workingAgent: String    // "claude" or "codex"
        let issue: Bead
        let branch: String
        var status: ReviewStatus = .pending
        var findings: [String] = []
    }
    
    enum ReviewStatus {
        case pending
        case inProgress
        case completed
        case needsRevision
    }
    
    func startReview(
        reviewingAgent: String,
        workingAgent: String,
        issue: Bead,
        branch: String
    ) async -> ReviewSession {
        let review = ReviewSession(
            id: UUID().uuidString,
            reviewingAgent: reviewingAgent,
            workingAgent: workingAgent,
            issue: issue,
            branch: branch
        )
        
        activeReviews.append(review)
        
        // Launch review session
        let reviewTask = """
        Review the changes in branch: \(branch)
        
        Issue: #\(issue.number) \(issue.title)
        \(issue.body ?? "")
        
        Check for:
        1. Code quality and style
        2. Test coverage
        3. Edge cases
        4. Performance concerns
        5. Documentation completeness
        
        Report findings as comments on the issue.
        """
        
        // Launch session with reviewing agent
        // This would integrate with TmuxSessionManager
        
        return review
    }
    
    func completeReview(reviewId: String, findings: [String]) {
        if let index = activeReviews.firstIndex(where: { $0.id == reviewId }) {
            activeReviews[index].status = .completed
            activeReviews[index].findings = findings
        }
    }
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Services/CrossReviewService.swift
git commit -m "feat: add cross-review service for agent code reviews"
```

---

### Task 10: Add review UI to completed sessions

**Objective:** Show "Request Review" button on completed sessions

**Files:**
- Modify: `AgentBoard/Views/Sidebar/SessionListView.swift`

**Step 1:** Add review button for completed sessions

```swift
@State private var crossReviewService = CrossReviewService()

// In session row
if session.status == .completed {
    Button("Request Review") {
        let reviewingAgent = session.agent == "claude" ? "codex" : "claude"
        Task {
            await crossReviewService.startReview(
                reviewingAgent: reviewingAgent,
                workingAgent: session.agent,
                issue: linkedIssue,
                branch: session.branch
            )
        }
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
}
```

**Step 2:** Build and verify

**Step 3:** Commit

```bash
git add AgentBoard/Views/Sidebar/SessionListView.swift
git commit -m "feat: add request review button to completed sessions"
```

---

## Summary: Phases 5-9

**Total Tasks:** 10
**Estimated Time:** 2-3 hours
**Focus:** Attachments, subtasks, notifications, session linking, cross-review

**Next:** Execute using subagent-driven development with Claude Code