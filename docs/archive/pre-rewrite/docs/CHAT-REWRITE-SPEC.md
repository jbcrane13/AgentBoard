# Chat Integration Rewrite — OpenClaw WebSocket RPC

## Problem

The current `OpenClawService` uses `POST /v1/chat/completions` (a stateless REST endpoint) and a
WebSocket only for ping checks. This means:
- Every chat message creates a throwaway session instead of talking to the real main session
- The `/api/sessions` REST endpoint doesn't exist (returns HTML fallback)
- No streaming events, no session management, no thinking controls

The OpenClaw gateway uses a **WebSocket JSON-RPC protocol** for all control-plane operations.

## Gateway WebSocket RPC Protocol

### Connection

Connect to `ws://127.0.0.1:18789` (same port as HTTP, multiplexed).

### Message Format

**Request:**
```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "<method-name>",
  "params": { ... }
}
```

**Response:**
```json
{
  "type": "res",
  "id": "<uuid>",
  "ok": true,
  "payload": { ... }
}
```
or on error:
```json
{
  "type": "res",
  "id": "<uuid>",
  "ok": false,
  "error": { "message": "<error-description>" }
}
```

**Server Event:**
```json
{
  "type": "event",
  "event": "<event-name>",
  "payload": { ... },
  "seq": <number>
}
```

### Connect Handshake

After WebSocket opens, wait ~750ms then send a `connect` request:

```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "agentboard",
      "version": "1.0",
      "platform": "macOS",
      "mode": "webchat"
    },
    "role": "operator",
    "scopes": ["operator.admin"],
    "auth": { "token": "<gateway-token>" }
  }
}
```

**Challenge flow:** The server may emit a `connect.challenge` event with a nonce before the
connect request is sent. If received, include the nonce in the connect params. For simplicity,
AgentBoard can skip the Ed25519 device identity signing and just use token auth. The connect
response is a "hello" payload with snapshot data.

### Chat Methods

**chat.send** — Send a message to a session:
```json
{
  "method": "chat.send",
  "params": {
    "sessionKey": "main",
    "message": "Hello!",
    "deliver": false,
    "idempotencyKey": "<uuid>"
  }
}
```
- `deliver: false` means don't deliver to external channels (just process internally)
- `idempotencyKey` prevents duplicate processing
- Response is immediate (just ack). The actual assistant response streams via `chat` events.

**chat.history** — Load chat history:
```json
{
  "method": "chat.history",
  "params": {
    "sessionKey": "main",
    "limit": 200
  }
}
```
Response payload:
```json
{
  "messages": [
    {
      "role": "user" | "assistant" | "system",
      "content": "<string>" | [{ "type": "text", "text": "..." }, ...],
      "timestamp": <number>
    }
  ],
  "thinkingLevel": "high" | "medium" | "low" | null
}
```
Note: `content` can be a string OR an array of content parts. Always handle both.

**chat.abort** — Abort a running generation:
```json
{
  "method": "chat.abort",
  "params": {
    "sessionKey": "main",
    "runId": "<optional-run-id>"
  }
}
```

### Chat Events

Server pushes `chat` events for streaming responses:
```json
{
  "type": "event",
  "event": "chat",
  "payload": {
    "sessionKey": "main",
    "runId": "<uuid>",
    "state": "delta" | "final" | "error" | "aborted",
    "message": {
      "role": "assistant",
      "content": "<string>" | [{ "type": "text", "text": "..." }]
    },
    "errorMessage": "<string>"  // only on state=error
  }
}
```

States:
- `delta` — Partial content update. Extract text from `message.content`. Each delta contains
  the FULL text so far (not incremental). Replace the current stream buffer.
- `final` — Generation complete. Refresh history with `chat.history`.
- `error` — Error occurred.
- `aborted` — User or system aborted.

### Session Methods

**sessions.list** — List all sessions:
```json
{
  "method": "sessions.list",
  "params": {
    "includeGlobal": true,
    "includeUnknown": false,
    "activeMinutes": 120,
    "limit": 50
  }
}
```

**sessions.patch** — Update session settings (thinking level, etc.):
```json
{
  "method": "sessions.patch",
  "params": {
    "key": "main",
    "thinkingLevel": "high"
  }
}
```
Valid thinking levels: `"high"`, `"medium"`, `"low"`, or omit/null to use default.

**agent.identity.get** — Get agent name/avatar:
```json
{
  "method": "agent.identity.get",
  "params": {
    "sessionKey": "main"
  }
}
```

## Implementation Plan

### 1. New WebSocket RPC Client (`GatewayClient.swift`)

Create a new actor that handles the WebSocket JSON-RPC protocol:

```swift
actor GatewayClient {
    // Connection
    func connect(url: URL, token: String?) async throws
    func disconnect()
    var isConnected: Bool { get }

    // RPC
    func request<T: Decodable>(_ method: String, params: Encodable) async throws -> T

    // Events
    var events: AsyncStream<GatewayEvent> { get }
}
```

This replaces the current WebSocket usage in OpenClawService.

### 2. Rewrite `OpenClawService`

Update to use `GatewayClient` for all operations:

- `connectToGateway()` — WebSocket + connect handshake
- `sendChatMessage(sessionKey:message:)` — Uses `chat.send`
- `loadChatHistory(sessionKey:limit:)` — Uses `chat.history`
- `abortChat(sessionKey:)` — Uses `chat.abort`
- `listSessions()` — Uses `sessions.list`
- `patchSession(key:thinkingLevel:)` — Uses `sessions.patch`
- `getAgentIdentity(sessionKey:)` — Uses `agent.identity.get`
- Expose `chatEvents: AsyncStream<ChatEvent>` for streaming

### 3. Update `AppState`

- Add `currentSessionKey: String` (default "main") for session switching
- Add `availableSessions: [GatewaySession]` from `sessions.list`
- Add `thinkingLevel: String?` for current session's thinking level
- Update `sendChatMessage()` to use `chat.send` + event stream
- Add `switchSession(to:)` for session switching
- Add `setThinkingLevel(_:)` for thinking control
- Add event listener loop for `chat` events
- Load history on session switch

### 4. UI Updates

**ChatPanelView:**
- Add a session picker (compact dropdown) in the chat header area
- Add a thinking level toggle (segmented control or menu: Off / Low / Medium / High)
- Add a connection status indicator
- Add an abort button (visible during streaming)

**Session Picker:**
- Dropdown or popover showing available sessions from gateway
- Each session shows: key/label, agent ID, last active time
- Selecting a session switches `currentSessionKey` and loads history

**Thinking Control:**
- Small segmented control or menu button near the chat input
- Options: Default, Low, Medium, High
- Changes persist via `sessions.patch`

### 5. Content Extraction Helper

Messages from the gateway can have `content` as string or array:
```swift
func extractText(from content: Any) -> String {
    if let str = content as? String { return str }
    if let parts = content as? [[String: Any]] {
        return parts.compactMap { part in
            if part["type"] as? String == "text" {
                return part["text"] as? String
            }
            return nil
        }.joined(separator: "\n")
    }
    return ""
}
```

## Files to Modify

- **New:** `AgentBoard/Services/GatewayClient.swift` — WebSocket RPC client
- **Rewrite:** `AgentBoard/Services/OpenClawService.swift` — Use GatewayClient
- **Modify:** `AgentBoard/App/AppState.swift` — Session switching, thinking, event loop
- **Modify:** `AgentBoard/Views/Chat/ChatPanelView.swift` — Session picker, thinking control, abort
- **Modify:** `AgentBoard/Models/ChatMessage.swift` — Handle gateway message format
- **Modify:** `AgentBoard/Models/OpenClawConnectionState.swift` — May need auth states

## Testing

After implementation:
1. Build: `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' build`
2. Test: `xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' test`
3. Verify chat connects and shows history from actual main session
4. Verify sending a message produces a streaming response
5. Verify session list populates from gateway
6. Verify thinking level changes via sessions.patch

## Gateway Details

- URL: `ws://127.0.0.1:18789` (HTTP and WS share same port)
- Token: Read from `~/.agentboard/config.json` → `openClawToken`
- Default session key: `"main"`
