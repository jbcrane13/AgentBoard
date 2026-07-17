# Phase 1 — Chat Feature-Complete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Hermes chat surface to feature-complete: block-level markdown, live tool-activity display, functional capability toggles + real `/skills`, Hermes-native remote history, and voice-note playback (issues #139–#142).

**Architecture:** Four PR-sized slices against the real Hermes gateway API (verified 2026-07-17 against gateway v0.18.2 source + live probes):
- Text streams as OpenAI `chat.completion.chunk` `delta.content`; tool activity arrives as custom SSE events `event: hermes.tool.progress` with `{tool, emoji, label, toolCallId, status: "running"|"completed"}` — NOT `delta.tool_calls`.
- Remote history exists: `GET /api/sessions`, `GET /api/sessions/{id}/messages`; `X-Hermes-Session-Id` request/response headers bind an app conversation to a server session.
- `/v1/chat/completions` accepts only `messages`, `stream`, `model` → capability toggles use system-prompt injection (labeled in `/status`).
- `GET /v1/skills` returns `{"data":[{"name","description","category"}]}`.
- The live API server listens on **8641** with a required bearer key; the app's hard-coded default of 8642 is stale.

**Tech Stack:** Swift 6, SwiftUI, swift-markdown (new SPM dep, PR A only), AVFoundation (PR D), Swift Testing, xcodegen, SwiftLint.

## Global Constraints

- Swift 6 strict concurrency; stores `@MainActor @Observable`; no ObservableObject/@Published/CoreData/@StateObject/DispatchQueue.
- TDD; tests in Swift Testing style (`@Test`, `#expect`) matching neighboring files.
- Every interactive UI element gets `.accessibilityIdentifier("{screen}_{element}_{description}")`.
- Per PR: all three schemes build, SwiftLint strict clean, full `AgentBoardTests` suite green.
- Test command (mac-mini preferred; local gateway host is the sanctioned fallback — pass `-derivedDataPath ./DerivedData` locally):
  `xcodebuild test -scheme AgentBoard -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:AgentBoardTests`
- Run `xcodegen generate` after adding files. `ConversationMessage`/`ChatConversation` are Codable and cached — new fields must decode as optional/defaulted so old cache rows still load.

---

## PR A — Block-level markdown (#139)

### Task A1: MarkdownBlockParser

**Files:**
- Create: `AgentBoardUI/Components/MarkdownBlockParser.swift`
- Modify: `project.yml` (add `swift-markdown` package, AgentBoardUI target dependency)
- Test: `AgentBoardTests/MarkdownBlockParserTests.swift` (new)

**Interfaces:**
- Produces: `enum MarkdownBlock: Equatable { case paragraph(AttributedString); case heading(level: Int, text: AttributedString); case code(String, language: String?); case list(items: [ListItem], ordered: Bool); case blockquote([MarkdownBlock]); case table(headers: [AttributedString], rows: [[AttributedString]]); case thematicBreak }` with `struct ListItem: Equatable { let blocks: [MarkdownBlock]; let depth: Int }`
- Produces: `enum MarkdownBlockParser { static func parse(_ content: String) -> [MarkdownBlock] }` — walks the `swift-markdown` `Document` AST. Inline styling: re-serialize each block's inline children to markdown (`.format()`) and run through `AttributedString(markdown:options:.inlineOnlyPreservingWhitespace)`, falling back to plain text on parse failure. Unknown block types degrade to `.paragraph`.

- [ ] **A1.1** Add to `project.yml` packages section (create the section if absent, matching how SwiftTerm is declared): `swift-markdown: { url: https://github.com/swiftlang/swift-markdown, from: 0.5.0 }`; add `package: swift-markdown, product: Markdown` to AgentBoardUI target dependencies. Run `xcodegen generate` and confirm `xcodebuild -resolvePackageDependencies` succeeds.
- [ ] **A1.2** Write failing tests covering: `# H1` → `.heading(level:1)`; a paragraph with `**bold**` yields `.paragraph` whose AttributedString contains a bold run; fenced block with language → `.code("…", "swift")`; `- a\n- b` → `.list(ordered: false)` with 2 items; `1. a` → ordered list; nested list item has `depth: 1`; `> quote` → `.blockquote`; a 2×2 pipe table → `.table` with 2 headers + 1 row; `---` → `.thematicBreak`; empty string → `[]`; malformed markdown degrades to paragraphs without crashing.
- [ ] **A1.3** Run tests → FAIL (type not found).
- [ ] **A1.4** Implement `MarkdownBlockParser` using `import Markdown`: `Document(parsing: content)` then map `children`: `Heading` → heading (clamp level 1–6), `CodeBlock` → code, `UnorderedList`/`OrderedList` → flatten with recursion carrying depth, `BlockQuote` → recurse children, `Table` → map head/body cells, `ThematicBreak` → thematicBreak, anything else → paragraph via inline re-serialization.
- [ ] **A1.5** Run tests → PASS. Commit: `feat: add MarkdownBlockParser for block-level chat markdown (#139)`.

### Task A2: Render blocks in MarkdownText

**Files:**
- Modify: `AgentBoardUI/Components/MarkdownText.swift` (replace the private `segments` fence-splitter with `MarkdownBlockParser.parse`)
- Test: extend `AgentBoardTests/MarkdownBlockParserTests.swift` only if new parser gaps surface (rendering itself is verified by build + existing DesignSemantics/accessibility tests)

**Interfaces:**
- Consumes: `MarkdownBlockParser.parse(_:) -> [MarkdownBlock]`
- Produces: `MarkdownText(content: String)` — public interface unchanged; `ChatBubble` call sites untouched.

- [ ] **A2.1** Rewrite `MarkdownText.body` to `ForEach` over parsed blocks: paragraph → existing `Text(attributed)` styling; heading → `.font(.system(size: 22 - CGFloat(level) * 2, weight: .bold))`; code → the existing code-block view verbatim (language label, monospaced green, horizontal scroll, rounded background); list → rows with bullet/number prefix indented `CGFloat(depth) * 16`; blockquote → leading 3pt accent bar + recursed content at 0.8 opacity; table → `Grid` inside `ScrollView(.horizontal)` with header row bolded and cell dividers; thematicBreak → `Divider().opacity(0.2)`.
- [ ] **A2.2** All three schemes build; SwiftLint clean; full suite green. Commit: `feat: block-level markdown rendering in chat (#139)`, push branch `feat/issue-139-chat-block-markdown`, open PR (`Closes #139`).

---

## PR B — Tool-activity display (#140)

### Task B1: Stream event type + SSE named-event parsing

**Files:**
- Modify: `AgentBoardCore/Services/HermesGatewayClient.swift` (`streamReply`, `consumeStream`)
- Test: `AgentBoardTests/HermesGatewayClientTests.swift` (append; uses existing `MockURLProtocol`)

**Interfaces:**
- Produces: `public struct HermesToolProgress: Codable, Hashable, Sendable { public let tool: String; public let emoji: String?; public let label: String?; public let toolCallId: String; public let status: String }` (top-level in HermesGatewayClient.swift)
- Produces: `public enum HermesStreamEvent: Sendable, Hashable { case text(String); case toolProgress(HermesToolProgress) }`
- Changes: `streamReply(for:) -> AsyncThrowingStream<HermesStreamEvent, Error>` (was `<String, Error>`)

- [ ] **B1.1** Write failing tests: an SSE body containing a `delta.content` chunk, then `event: hermes.tool.progress\ndata: {"tool":"web_search","emoji":"🔍","label":"Searching…","toolCallId":"c1","status":"running"}\n\n`, then a completed event, then `data: [DONE]` yields `[.text("Hello"), .toolProgress(running…), .toolProgress(completed…)]`; a malformed tool-progress `data:` line is skipped without throwing; a stream with no `event:` lines behaves exactly as before (regression: existing streaming tests updated to unwrap `.text`).
- [ ] **B1.2** Run → FAIL (type mismatch).
- [ ] **B1.3** Implement: in `consumeStream`, track `var pendingEventName: String?`; a line prefixed `event: ` sets it; a `data: ` line consumes it — when `pendingEventName == "hermes.tool.progress"`, decode `HermesToolProgress` (skip on decode failure) and `continuation.yield(.toolProgress(…))`, else existing OpenAI-chunk path yields `.text(content)`. Reset `pendingEventName` after each `data:` line and on blank lines. `didYieldContent` still tracks text only; tool events alone must not suppress the `emptyAssistantResponse` error.
- [ ] **B1.4** Run → PASS. Commit: `feat: parse hermes.tool.progress SSE events in gateway client (#140)`.

### Task B2: Thread tool activity into messages and render chips

**Files:**
- Modify: `AgentBoardCore/Models/DomainModels.swift` (ConversationMessage)
- Modify: `AgentBoardCore/Stores/ChatStreamCoordinator.swift` (send loop)
- Modify: `AgentBoardUI/Components/ChatBubble.swift`
- Test: `AgentBoardTests/DomainModelsTests.swift` + `AgentBoardTests/ChatStoreTests.swift` (append)

**Interfaces:**
- Produces: `public struct ToolActivity: Codable, Hashable, Sendable, Identifiable { public var id: String  // toolCallId; public var tool: String; public var emoji: String?; public var label: String?; public var isComplete: Bool }`
- Changes: `ConversationMessage.toolActivities: [ToolActivity]` — new stored property, default `[]`, decoded with `decodeIfPresent` so cached/companion rows without the key still decode (follow the existing backward-compatible decoder pattern in ConversationMessage).

- [ ] **B2.1** Failing tests: `ConversationMessage` JSON without `toolActivities` decodes with `[]`; round-trips with activities; coordinator test (via ChatStore's existing mock plumbing) — a stream of `[.toolProgress(running c1), .text("Hi"), .toolProgress(completed c1)]` leaves the assistant message with `content == "Hi"` and one `ToolActivity(id: "c1", isComplete: true)`.
- [ ] **B2.2** Run → FAIL.
- [ ] **B2.3** Implement: model field + decoder; in `ChatStreamCoordinator.send`, switch on the event — `.text` appends to `assistantMessage.content`; `.toolProgress(p)` upserts by `toolCallId` (`status == "completed"` sets `isComplete = true`, completed-without-running is inserted already-complete); both paths call `callbacks.replaceMessages(…)`.
- [ ] **B2.4** In `ChatBubble` (assistant messages with non-empty `toolActivities`): above the markdown body, a wrapping HStack of chips — emoji (fallback `wrench.and.screwdriver` symbol) + `label ?? tool` in caption font, capsule background; running chips show `ProgressView().controlSize(.mini)`, complete chips a small checkmark at reduced opacity. Chip gets `.accessibilityIdentifier("chat_chip_tool_\(activity.id)")`.
- [ ] **B2.5** Full suite green; three schemes build. Commit: `feat: live tool-activity chips in chat transcript (#140)`, branch `feat/issue-140-tool-activity`, PR (`Closes #140`).

---

## PR C — Capability toggles + real /skills + correct gateway default (#141)

### Task C1: Per-conversation capability flags with system-prompt injection

**Files:**
- Create: `AgentBoardCore/Models/ChatCapability.swift`
- Modify: `AgentBoardCore/Stores/ChatStore.swift` (state), `AgentBoardCore/Stores/ChatStore+SlashCommands.swift` (`handleToggleCommand`, `statusMessageForSlashCommand`), `AgentBoardCore/Stores/ChatStreamCoordinator.swift` (inject synthetic system message), `AgentBoardCore/Services/SlashCommandHandler.swift` (`formatStatus` gains an `activeCapabilities: [String]` parameter)
- Test: `AgentBoardTests/ChatStoreSlashCommandTests.swift` (append)

**Interfaces:**
- Produces: `public enum ChatCapability: String, Codable, CaseIterable, Sendable { case thinking, web, code, image, speak }` with `var promptInstruction: String` (e.g. `.thinking` → `"Think step-by-step and show deeper reasoning before answering."`) and `var displayName: String`.
- Produces: `ChatStore.capabilities(for conversationID: UUID) -> Set<ChatCapability>` and `ChatStore.toggleCapability(_:for:) -> Bool` (returns new state). Storage: in-memory `[UUID: Set<ChatCapability>]`.
- Changes: `ChatStreamRequest` gains `let capabilities: Set<ChatCapability>`; when non-empty the coordinator prepends one synthetic `ConversationMessage(role: .system, content: "Capability overrides (client-side): " + joined instructions)` to the outbound request messages ONLY (never persisted, never shown).

- [ ] **C1.1** Failing tests: toggling `.thinking` flips state and returns true, toggling again returns false; `/think` command path appends a system message reading `"Thinking mode ON (client-side prompt injection)"` and marks the command handled (returns true — no longer falls through to the agent); `/status` output contains `"Active capabilities: Thinking (prompt-injected)"`; outbound request messages start with the synthetic system message when a capability is on (assert via the ChatStore mock client capture used by existing streaming tests).
- [ ] **C1.2** Run → FAIL.
- [ ] **C1.3** Implement. `handleToggleCommand` becomes: map `.toggleThinking → .thinking` etc.; `.showMemory`/`.showTools` keep their current passthrough behavior; toggles now `return true` (handled locally). `/status` labels every active capability `(prompt-injected)` per the spec's honesty requirement.
- [ ] **C1.4** Run → PASS. Commit: `feat: functional capability toggles via system-prompt injection (#141)`.

### Task C2: Wire /skills to GET /v1/skills

**Files:**
- Modify: `AgentBoardCore/Services/HermesGatewayClient.swift` (add `fetchSkills`), `AgentBoardCore/Stores/ChatStore+SlashCommands.swift` (`.showSkills`), `AgentBoardCore/Services/SlashCommandHandler.swift` (`formatSkills` takes `[HermesSkill]`)
- Test: `AgentBoardTests/HermesGatewayClientTests.swift`, `AgentBoardTests/ChatStoreSlashCommandTests.swift`

**Interfaces:**
- Produces: `public struct HermesSkill: Codable, Hashable, Sendable { public let name: String; public let description: String? }`; `HermesGatewayClient.fetchSkills() async throws -> [HermesSkill]` — GET `v1/skills`, decode `{"data": […]}`, auth + validation identical to `fetchModels()`.

- [ ] **C2.1** Failing tests: `fetchSkills` decodes the live payload shape (fixture with two skills incl. one `"category": null`); `.showSkills` renders fetched names + truncated descriptions and falls back to `"No skills reported by the gateway."` on error/empty.
- [ ] **C2.2** Run → FAIL. Implement. Run → PASS. Commit: `feat: wire /skills to gateway skills API (#141)`.

### Task C3: Correct the stale gateway default port

**Files:**
- Modify: `AgentBoardCore/Services/HermesGatewayClient.swift` (three `8642` literals → one `static let defaultBaseURL = "http://127.0.0.1:8641"`), plus any other `8642` hits from `grep -rn "8642" AgentBoardCore AgentBoardUI AgentBoard AgentBoardMobile`
- Test: `AgentBoardTests/HermesGatewayClientTests.swift`

- [ ] **C3.1** Failing test: `HermesGatewayConfiguration().baseURL == "http://127.0.0.1:8641"`. Implement; existing-user configured URLs in SettingsStore are untouched (default only applies when settings are blank). Update any test fixtures asserting 8642. Run → PASS. Commit: `fix: default Hermes gateway URL to live API server port 8641 (#141)`.
- [ ] **C3.2** Gate + PR: branch `feat/issue-141-capability-toggles`, PR (`Closes #141`).

---

## PR D — Remote history via Hermes sessions + voice playback (#142)

### Task D1: Bind conversations to Hermes sessions and fetch remote history

**Files:**
- Modify: `AgentBoardCore/Services/HermesGatewayClient.swift` (session header in/out, `fetchSessionMessages`, delete `loadConversationHistory` stub)
- Modify: `AgentBoardCore/Models/DomainModels.swift` (`ChatConversation.hermesSessionID: String?`, backward-compatible decode)
- Modify: `AgentBoardCore/Stores/ChatStreamCoordinator.swift` (pass/capture session id), `AgentBoardCore/Stores/ChatStore.swift` (hydrate empty synced conversations)
- Modify: `docs/ADR.md` (append entry)
- Test: `AgentBoardTests/HermesGatewayClientTests.swift`, `AgentBoardTests/DomainModelsTests.swift`, `AgentBoardTests/ChatStoreTests.swift`

**Interfaces:**
- Changes: `streamReply(for:sessionID:)` — when `sessionID != nil` sets request header `X-Hermes-Session-Id`; server then owns history (body still carries messages; server derives the user message from it). New stream event `case sessionID(String)` emitted once, from the response's `X-Hermes-Session-Id` header, before any text.
- Produces: `fetchSessionMessages(sessionID: String) async throws -> [ConversationMessage]` — GET `api/sessions/{id}/messages`; map rows (`role`, `content`, `tool_calls`→ignored, `reasoning_content`→ignored) to `ConversationMessage`; non-user/assistant roles skipped.
- ChatStore: after a stream completes with a new session id, persist it on the conversation (synced to other devices via the existing Companion conversation sync). `selectConversation` on a conversation with `hermesSessionID` set and zero local messages hydrates via `fetchSessionMessages` (best-effort; failures keep local state).

- [ ] **D1.1** ADR: append to `docs/ADR.md` — "Hermes sessions are the remote chat-history authority (`/api/sessions`); the Companion remains the cross-device sync channel for conversation metadata + local snapshots. The `loadConversationHistory` stub is removed." Match the file's existing entry format.
- [ ] **D1.2** Failing tests: request carries `X-Hermes-Session-Id` when set; `.sessionID` event surfaces the response header; `fetchSessionMessages` maps a two-row fixture (user+assistant) and skips a `tool` row; `ChatConversation` decodes legacy JSON without the field; store test: stream outcome writes `hermesSessionID` onto the conversation.
- [ ] **D1.3** Run → FAIL. Implement (delete the stub at the old `HermesGatewayClient.swift:119`). Run → PASS. Commit: `feat: Hermes session-backed remote chat history (#142)`.

### Task D2: Voice-note playback

**Files:**
- Create: `AgentBoardCore/Services/AudioPlaybackService.swift`
- Modify: `AgentBoardUI/Components/Attachments/VoiceViews.swift` (`VoicePlaybackView`)
- Test: `AgentBoardTests/AudioPlaybackServiceTests.swift` (new)

**Interfaces:**
- Produces: `@MainActor @Observable public final class AudioPlaybackService { public private(set) var activeAttachmentID: UUID?; public private(set) var progress: Double; public private(set) var isPlaying: Bool; public func togglePlayback(attachmentID: UUID, url: URL) throws; public func stop() }` — wraps `AVAudioPlayer` + a 0.1s progress `Task`; starting one attachment stops any other; `AVAudioPlayerDelegate` end-of-play resets state. Missing/undecodable file throws `PlaybackError.cannotPlay(String)`; the view surfaces it as a small error label.
- `VoicePlaybackView` drops its local `isPlaying/progress` `@State` and observes a shared service instance (injected via `@Environment` — register one instance in both app roots); replaces the placeholder `"0:00"` with remaining time from `progress`.

- [ ] **D2.1** Failing tests: playing a generated tiny WAV (write 0.2s of silence via `AVAudioFile` into a temp URL in-test) flips `isPlaying`/`activeAttachmentID`; toggling the same id pauses; a second id steals playback; a bogus URL throws `cannotPlay`.
- [ ] **D2.2** Run → FAIL. Implement service + view wiring (play `payload.localURL ?? attachment.remoteURL` — remote URLs downloaded to a temp file first via `URLSession.shared.download`). Run → PASS. Commit: `feat: voice-note playback with AVAudioPlayer (#142)`.
- [ ] **D2.3** Gate + PR: branch `feat/issue-142-history-voice`, PR (`Closes #142`).

---

## Self-review notes

- Spec coverage: 1.1→PR A, 1.2→PR B, 1.3→PR C1/C2, 1.4→PR D1 (spike outcome: endpoint EXISTS, so the implement branch runs; ADR still records the authority split), 1.5→PR D2. Port-default fix folded into PR C as gateway hygiene surfaced by the spike.
- The `streamReply` element-type change (B1) is source-breaking for `ChatStreamCoordinator` and any test unwrapping plain strings — B1/B2 land in the same PR so the tree never breaks between commits… each commit must still compile: B1's commit includes the mechanical `case .text` adaptation in the coordinator; B2 adds behavior.
- D1's session header changes outbound semantics only when a session id exists; first-turn behavior is byte-identical to today.
